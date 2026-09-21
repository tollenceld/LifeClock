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
}
