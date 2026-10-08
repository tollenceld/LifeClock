import Foundation
import SwiftData

/// A versioned, inspectable file. Persistent models never cross the file boundary.
struct LocalBackup: Codable, Sendable {
    struct Profile: Codable, Sendable {
        let birthday: String
        let birthTimeZoneIdentifier: String?
        let targetAge: Int
        let weekStartsOnMonday: Bool
        let hapticsEnabled: Bool
    }

    struct Event: Codable, Sendable {
        let id: UUID
        let title: String
        let symbolName: String
        let color: String
        let recurrence: String
        let anchorDate: Date
        let anchorDateComponents: String?
        let createdAt: Date
        let updatedAt: Date
    }

    let format: String
    let version: Int
    let exportedAt: Date
    let profile: Profile
    let appearance: String
    let events: [Event]
    static let maximumBytes = 5 * 1_024 * 1_024

    @MainActor
    init(profile: UserProfile, events: [TimeEvent], appearance: AppAppearance, at date: Date = .now) {
        let calendar = ClockEngine.calendar(for: profile)
        format = "Kedu.LocalBackup"
        version = 1
        exportedAt = date
        self.profile = Profile(birthday: CivilBirthday.key(for: profile.birthday(in: calendar), calendar: calendar),
                               birthTimeZoneIdentifier: profile.birthTimeZoneIdentifier ?? calendar.timeZone.identifier,
                               targetAge: profile.targetAge, weekStartsOnMonday: profile.weekStartsOnMonday,
                               hapticsEnabled: profile.hapticsEnabled)
        self.appearance = appearance.rawValue
        self.events = events.map {
            Event(id: $0.id, title: $0.title, symbolName: $0.symbolName, color: $0.colorRawValue,
                  recurrence: $0.recurrenceRawValue, anchorDate: $0.anchorDate,
                  anchorDateComponents: $0.recurrence == .once ? nil : ($0.anchorDateComponents ?? CivilSchedule.key(for: $0.anchorDate, calendar: calendar)),
                  createdAt: $0.createdAt, updatedAt: $0.updatedAt)
        }
    }

    func encoded() throws -> Data {
        try validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(self)
        guard data.count <= Self.maximumBytes else { throw BackupError.tooLarge }
        return data
    }

    static func decode(_ data: Data, at now: Date = .now) throws -> LocalBackup {
        guard data.count <= maximumBytes else { throw BackupError.tooLarge }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let backup: LocalBackup
        do { backup = try decoder.decode(Self.self, from: data) }
        catch { throw BackupError.invalidFile }
        try backup.validate(at: now)
        return backup
    }

    func validate(at now: Date = .now) throws {
        guard format == "Kedu.LocalBackup" else { throw BackupError.invalidFile }
        guard version == 1 else { throw BackupError.unsupportedVersion }
        var calendar = CivilBirthday.calendar
        if let identifier = profile.birthTimeZoneIdentifier {
            guard let zone = TimeZone(identifier: identifier) else { throw BackupError.invalidFile }
            calendar.timeZone = zone
        }
        guard let birthday = CivilBirthday.date(from: profile.birthday, calendar: calendar),
              CivilBirthday.allowedRange(at: now, calendar: calendar).contains(birthday),
              (1...150).contains(profile.targetAge), AppAppearance(rawValue: appearance) != nil,
              Self.validDate(exportedAt), events.count <= 10_000,
              Set(events.map(\.id)).count == events.count else { throw BackupError.invalidFile }
        for event in events {
            guard !event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  event.title.count <= 10_000, !event.symbolName.isEmpty, event.symbolName.count <= 100,
                  EventColor(rawValue: event.color) != nil, RecurrenceRule(rawValue: event.recurrence) != nil,
                  Self.validDate(event.anchorDate), Self.validDate(event.createdAt), Self.validDate(event.updatedAt)
            else { throw BackupError.invalidFile }
            if let key = event.anchorDateComponents {
                guard CivilSchedule.date(from: key, calendar: calendar) != nil else { throw BackupError.invalidFile }
            }
        }
    }

    private static func validDate(_ date: Date) -> Bool {
        date.timeIntervalSinceReferenceDate.isFinite && date >= .distantPast && date <= .distantFuture
    }

