import Foundation

struct EventMarkerSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let symbolName: String
    let color: EventColor
    let index: Int
    let occurrence: Date
    let isPast: Bool
}

struct ClockSnapshot: Equatable, Sendable {
    let scale: ClockScale
    let interval: DateInterval
    let progress: Double
    let completedUnits: Int
    let totalUnits: Int
    let gridColumns: Int
    let headline: String
    let progressText: String
    let countText: String
    let markers: [EventMarkerSnapshot]

    var currentIndex: Int {
        guard totalUnits > 0 else { return 0 }
        return min(totalUnits - 1, max(0, Int(progress * Double(totalUnits))))
    }

    func marker(at index: Int) -> EventMarkerSnapshot? {
        markers.first { $0.index == index }
    }

    func nearestMarker(to date: Date) -> EventMarkerSnapshot? {
        markers.first(where: { $0.occurrence >= date }) ?? markers.last
    }
}

struct ClockUnitSnapshot: Identifiable, Equatable, Sendable {
    let id: Int
    let interval: DateInterval?
    let label: String?
    let isPlaceholder: Bool
    let progress: Double
    let markerIDs: [UUID]
}

struct ScaleProgressSnapshot: Identifiable, Equatable, Sendable {
    var id: ClockScale { scale }

    let scale: ClockScale
    let progress: Double
    let progressText: String
}

struct ClockPresentationSnapshot: Identifiable, Equatable, Sendable {
    let calendar: Calendar
    var id: ClockScale { scale }

    let scale: ClockScale
    let clock: ClockSnapshot
    let units: [ClockUnitSnapshot]
    let stageTitle: String
    let stageDetail: String
    let remainingText: String
    let focusProgress: [Double]
    let relatedProgress: [ScaleProgressSnapshot]
    let fineProgress: Double?
    let periodEventCount: Int
}

struct ClockDashboardSnapshot: Equatable, Sendable {
    let presentations: [ClockPresentationSnapshot]

    subscript(scale: ClockScale) -> ClockPresentationSnapshot {
        presentations[Int(scale.position)]
    }
}

enum ClockEngine {
    static func snapshot(
        scale: ClockScale,
        at now: Date,
        calendar sourceCalendar: Calendar = .autoupdatingCurrent,
        profile: UserProfile,
        events: [TimeEvent]
    ) -> ClockSnapshot {
        var calendar = sourceCalendar
        calendar.locale = Locale(identifier: "zh_Hans_CN")
        calendar.firstWeekday = profile.weekStartsOnMonday ? 2 : 1

        let interval = interval(for: scale, at: now, calendar: calendar, profile: profile)
        let duration = max(1, interval.duration)
        let progress = min(1, max(0, now.timeIntervalSince(interval.start) / duration))
        let totalUnits = unitCount(for: scale, interval: interval, calendar: calendar, profile: profile)
        let completedUnits = min(totalUnits, max(0, Int(floor(progress * Double(totalUnits)))))
        let matchingEvents = events.filter { $0.scale == scale }
        let markers = matchingEvents.compactMap { event -> EventMarkerSnapshot? in
            guard let occurrence = occurrence(
                for: event,
                scale: scale,
                interval: interval,
                calendar: calendar,
                profile: profile
            ) else { return nil }

            let ratio = occurrence.timeIntervalSince(interval.start) / duration
            let index = min(totalUnits - 1, max(0, Int(floor(ratio * Double(totalUnits)))))
            return EventMarkerSnapshot(
                id: event.id,
                title: event.title,
                symbolName: event.symbolName,
                color: event.eventColor,
                index: index,
                occurrence: occurrence,
                isPast: occurrence < now
            )
        }
        .sorted { $0.occurrence < $1.occurrence }

        return ClockSnapshot(
            scale: scale,
            interval: interval,
            progress: progress,
            completedUnits: completedUnits,
            totalUnits: totalUnits,
            gridColumns: gridColumns(for: scale),
            headline: headline(for: scale, at: now, calendar: calendar, profile: profile),
            progressText: progress.formatted(.percent.precision(.fractionLength(1))),
            countText: countText(
                scale: scale,
                completed: completedUnits,
                total: totalUnits
            ),
            markers: markers
        )
    }

