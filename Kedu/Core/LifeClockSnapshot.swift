import Foundation

/// A date-only birthday evaluated in the supplied calendar and time zone.
/// All values come from one instant so the two faces remain complementary.
struct LifeClockSnapshot: Equatable, Sendable {
    let date: Date
    let age: Double
    let remainingYears: Double
    let progress: Double
    let remainingProgress: Double
    let isAtEnd: Bool
    let birthInstant: Date
    let targetInstant: Date
    let elapsedSeconds: TimeInterval
    let remainingSeconds: TimeInterval

    init(at date: Date, calendar: Calendar, birthDate: Date, targetAge: Int) {
        self.date = date
        let birth = calendar.startOfDay(for: birthDate)
        let targetAge = max(0, targetAge)
        let target = Self.birthday(atAge: targetAge, birth: birth, calendar: calendar)
        birthInstant = birth
        targetInstant = target
        elapsedSeconds = max(0, date.timeIntervalSince(birth))
        remainingSeconds = max(0, target.timeIntervalSince(date))

        if date < birth {
            age = 0
        } else {
            // Calendar year differences need correction around February 29:
            // the non-leap birthday is February 28, not March 1.
            var wholeYears = max(0, calendar.dateComponents([.year], from: birth, to: date).year ?? 0)
            var lastBirthday = Self.birthday(atAge: wholeYears, birth: birth, calendar: calendar)
            while wholeYears > 0, lastBirthday > date {
                wholeYears -= 1
                lastBirthday = Self.birthday(atAge: wholeYears, birth: birth, calendar: calendar)
            }
            var nextBirthday = Self.birthday(atAge: wholeYears + 1, birth: birth, calendar: calendar)
            while nextBirthday <= date, nextBirthday > lastBirthday {
                wholeYears += 1
                lastBirthday = nextBirthday
                nextBirthday = Self.birthday(atAge: wholeYears + 1, birth: birth, calendar: calendar)
            }
            let yearDuration = max(1, nextBirthday.timeIntervalSince(lastBirthday))
            age = Double(wholeYears) + max(0, date.timeIntervalSince(lastBirthday)) / yearDuration
        }

        remainingYears = max(0, Double(targetAge) - age)
        isAtEnd = date >= target
        if isAtEnd {
            progress = 1
        } else {
            progress = min(1, max(0, date.timeIntervalSince(birth) / max(1, target.timeIntervalSince(birth))))
        }
        remainingProgress = 1 - progress
    }

    private static func birthday(atAge age: Int, birth: Date, calendar: Calendar) -> Date {
        // Add years to the first of the birth month before restoring the day,
        // avoiding leap-day overflow and preserving local midnight across DST.
        guard
            let birthMonth = calendar.dateInterval(of: .month, for: birth)?.start,
            let anniversaryMonth = calendar.date(byAdding: .year, value: age, to: birthMonth),
            let days = calendar.range(of: .day, in: .month, for: anniversaryMonth),
            let anniversary = calendar.date(
                byAdding: .day,
                value: min(calendar.component(.day, from: birth), days.upperBound - 1) - 1,
                to: anniversaryMonth
            )
        else {
            return calendar.date(byAdding: .year, value: age, to: birth)
                ?? birth.addingTimeInterval(Double(age) * 365.25 * 86_400)
        }
        return calendar.startOfDay(for: anniversary)
    }
}
