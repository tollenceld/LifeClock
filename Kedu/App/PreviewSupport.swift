import Foundation
import SwiftData

@MainActor
enum PreviewSupport {
    enum Scenario {
        case empty
        case single
        case multiple
    }

    static func container(_ scenario: Scenario) -> ModelContainer {
        let schema = Schema([UserProfile.self, TimeEvent.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        let birthday = calendar.date(from: DateComponents(year: 2000, month: 4, day: 24)) ?? .now
        context.insert(UserProfile(birthDate: birthday))

        if scenario != .empty {
            context.insert(TimeEvent(
                title: "生日",
                symbolName: "birthday.cake.fill",
                color: .jade,
                recurrence: .yearly,
                anchorDate: birthday
            ))
        }

        if scenario == .multiple {
            context.insert(TimeEvent(
                title: "还信用卡",
                symbolName: "creditcard.fill",
                color: .amber,
                recurrence: .monthly,
                anchorDate: calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 9)) ?? .now
            ))
            context.insert(TimeEvent(
                title: "锻炼",
                symbolName: "figure.run",
                color: .cobalt,
                recurrence: .daily,
                anchorDate: calendar.date(from: DateComponents(year: 2026, month: 8, day: 30, hour: 18)) ?? .now
            ))
        }

        try? context.save()
        return container
    }

    static func profile() -> UserProfile {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        let birthday = calendar.date(from: DateComponents(year: 2000, month: 4, day: 24)) ?? .now
        return UserProfile(birthDate: birthday)
    }
}