    static func dashboard(
        at now: Date,
        calendar sourceCalendar: Calendar = .autoupdatingCurrent,
        profile: UserProfile,
        events: [TimeEvent]
    ) -> ClockDashboardSnapshot {
        var calendar = sourceCalendar
        calendar.locale = Locale(identifier: "zh_Hans_CN")
        calendar.firstWeekday = profile.weekStartsOnMonday ? 2 : 1

        let clocks = ClockScale.allCases.map { scale in
            snapshot(
                scale: scale,
                at: now,
                calendar: calendar,
                profile: profile,
                events: events
            )
        }

        let presentations = clocks.map { clock in
            presentation(
                for: clock,
                clocks: clocks,
                at: now,
                calendar: calendar,
                profile: profile
            )
        }
        return ClockDashboardSnapshot(presentations: presentations)
    }

    static func calendar(for profile: UserProfile, timeZone: TimeZone = .autoupdatingCurrent) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_Hans_CN")
        calendar.timeZone = timeZone
        calendar.firstWeekday = profile.weekStartsOnMonday ? 2 : 1
        return calendar
    }

    private static func interval(
        for scale: ClockScale,
        at now: Date,
        calendar: Calendar,
        profile: UserProfile
    ) -> DateInterval {
        switch scale {
        case .life:
            let start = calendar.startOfDay(for: profile.birthDate)
            let end = calendar.date(byAdding: .year, value: profile.targetAge, to: start)
                ?? start.addingTimeInterval(TimeInterval(profile.targetAge) * 365.25 * 86_400)
            return DateInterval(start: start, end: end)
        case .year:
            return calendar.dateInterval(of: .year, for: now) ?? fallbackDayInterval(now, calendar: calendar)
        case .month:
            return calendar.dateInterval(of: .month, for: now) ?? fallbackDayInterval(now, calendar: calendar)
        case .day:
            return calendar.dateInterval(of: .day, for: now) ?? fallbackDayInterval(now, calendar: calendar)
        }
    }

    private static func fallbackDayInterval(_ date: Date, calendar: Calendar) -> DateInterval {
        let start = calendar.startOfDay(for: date)
        return DateInterval(start: start, duration: 86_400)
    }

    private static func presentation(
        for clock: ClockSnapshot,
        clocks: [ClockSnapshot],
        at now: Date,
        calendar: Calendar,
        profile: UserProfile
    ) -> ClockPresentationSnapshot {
        let stage = stageCopy(for: clock, at: now, calendar: calendar, profile: profile)
        let relationScales = relationshipScales(for: clock.scale)
        let relatedProgress = relationScales.map { scale in
            let snapshot = clocks[Int(scale.position)]
            return ScaleProgressSnapshot(
                scale: scale,
                progress: snapshot.progress,
                progressText: snapshot.progressText
            )
        }

        return ClockPresentationSnapshot(
            calendar: calendar,
            scale: clock.scale,
            clock: clock,
            units: presentationUnits(for: clock, at: now, calendar: calendar, profile: profile),
            stageTitle: stage.title,
            stageDetail: stage.detail,
            remainingText: stage.remaining,
            focusProgress: focusProgress(for: clock, at: now, calendar: calendar, profile: profile),
            relatedProgress: relatedProgress,
            fineProgress: fineProgress(for: clock.scale, at: now, calendar: calendar),
            periodEventCount: clock.markers.count
        )
    }

    private static func relationshipScales(for scale: ClockScale) -> [ClockScale] {
        switch scale {
        case .life, .year: [.life, .year, .month]
        case .month, .day: [.year, .month, .day]
        }
    }

    private static func presentationUnits(
        for clock: ClockSnapshot,
        at now: Date,
        calendar: Calendar,
        profile: UserProfile
    ) -> [ClockUnitSnapshot] {
        switch clock.scale {
        case .life:
            return lifeUnits(clock: clock, at: now, calendar: calendar, profile: profile)
        case .year:
            return sequentialUnits(
                clock: clock,
                component: .day,
                count: clock.totalUnits,
                at: now,
                calendar: calendar,
                label: { date, _ in calendar.component(.day, from: date) == 1
                    ? "\(calendar.component(.month, from: date))月"
                    : nil
                }
            )
        case .month:
            return monthUnits(clock: clock, at: now, calendar: calendar)
        case .day:
            return dayHourUnits(clock: clock, at: now, calendar: calendar)
        }
    }

    private static func lifeUnits(
        clock: ClockSnapshot,
        at now: Date,
        calendar: Calendar,
        profile: UserProfile
    ) -> [ClockUnitSnapshot] {
        (0..<profile.targetAge).compactMap { age in
            guard
                let start = calendar.date(byAdding: .year, value: age, to: profile.birthDate),
                let end = calendar.date(byAdding: .year, value: age + 1, to: profile.birthDate)
            else { return nil }
            let interval = DateInterval(start: start, end: end)
            return makeUnit(
                id: age,
                interval: interval,
                label: age.isMultiple(of: 10) ? "\(age)" : nil,
                at: now,
                markers: clock.markers
            )
        }
    }

    private static func sequentialUnits(
        clock: ClockSnapshot,
        component: Calendar.Component,
        count: Int,
        at now: Date,
        calendar: Calendar,
        label: (Date, Int) -> String?
    ) -> [ClockUnitSnapshot] {
        (0..<count).compactMap { index in
            guard
                let start = calendar.date(byAdding: component, value: index, to: clock.interval.start),
                let end = calendar.date(byAdding: component, value: index + 1, to: clock.interval.start),
                start < clock.interval.end
            else { return nil }
            return makeUnit(
                id: index,
                interval: DateInterval(start: start, end: min(end, clock.interval.end)),
                label: label(start, index),
                at: now,
                markers: clock.markers
            )
        }
    }

    private static func monthUnits(
        clock: ClockSnapshot,
        at now: Date,
        calendar: Calendar
    ) -> [ClockUnitSnapshot] {
        let weekday = calendar.component(.weekday, from: clock.interval.start)
        let leadingCount = (weekday - calendar.firstWeekday + 7) % 7
        var result = (0..<leadingCount).map { index in
            ClockUnitSnapshot(
                id: index,
                interval: nil,
                label: nil,
                isPlaceholder: true,
                progress: 0,
                markerIDs: []
            )
        }

        let days = sequentialUnits(
            clock: clock,
            component: .day,
            count: clock.totalUnits,
            at: now,
            calendar: calendar,
            label: { date, _ in "\(calendar.component(.day, from: date))" }
        )
        result.append(contentsOf: days.enumerated().map { offset, unit in
            ClockUnitSnapshot(
                id: leadingCount + offset,
                interval: unit.interval,
                label: unit.label,
                isPlaceholder: false,
                progress: unit.progress,
                markerIDs: unit.markerIDs
            )
        })

        while result.count < 42 {
            result.append(ClockUnitSnapshot(
                id: result.count,
                interval: nil,
                label: nil,
                isPlaceholder: true,
                progress: 0,
                markerIDs: []
            ))
        }
        return Array(result.prefix(42))
    }

    private static func dayHourUnits(
        clock: ClockSnapshot,
        at now: Date,
        calendar: Calendar
    ) -> [ClockUnitSnapshot] {
        var units: [ClockUnitSnapshot] = []
        var cursor = clock.interval.start

        while cursor < clock.interval.end, units.count < 25 {
            guard let next = calendar.date(byAdding: .hour, value: 1, to: cursor), next > cursor else { break }
            let end = min(next, clock.interval.end)
            let label = String(format: "%02d", calendar.component(.hour, from: cursor))
            units.append(makeUnit(
                id: units.count,
                interval: DateInterval(start: cursor, end: end),
                label: label,
                at: now,
                markers: clock.markers
            ))
            cursor = end
        }
        return units
    }

    private static func makeUnit(
        id: Int,
        interval: DateInterval,
        label: String?,
        at now: Date,
        markers: [EventMarkerSnapshot]
    ) -> ClockUnitSnapshot {
        let progress: Double
        if now <= interval.start {
            progress = 0
        } else if now >= interval.end {
            progress = 1
        } else {
            progress = min(1, max(0, now.timeIntervalSince(interval.start) / max(1, interval.duration)))
        }
        return ClockUnitSnapshot(
            id: id,
            interval: interval,
            label: label,
            isPlaceholder: false,
            progress: progress,
            markerIDs: markers.filter { interval.contains($0.occurrence) }.map(\.id)
        )
    }

    private static func focusProgress(
        for clock: ClockSnapshot,
        at now: Date,
        calendar: Calendar,
        profile: UserProfile
    ) -> [Double] {
        switch clock.scale {
        case .life:
            let age = max(0, calendar.dateComponents([.year], from: profile.birthDate, to: now).year ?? 0)
            let decadeStart = age / 10 * 10
            return (decadeStart..<(decadeStart + 10)).map { year in
                guard
                    year < profile.targetAge,
                    let start = calendar.date(byAdding: .year, value: year, to: profile.birthDate),
                    let end = calendar.date(byAdding: .year, value: year + 1, to: profile.birthDate)
                else { return 0 }
                return unitProgress(at: now, interval: DateInterval(start: start, end: end))
            }
        case .year:
            return (0..<12).compactMap { monthOffset in
                guard
                    let start = calendar.date(byAdding: .month, value: monthOffset, to: clock.interval.start),
                    let end = calendar.date(byAdding: .month, value: monthOffset + 1, to: clock.interval.start)
                else { return nil }
                return unitProgress(at: now, interval: DateInterval(start: start, end: end))
            }
        case .month:
            let units = monthUnits(clock: clock, at: now, calendar: calendar)
            return stride(from: 0, to: units.count, by: 7).map { start in
                Array(units[start..<min(start + 7, units.count)]).map(\.progress).max() ?? 0
            }
        case .day:
            return [0, 6, 12, 18].map { hour in
                let start = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: clock.interval.start)
                    ?? clock.interval.start
                let nextHour = hour == 18 ? 24 : hour + 6
                let end = nextHour == 24
                    ? clock.interval.end
                    : (calendar.date(bySettingHour: nextHour, minute: 0, second: 0, of: clock.interval.start)
                        ?? clock.interval.end)
                return unitProgress(at: now, interval: DateInterval(start: start, end: end))
            }
        }
    }

    private static func fineProgress(
        for scale: ClockScale,
        at now: Date,
        calendar: Calendar
    ) -> Double? {
        guard scale == .day, let hour = calendar.dateInterval(of: .hour, for: now) else { return nil }
        return unitProgress(at: now, interval: hour)
    }

    private static func unitProgress(at now: Date, interval: DateInterval) -> Double {
        if now <= interval.start { return 0 }
        if now >= interval.end { return 1 }
        return min(1, max(0, now.timeIntervalSince(interval.start) / max(1, interval.duration)))
    }

    private static func stageCopy(
        for clock: ClockSnapshot,
        at now: Date,
        calendar: Calendar,
        profile: UserProfile
    ) -> (title: String, detail: String, remaining: String) {
        let weekday = shortWeekday(at: now, calendar: calendar)
        switch clock.scale {
        case .life:
            let age = max(0, calendar.dateComponents([.year], from: profile.birthDate, to: now).year ?? 0)
            let decade = age / 10 + 1
            let decadeStart = age / 10 * 10
            let decadeEnd = min(profile.targetAge - 1, decadeStart + 9)
            let nextBirthday = calendar.date(byAdding: .year, value: age + 1, to: profile.birthDate)
                ?? clock.interval.end
            return (
                "第\(decade)个十年 · \(age)–\(age + 1)岁",
                "当前十年 \(decadeStart)–\(decadeEnd)岁",
                remainingDaysText(prefix: "距\(age + 1)岁", from: now, to: nextBirthday, calendar: calendar)
            )
        case .year:
            let month = calendar.component(.month, from: now)
            let quarter = (month - 1) / 3 + 1
            let week = calendar.component(.weekOfYear, from: now)
            return (
                "第\(quarter)季度 · \(month)月",
                "本年第\(week)周",
                remainingDaysText(prefix: "距年末", from: now, to: clock.interval.end, calendar: calendar)
            )
        case .month:
            let week = calendar.component(.weekOfMonth, from: now)
            let counts = workdayCounts(in: clock.interval, calendar: calendar)
            return (
                "本月第\(week)周 · \(weekday)",
                "工作日 \(counts.workdays) · 周末 \(counts.weekends)",
                remainingDaysText(prefix: "距下月", from: now, to: clock.interval.end, calendar: calendar)
            )
        case .day:
            let hour = calendar.component(.hour, from: now)
            let minute = calendar.component(.minute, from: now)
            return (
                "\(dayPhase(at: now, calendar: calendar)) · \(String(format: "%02d", hour))时",
                "当前小时 \(String(format: "%02d", minute)) / 60分",
                remainingClockText(prefix: "距午夜", from: now, to: clock.interval.end)
            )
        }
    }

    private static func remainingDaysText(
        prefix: String,
        from now: Date,
        to end: Date,
        calendar: Calendar
    ) -> String {
        let start = calendar.startOfDay(for: now)
        let days = max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
        return "\(prefix) \(days)天"
    }

    private static func remainingClockText(prefix: String, from now: Date, to end: Date) -> String {
        let minutes = max(0, Int(ceil(end.timeIntervalSince(now) / 60)))
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(prefix) \(remainder)分" }
        return "\(prefix) \(hours)小时\(String(format: "%02d", remainder))分"
    }

    private static func dayPhase(at date: Date, calendar: Calendar) -> String {
        switch calendar.component(.hour, from: date) {
        case 0..<6: "凌晨"
        case 6..<12: "上午"
        case 12..<18: "下午"
        default: "夜间"
        }
    }

    private static func shortWeekday(at date: Date, calendar: Calendar) -> String {
        let symbols = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
        let index = min(symbols.count - 1, max(0, calendar.component(.weekday, from: date) - 1))
        return symbols[index]
    }

    private static func workdayCounts(
        in interval: DateInterval,
        calendar: Calendar
    ) -> (workdays: Int, weekends: Int) {
        var workdays = 0
        var weekends = 0
        var cursor = interval.start
        while cursor < interval.end {
            if calendar.isDateInWeekend(cursor) {
                weekends += 1
            } else {
                workdays += 1
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return (workdays, weekends)
    }

    private static func unitCount(
        for scale: ClockScale,
        interval: DateInterval,
        calendar: Calendar,
        profile: UserProfile
    ) -> Int {
        switch scale {
        case .life:
            return max(1, profile.targetAge * 12)
        case .year, .month:
            return max(1, calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1)
        case .day:
            return max(1, Int((interval.duration / 3_600).rounded()))
        }
    }

    private static func gridColumns(for scale: ClockScale) -> Int {
        switch scale {
        case .life: 24
        case .year: 20
        case .month: 7
        case .day: 6
        }
    }

    private static func headline(
        for scale: ClockScale,
        at now: Date,
        calendar: Calendar,
        profile: UserProfile
    ) -> String {
        switch scale {
        case .life:
            let years = max(0, calendar.dateComponents([.year], from: profile.birthDate, to: now).year ?? 0)
            return "\(years)岁"
        case .year:
            return String(calendar.component(.year, from: now))
        case .month:
            return "\(calendar.component(.month, from: now))月"
        case .day:
            return "\(calendar.component(.day, from: now))日"
        }
    }

    private static func countText(scale: ClockScale, completed: Int, total: Int) -> String {
        let unit: String = switch scale {
        case .life: "个月"
        case .year, .month: "天"
        case .day: "小时"
        }
        return "\(completed.formatted()) / \(total.formatted()) \(unit)"
    }

    private static func occurrence(
        for event: TimeEvent,
        scale: ClockScale,
        interval: DateInterval,
        calendar: Calendar,
        profile: UserProfile
    ) -> Date? {
        guard event.recurrence.scale == scale else { return nil }
        let components = calendar.dateComponents([.month, .day, .hour, .minute], from: event.anchorDate)

        let date: Date?
        switch event.recurrence {
        case .once:
            date = event.anchorDate
        case .yearly:
            date = dateInMonth(
                year: calendar.component(.year, from: interval.start),
                month: components.month ?? 1,
                day: components.day ?? 1,
                hour: components.hour ?? 0,
                minute: components.minute ?? 0,
                calendar: calendar
            )
        case .monthly:
            date = dateInMonth(
                year: calendar.component(.year, from: interval.start),
                month: calendar.component(.month, from: interval.start),
                day: components.day ?? 1,
                hour: components.hour ?? 0,
                minute: components.minute ?? 0,
                calendar: calendar
            )
        case .weekly:
            return nil
        case .daily:
            date = calendar.date(
                bySettingHour: components.hour ?? 0,
                minute: components.minute ?? 0,
                second: 0,
                of: interval.start
            )
        }

        guard let date, date >= interval.start, date < interval.end else { return nil }
        if event.recurrence == .once {
            let lifeEnd = calendar.date(byAdding: .year, value: profile.targetAge, to: profile.birthDate) ?? interval.end
            guard date >= profile.birthDate, date < lifeEnd else { return nil }
        }
        return date
    }

    private static func dateInMonth(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date? {
        guard let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1)) else {
            return nil
        }
        let validDays = calendar.range(of: .day, in: .month, for: firstDay) ?? 1..<2
        let clampedDay = min(max(day, validDays.lowerBound), validDays.upperBound - 1)
        return calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: clampedDay,
            hour: hour,
            minute: minute
        ))
    }
}
