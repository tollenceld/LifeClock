import SwiftData
import SwiftUI

@main
struct KeduApp: App {
    private let modelContainer: ModelContainer
    @State private var theme = AppTheme()

    init() {
        let schema = Schema([UserProfile.self, TimeEvent.self])
        let isUITesting = CommandLine.arguments.contains("-uiTesting")
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isUITesting)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
            if CommandLine.arguments.contains("-uiTestingSeeded") {
                Self.seedUITestProfile(in: modelContainer)
            }
        } catch {
            fatalError("无法创建本地数据存储：\(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(theme)
        }
        .modelContainer(modelContainer)
    }

    private static func seedUITestProfile(in container: ModelContainer) {
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        let birthday = calendar.date(from: DateComponents(year: 2000, month: 4, day: 24)) ?? .now
        context.insert(UserProfile(birthDate: birthday))
        if CommandLine.arguments.contains("-uiTestingSeedEvent") {
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
        try? context.save()
    }
}
