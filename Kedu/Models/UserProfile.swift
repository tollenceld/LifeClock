import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var birthDate: Date
    // Optional for lightweight migration of existing stores. A birthday is a civil date,
    // so crossing time zones must not turn April 24 into April 23.
    var birthDateComponents: String?
    var birthTimeZoneIdentifier: String?
    var targetAge: Int
    var weekStartsOnMonday: Bool
    var onboardingCompleted: Bool
    var hapticsEnabled: Bool

    init(
        id: UUID = UUID(),
        birthDate: Date,
        targetAge: Int = 85,
        weekStartsOnMonday: Bool = true,
        onboardingCompleted: Bool = true,
        hapticsEnabled: Bool = true
    ) {
        self.id = id
        self.birthDate = birthDate
        self.birthDateComponents = nil
        self.birthTimeZoneIdentifier = nil
        self.targetAge = targetAge
        self.weekStartsOnMonday = weekStartsOnMonday
        self.onboardingCompleted = onboardingCompleted
        self.hapticsEnabled = hapticsEnabled
    }

    func birthday(in calendar: Calendar) -> Date {
        guard let key = birthDateComponents,
              let date = CivilBirthday.date(from: key, calendar: calendar) else { return birthDate }
        return date
    }

    func setBirthday(_ date: Date, calendar: Calendar) {
        birthDate = calendar.startOfDay(for: date)
        birthDateComponents = CivilBirthday.key(for: birthDate, calendar: calendar)
        birthTimeZoneIdentifier = calendar.timeZone.identifier
    }

    func lifeCalendar(from calendar: Calendar) -> Calendar {
        guard let identifier = birthTimeZoneIdentifier, let zone = TimeZone(identifier: identifier) else { return calendar }
        var fixed = calendar
        fixed.timeZone = zone
        return fixed
    }
}

enum CivilBirthday {
    static var calendar: Calendar { Calendar(identifier: .gregorian) }

    static func key(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 2000, parts.month ?? 1, parts.day ?? 1)
    }

    static func date(from key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              (1...9999).contains(year), (1...12).contains(month), (1...31).contains(day),
              let date = calendar.date(from: DateComponents(year: year, month: month, day: day)),
              self.key(for: date, calendar: calendar) == key else { return nil }
        return calendar.startOfDay(for: date)
    }

    static func allowedRange(at now: Date = .now, calendar: Calendar = calendar) -> ClosedRange<Date> {
        let end = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .year, value: -150, to: end) ?? end
        return start...end
    }
}
