import Foundation
import SwiftData

@Model
final class TimeEvent {
    @Attribute(.unique) var id: UUID
    var title: String
    var symbolName: String
    var colorRawValue: String
    var recurrenceRawValue: String
    var anchorDate: Date
    var anchorDateComponents: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        symbolName: String = "circle.fill",
        color: EventColor = .jade,
        recurrence: RecurrenceRule,
        anchorDate: Date,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.symbolName = symbolName
        self.colorRawValue = color.rawValue
        self.recurrenceRawValue = recurrence.rawValue
        self.anchorDate = anchorDate
        self.anchorDateComponents = nil
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var recurrence: RecurrenceRule {
        get { RecurrenceRule(rawValue: recurrenceRawValue) ?? .once }
        set { recurrenceRawValue = newValue.rawValue }
    }

    var eventColor: EventColor {
        get { EventColor(rawValue: colorRawValue) ?? .jade }
        set { colorRawValue = newValue.rawValue }
    }

    var scale: ClockScale? { recurrence.scale }

    func anchor(in calendar: Calendar) -> Date {
        guard recurrence != .once, let key = anchorDateComponents,
              let date = CivilSchedule.date(from: key, calendar: calendar) else { return anchorDate }
        return date
    }

    func setAnchor(_ date: Date, calendar: Calendar) {
        anchorDate = date
        anchorDateComponents = recurrence == .once ? nil : CivilSchedule.key(for: date, calendar: calendar)
    }
}

enum CivilSchedule {
    static func key(for date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return CivilBirthday.key(for: date, calendar: calendar) + String(format: "T%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    static func date(from key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "T", omittingEmptySubsequences: false)
        guard parts.count == 2, let day = CivilBirthday.date(from: String(parts[0]), calendar: calendar) else { return nil }
        let time = parts[1].split(separator: ":", omittingEmptySubsequences: false)
        guard time.count == 2, let hour = Int(time[0]), let minute = Int(time[1]),
              (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        // The civil time may fall in a DST gap in the destination zone. The next
        // valid local time is used, matching ClockEngine's daily recurrence rule.
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)
    }
}

enum EventSymbol {
    static let choices = ["circle.fill", "birthday.cake.fill", "creditcard.fill", "pills.fill",
                          "figure.run", "briefcase.fill", "heart.fill", "book.fill"]
    static func title(for symbol: String) -> String {
        switch symbol {
        case "birthday.cake.fill": "生日"
        case "creditcard.fill": "账单"
        case "pills.fill": "健康"
        case "figure.run": "运动"
        case "briefcase.fill": "工作"
        case "heart.fill": "心愿"
        case "book.fill": "阅读"
        default: "圆点"
        }
    }
}
