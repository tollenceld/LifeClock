import SwiftData
import SwiftUI
import OSLog

@main
struct KeduApp: App {
    @State private var storage = AppStorageController()
    @State private var theme = AppTheme()

    var body: some Scene {
        WindowGroup {
            Group {
                if let container = storage.container {
                    AppRootView().modelContainer(container)
                } else {
                    StorageUnavailableView(retry: storage.load)
                }
            }
            .environment(theme)
        }
    }
}

/// Test fixtures can never replace the persistent store in a distribution build.
enum AppLaunchOptions {
    static var arguments: [String] {
        #if DEBUG
        CommandLine.arguments
        #else
        []
        #endif
    }
    static var isTesting: Bool {
        #if DEBUG
        arguments.contains("-uiTesting")
        #else
        false
        #endif
    }
    static func contains(_ flag: String) -> Bool { isTesting && arguments.contains(flag) }
}

@MainActor
@Observable
final class AppStorageController {
    private(set) var container: ModelContainer?
    private(set) var loadFailed = false
    private let factory: (() throws -> ModelContainer)?
    #if DEBUG
    private var simulatedFailures = AppLaunchOptions.contains("-uiTestingStorageFailure") ? 1 : 0
    #else
    private var simulatedFailures = 0
    #endif

    init(factory: (() throws -> ModelContainer)? = nil) {
        self.factory = factory
        load()
    }

    func load() {
        do {
            if simulatedFailures > 0 {
                simulatedFailures -= 1
                throw CocoaError(.fileReadNoPermission)
            }
            let loaded = try factory?() ?? Self.makeContainer()
            let profiles = try loaded.mainContext.fetch(FetchDescriptor<UserProfile>())
            for profile in profiles where profile.birthDateComponents == nil {
                profile.birthDateComponents = CivilBirthday.key(for: profile.birthDate, calendar: CivilBirthday.calendar)
            }
            for profile in profiles where profile.birthTimeZoneIdentifier == nil {
                profile.birthTimeZoneIdentifier = CivilBirthday.calendar.timeZone.identifier
            }
            let events = try loaded.mainContext.fetch(FetchDescriptor<TimeEvent>())
            for event in events where event.recurrence != .once && event.anchorDateComponents == nil {
                event.anchorDateComponents = CivilSchedule.key(for: event.anchorDate, calendar: CivilBirthday.calendar)
            }
            if loaded.mainContext.hasChanges { try loaded.mainContext.save() }
            container = loaded
            loadFailed = false
        } catch {
            // Never erase a user's store or silently replace it with an ephemeral one.
            container = nil
            loadFailed = true
            Logger(subsystem: "com.local.Kedu", category: "Storage").error("Store could not open: \(String(describing: error), privacy: .private)")
        }
    }

    private static func makeContainer() throws -> ModelContainer {
        let schema = Schema([UserProfile.self, TimeEvent.self])
        let configuration: ModelConfiguration
        #if DEBUG
        if AppLaunchOptions.contains("-uiTestingPersistentStore") {
            let directory = URL.applicationSupportDirectory.appending(path: "UITestStore", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            configuration = ModelConfiguration(schema: schema, url: directory.appending(path: "persistence.sqlite"), cloudKitDatabase: .none)
        } else {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: AppLaunchOptions.isTesting, cloudKitDatabase: .none)
        }
        #else
        configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)
        #endif
        let container = try ModelContainer(for: schema, configurations: [configuration])
        #if DEBUG
        if AppLaunchOptions.contains("-uiTestingResetStore") {
            try container.mainContext.delete(model: TimeEvent.self)
            try container.mainContext.delete(model: UserProfile.self)
            try container.mainContext.save()
        }
        if AppLaunchOptions.contains("-uiTestingSeeded"), try container.mainContext.fetchCount(FetchDescriptor<UserProfile>()) == 0 {
            try seedUITestProfile(in: container)
        }
        #endif
        return container
    }

    #if DEBUG
    private static func seedUITestProfile(in container: ModelContainer) throws {
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        let birthday = calendar.date(from: DateComponents(year: 2000, month: 4, day: 24)) ?? .now
        let profile = UserProfile(birthDate: birthday)
        if AppLaunchOptions.contains("-uiTestingAtEndpoint") {
            profile.birthDate = calendar.date(byAdding: .year, value: -90, to: calendar.startOfDay(for: .now)) ?? birthday
        }
        profile.setBirthday(profile.birthDate, calendar: calendar)
        context.insert(profile)
        if AppLaunchOptions.contains("-uiTestingSeedEvent") {
            context.insert(
                TimeEvent(
                    title: "生日",
                    symbolName: "birthday.cake.fill",
                    color: .amber,
                    recurrence: .yearly,
                    anchorDate: birthday
                )
            )
        }
        if AppLaunchOptions.contains("-uiTestingSeedWeeklyEvent") {
            context.insert(TimeEvent(title: "每周回顾", symbolName: "book.fill", recurrence: .weekly, anchorDate: .now))
        }
        if AppLaunchOptions.contains("-uiTestingSeedCalendarEvents") {
            context.insert(TimeEvent(title: "第一刻点", recurrence: .daily, anchorDate: .now))
            context.insert(TimeEvent(title: "第二刻点", recurrence: .daily, anchorDate: .now))
            context.insert(TimeEvent(title: "本月刻点", recurrence: .monthly, anchorDate: .now))
        }
        try context.save()
    }
    #endif
}

private struct StorageUnavailableView: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
    let retry: () -> Void

    var body: some View {
        ZStack {
            theme.background(for: colorScheme).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 20) {
                Text("暂时无法打开本地数据").font(.title2)
                Text("数据未被删除。请确认设备有可用空间，并在解锁设备后重试。")
                    .font(.body).foregroundStyle(theme.secondaryLabel(for: colorScheme))
                KeduActionButton(title: "重试", action: retry)
                    .accessibilityIdentifier("storage.retry")
            }.padding(28)
        }
        .accessibilityElement(children: .contain)
    }
}
