import Foundation
import SwiftData
import Testing
@testable import Kedu

struct ClockEngineTests {
    private func calendar(_ identifier: String = "Asia/Shanghai") -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_Hans_CN")
        calendar.timeZone = TimeZone(identifier: identifier)!
        calendar.firstWeekday = 2
        return calendar
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int = 0,
        _ minute: Int = 0,
        calendar: Calendar? = nil
    ) -> Date {
        let calendar = calendar ?? self.calendar()
        return calendar.date(from: DateComponents(
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    @Test("闰年包含 366 个日点")
    func leapYearHas366Days() {
        let calendar = calendar()
        let profile = UserProfile(birthDate: date(2000, 4, 24))
        let snapshot = ClockEngine.snapshot(
            scale: .year,
            at: date(2024, 8, 29, 12),
            calendar: calendar,
            profile: profile,
            events: []
        )

        #expect(snapshot.totalUnits == 366)
        #expect(snapshot.completedUnits == 241)
    }

    @Test("非闰年的 2 月 29 日事件落到 2 月 28 日")
    func leapBirthdayClampsToFebruary28() {
        let calendar = calendar()
        let profile = UserProfile(birthDate: date(2000, 4, 24))
        let event = TimeEvent(
            title: "闰日",
            recurrence: .yearly,
            anchorDate: date(2024, 2, 29, 8)
        )

        let snapshot = ClockEngine.snapshot(
            scale: .year,
            at: date(2025, 2, 1),
            calendar: calendar,
            profile: profile,
            events: [event]
        )

        #expect(snapshot.markers.count == 1)
        #expect(calendar.component(.month, from: snapshot.markers[0].occurrence) == 2)
        #expect(calendar.component(.day, from: snapshot.markers[0].occurrence) == 28)
    }

    @Test("每月 31 日在短月落到最后一天")
    func monthlyEventClampsToMonthEnd() {
        let calendar = calendar()
        let profile = UserProfile(birthDate: date(2000, 4, 24))
        let event = TimeEvent(
            title: "还款",
            recurrence: .monthly,
            anchorDate: date(2026, 1, 31, 9)
        )

        let snapshot = ClockEngine.snapshot(
            scale: .month,
            at: date(2026, 2, 10),
            calendar: calendar,
            profile: profile,
            events: [event]
        )

        #expect(snapshot.totalUnits == 28)
        #expect(calendar.component(.day, from: snapshot.markers[0].occurrence) == 28)
    }

    @Test("夏令时开始日使用真实的 23 小时区间")
    func daylightSavingDayHas23Hours() {
        let losAngeles = calendar("America/Los_Angeles")
        let profile = UserProfile(birthDate: date(2000, 4, 24, calendar: losAngeles))
        let snapshot = ClockEngine.snapshot(
            scale: .day,
            at: date(2024, 3, 10, 12, calendar: losAngeles),
            calendar: losAngeles,
            profile: profile,
            events: []
        )

        #expect(snapshot.totalUnits == 23)
    }

    @Test("人生以月份作为点阵单位")
    func lifeUsesMonths() {
        let calendar = calendar()
        let profile = UserProfile(birthDate: date(2000, 4, 24), targetAge: 85)
        let snapshot = ClockEngine.snapshot(
            scale: .life,
            at: date(2026, 8, 29),
            calendar: calendar,
            profile: profile,
            events: []
        )

        #expect(snapshot.totalUnits == 1_020)
        #expect(snapshot.completedUnits > 315)
        #expect(snapshot.completedUnits < 317)
    }

    @Test("事件按重复规则进入唯一尺度")
    func recurrenceMapsToSingleScale() {
        #expect(RecurrenceRule.once.scale == .life)
        #expect(RecurrenceRule.yearly.scale == .year)
        #expect(RecurrenceRule.monthly.scale == .month)
        #expect(RecurrenceRule.weekly.scale == .week)
        #expect(RecurrenceRule.daily.scale == .day)
    }

    @Test("连续尺度位置限制在五个尺度内")
    func scalePositionClampsToBounds() {
        #expect(ScalePosition.clamped(-2) == 0)
        #expect(ScalePosition.clamped(6) == 4)
        #expect(ClockScale.at(position: 1.49) == .year)
        #expect(ClockScale.at(position: 1.51) == .month)
    }

    @Test("连续尺度位置返回相邻尺度和插值比例")
    func scalePositionInterpolatesAdjacentScales() {
        let interpolation = ScalePosition.interpolation(at: 2.35)
        #expect(interpolation.lower == .month)
        #expect(interpolation.upper == .week)
        #expect(abs(interpolation.progress - 0.35) < 0.0001)

        let boundary = ScalePosition.interpolation(at: 4)
        #expect(boundary.lower == .day)
        #expect(boundary.upper == .day)
        #expect(boundary.progress == 0)
    }

    @Test("快速滑动采用预测位置，慢速拖动吸附当前位置")
    func scalePositionUsesProjectedSnap() {
        #expect(ScalePosition.snapped(current: 1.35, predicted: 3.55) == .day)
        #expect(ScalePosition.snapped(current: 2.42, predicted: 2.48) == .month)
        #expect(ScalePosition.snapped(current: 2.58, predicted: 2.62) == .week)
        #expect(ScalePosition.snapped(current: 2.65, predicted: 0.25) == .life)
    }

    @Test("减少动态效果时连续位置即时吸附")
    func scalePositionRespectsReduceMotion() {
        #expect(ScalePosition.interactionPosition(2.35, reduceMotion: false) == 2.35)
        #expect(ScalePosition.interactionPosition(2.35, reduceMotion: true) == 2)
        #expect(ScalePosition.interactionPosition(2.65, reduceMotion: true) == 3)
    }

    @Test("仪表为五个尺度生成完整语义单元")
    func dashboardBuildsSemanticUnits() {
        let calendar = calendar()
        let profile = UserProfile(birthDate: date(2000, 4, 24), targetAge: 85)
        let dashboard = ClockEngine.dashboard(
            at: date(2026, 8, 30, 20, 3),
            calendar: calendar,
            profile: profile,
            events: []
        )

        #expect(dashboard[.life].units.count == 85)
        #expect(dashboard[.year].units.count == 365)
        #expect(dashboard[.month].units.count == 42)
        #expect(dashboard[.week].units.count == 28)
        #expect(dashboard[.day].units.count == 24)
        #expect(dashboard[.year].relatedProgress.map(\.scale) == [.life, .year, .month])
        #expect(dashboard[.day].relatedProgress.map(\.scale) == [.month, .week, .day])
    }

    @Test("月历槽位服从用户选择的周起始日")
    func monthGridRespectsWeekStart() {
        let calendar = calendar()
        let mondayProfile = UserProfile(
            birthDate: date(2000, 4, 24),
            weekStartsOnMonday: true
        )
        let sundayProfile = UserProfile(
            birthDate: date(2000, 4, 24),
            weekStartsOnMonday: false
        )
        let now = date(2026, 8, 30, 12)

        let monday = ClockEngine.dashboard(
            at: now,
            calendar: calendar,
            profile: mondayProfile,
            events: []
        )[.month]
        let sunday = ClockEngine.dashboard(
            at: now,
            calendar: calendar,
            profile: sundayProfile,
            events: []
        )[.month]

        #expect(monday.units.firstIndex(where: { !$0.isPlaceholder }) == 5)
        #expect(sunday.units.firstIndex(where: { !$0.isPlaceholder }) == 6)
        #expect(monday.units[5].label == "1")
        #expect(sunday.units[6].label == "1")
    }

    @Test("周事件映射到对应日期与六小时时段")
    func weeklyEventMapsToPhaseCell() {
        let calendar = calendar()
        let profile = UserProfile(birthDate: date(2000, 4, 24))
        let event = TimeEvent(
            title: "周日晚间",
            recurrence: .weekly,
            anchorDate: date(2026, 8, 30, 20)
        )
        let week = ClockEngine.dashboard(
            at: date(2026, 8, 30, 20, 3),
            calendar: calendar,
            profile: profile,
            events: [event]
        )[.week]

        #expect(week.units.count == 28)
        #expect(week.units[27].markerIDs == [event.id])
    }

    @Test("日仪表保留 DST 的 23 与 25 个真实小时")
    func dayPresentationHandlesDST() {
        let losAngeles = calendar("America/Los_Angeles")
        let profile = UserProfile(birthDate: date(2000, 4, 24, calendar: losAngeles))

        let spring = ClockEngine.dashboard(
            at: date(2024, 3, 10, 12, calendar: losAngeles),
            calendar: losAngeles,
            profile: profile,
            events: []
        )[.day]
        let fall = ClockEngine.dashboard(
            at: date(2024, 11, 3, 12, calendar: losAngeles),
            calendar: losAngeles,
            profile: profile,
            events: []
        )[.day]

        #expect(spring.units.count == 23)
        #expect(fall.units.count == 25)
    }

    @Test("日仪表提供当前小时的分钟进度")
    func dayPresentationIncludesMinuteProgress() {
        let calendar = calendar()
        let profile = UserProfile(birthDate: date(2000, 4, 24))
        let day = ClockEngine.dashboard(
            at: date(2026, 8, 30, 12, 30),
            calendar: calendar,
            profile: profile,
            events: []
        )[.day]

        #expect(abs((day.fineProgress ?? 0) - 0.5) < 0.0001)
        #expect(day.focusProgress.count == 4)
        #expect(day.stageTitle == "下午 · 12时")
    }

    @Test("人生阶段在整十岁生日切换且保持中性描述")
    func lifeDecadeBoundary() {
        let calendar = calendar()
        let profile = UserProfile(birthDate: date(2000, 4, 24), targetAge: 85)
        let before = ClockEngine.dashboard(
            at: date(2030, 4, 23, 12),
            calendar: calendar,
            profile: profile,
            events: []
        )[.life]
        let after = ClockEngine.dashboard(
            at: date(2030, 4, 24, 12),
            calendar: calendar,
            profile: profile,
            events: []
        )[.life]

        #expect(before.stageTitle.contains("第3个十年"))
        #expect(after.stageTitle.contains("第4个十年"))
        #expect(after.focusProgress.count == 10)
    }

    @Test("SwiftData 内存容器可持久化和删除刻点")
    @MainActor
    func swiftDataCRUD() throws {
        let schema = Schema([UserProfile.self, TimeEvent.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext
        let event = TimeEvent(title: "吃药", recurrence: .daily, anchorDate: .now)

        context.insert(event)
        try context.save()
        let inserted = try context.fetch(FetchDescriptor<TimeEvent>())
        #expect(inserted.count == 1)

        context.delete(event)
        try context.save()
        let deleted = try context.fetch(FetchDescriptor<TimeEvent>())
        #expect(deleted.isEmpty)
    }
}