    /// Read and validate everything before touching any live records. One save is
    /// the commit point; an error restores the original profile and event objects.
    @MainActor
    func restore(in context: ModelContext, into existingProfile: UserProfile,
                 commit: ((ModelContext) throws -> Void)? = nil) throws {
        try validate()
        let oldEvents = try context.fetch(FetchDescriptor<TimeEvent>())
        let oldProfile = (birthDate: existingProfile.birthDate, components: existingProfile.birthDateComponents,
                          zone: existingProfile.birthTimeZoneIdentifier, age: existingProfile.targetAge,
                          monday: existingProfile.weekStartsOnMonday, haptics: existingProfile.hapticsEnabled)
        let oldRecords = oldEvents.map {
            Event(id: $0.id, title: $0.title, symbolName: $0.symbolName, color: $0.colorRawValue,
                  recurrence: $0.recurrenceRawValue, anchorDate: $0.anchorDate,
                  anchorDateComponents: $0.anchorDateComponents, createdAt: $0.createdAt, updatedAt: $0.updatedAt)
        }
        let autosave = context.autosaveEnabled
        context.autosaveEnabled = false
        defer { context.autosaveEnabled = autosave }
        do {
            let incomingIDs = Set(events.map(\.id))
            let existingByID = Dictionary(uniqueKeysWithValues: oldEvents.map { ($0.id, $0) })
            for event in oldEvents where !incomingIDs.contains(event.id) { context.delete(event) }
            var calendar = CivilBirthday.calendar
            if let identifier = profile.birthTimeZoneIdentifier, let zone = TimeZone(identifier: identifier) {
                calendar.timeZone = zone
            }
            guard let birthday = CivilBirthday.date(from: profile.birthday, calendar: calendar) else {
                throw BackupError.invalidFile
            }
            existingProfile.setBirthday(birthday, calendar: calendar)
            existingProfile.targetAge = profile.targetAge
            existingProfile.weekStartsOnMonday = profile.weekStartsOnMonday
            existingProfile.hapticsEnabled = profile.hapticsEnabled
            for record in events {
                let event = existingByID[record.id] ?? TimeEvent(id: record.id, title: record.title, symbolName: record.symbolName,
                                      color: EventColor(rawValue: record.color) ?? .jade,
                                      recurrence: RecurrenceRule(rawValue: record.recurrence) ?? .once,
                                      anchorDate: record.anchorDate, createdAt: record.createdAt, updatedAt: record.updatedAt)
                event.title = record.title
                event.symbolName = record.symbolName
                event.colorRawValue = record.color
                event.recurrenceRawValue = record.recurrence
                event.anchorDate = record.anchorDate
                event.createdAt = record.createdAt
                event.updatedAt = record.updatedAt
                event.anchorDateComponents = record.anchorDateComponents
                if existingByID[record.id] == nil { context.insert(event) }
            }
            if let commit { try commit(context) } else { try context.save() }
        } catch {
            context.rollback()
            // Some supported SwiftData runtimes leave an already-loaded model's
            // property cache at the failed value. Restore the retained objects too.
            existingProfile.birthDate = oldProfile.birthDate
            existingProfile.birthDateComponents = oldProfile.components
            existingProfile.birthTimeZoneIdentifier = oldProfile.zone
            existingProfile.targetAge = oldProfile.age
            existingProfile.weekStartsOnMonday = oldProfile.monday
            existingProfile.hapticsEnabled = oldProfile.haptics
            for (event, record) in zip(oldEvents, oldRecords) {
                event.title = record.title
                event.symbolName = record.symbolName
                event.colorRawValue = record.color
                event.recurrenceRawValue = record.recurrence
                event.anchorDate = record.anchorDate
                event.anchorDateComponents = record.anchorDateComponents
                event.createdAt = record.createdAt
                event.updatedAt = record.updatedAt
            }
            throw error
        }
    }
}

enum BackupError: LocalizedError {
    case tooLarge, invalidFile, unsupportedVersion
    var errorDescription: String? {
        switch self {
        case .tooLarge: "备份文件过大，请选择小于 5 MB 的刻度备份。"
        case .invalidFile: "这不是有效的刻度备份，当前数据未被更改。"
        case .unsupportedVersion: "这份备份来自更新版本的刻度，请更新 App 后再试。"
        }
    }
}
