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

    @Test("事件按重复规则进入唯一尺度")
    func recurrenceMapsToSingleScale() {
        #expect(ClockScale.allCases == [.life, .day, .month, .year])
        #expect(RecurrenceRule.supportedCases == [.once, .yearly, .monthly, .daily])
        #expect(RecurrenceRule.once.scale == .life)
        #expect(RecurrenceRule.yearly.scale == .year)
        #expect(RecurrenceRule.monthly.scale == .month)
        #expect(RecurrenceRule.weekly.scale == nil)
        #expect(RecurrenceRule.daily.scale == .day)
    }

    @Test("连续尺度位置限制在四个尺度内")
    func scalePositionClampsToBounds() {
        #expect(ScalePosition.clamped(-2) == 0)
        #expect(ScalePosition.clamped(6) == 3)
        #expect(ClockScale.at(position: 1.49) == .day)
        #expect(ClockScale.at(position: 1.51) == .month)
    }

    @Test("连续尺度位置返回相邻尺度和插值比例")
    func scalePositionInterpolatesAdjacentScales() {
        let interpolation = ScalePosition.interpolation(at: 2.35)
        #expect(interpolation.lower == .month)
        #expect(interpolation.upper == .year)
        #expect(abs(interpolation.progress - 0.35) < 0.0001)

        let boundary = ScalePosition.interpolation(at: 3)
        #expect(boundary.lower == .year)
        #expect(boundary.upper == .year)
        #expect(boundary.progress == 0)
    }

    @Test("快速滑动采用预测位置，慢速拖动吸附当前位置")
    func scalePositionUsesProjectedSnap() {
        #expect(ScalePosition.snapped(current: 1.35, predicted: 3.55) == .year)
        #expect(ScalePosition.snapped(current: 2.42, predicted: 2.48) == .month)
        #expect(ScalePosition.snapped(current: 2.58, predicted: 2.62) == .year)
        #expect(ScalePosition.snapped(current: 2.65, predicted: 0.25) == .life)
    }

    @Test("减少动态效果时连续位置即时吸附")
    func scalePositionRespectsReduceMotion() {
        #expect(ScalePosition.interactionPosition(2.35, reduceMotion: false) == 2.35)
        #expect(ScalePosition.interactionPosition(2.35, reduceMotion: true) == 2)
        #expect(ScalePosition.interactionPosition(2.65, reduceMotion: true) == 3)
    }

    @Test("仪表为四个尺度生成完整语义单元")
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
        #expect(dashboard[.day].units.count == 24)
        #expect(dashboard[.year].relatedProgress.map(\.scale) == [.life, .year, .month])
        #expect(dashboard[.day].relatedProgress.map(\.scale) == [.year, .month, .day])
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

    @Test("月历的可见星期标签跟随既有排列偏好及计算时区")
    func visibleWeekdayLabelsRespectCalendar() {
        for zone in ["Asia/Shanghai", "America/Los_Angeles"] {
            let calendar = calendar(zone)
            for mondayStart in [true, false] {
                let profile = UserProfile(birthDate: date(2000, 4, 24), weekStartsOnMonday: mondayStart)
                let dashboard = ClockEngine.dashboard(at: date(2026, 8, 30, 12, calendar: calendar), calendar: calendar, profile: profile, events: [])
                for scale in [ClockScale.month] {
                    let layout = ClockVisualLayout(presentation: dashboard[scale], size: CGSize(width: 330, height: 280))
                    let labels = Array(layout.annotations.prefix(7).map(\.text))
                    #expect(labels == (mondayStart ? ["一", "二", "三", "四", "五", "六", "日"] : ["日", "一", "二", "三", "四", "五", "六"]))
                }
            }
        }
    }

    @Test("年度分月布局保留闰日且所有日点在仪表内")
    func yearLayoutPreservesEveryDay() {
        let calendar = calendar("America/Los_Angeles")
        let profile = UserProfile(birthDate: date(2000, 4, 24))
        let presentation = ClockEngine.dashboard(at: date(2024, 2, 29, 12, calendar: calendar), calendar: calendar, profile: profile, events: [])[.year]
        let layout = ClockVisualLayout(presentation: presentation, size: CGSize(width: 300, height: 260))
        #expect(layout.count == 366)
        #expect(layout.annotations.count == 12)
        for index in 0..<layout.count {
            let point = layout.item(at: index).center
            #expect(point.x > 0 && point.x < 300 && point.y > 0 && point.y < 260)
        }
        #expect(layout.item(at: 58).center != layout.item(at: 59).center)
        #expect(layout.item(at: 59).center != layout.item(at: 60).center)
    }

    @Test("小屏日视图的分钟刻度不重叠")
    func compactMinuteMarksRemainSeparated() {
        let profile = UserProfile(birthDate: date(2000, 4, 24))
        let presentation = ClockEngine.dashboard(at: date(2026, 9, 8, 12), calendar: calendar(), profile: profile, events: [])[.day]
        let layout = ClockVisualLayout(presentation: presentation, size: CGSize(width: 300, height: 190))
        #expect(layout.fineRects.count == 60)
        for index in 0..<45 {
            #expect(!layout.fineRects[index].intersects(layout.fineRects[index + 15]))
        }
        #expect(layout.fineRects.allSatisfy { $0.minY >= 0 && $0.maxY < 190 })
    }

    @Test("历史每周记录保持原规则但不进入任何尺度")
    func weeklyRecordsAreInactiveWithoutBeingConverted() throws {
        let calendar = calendar()
        let profile = UserProfile(birthDate: date(2000, 4, 24))
        let event = TimeEvent(
            title: "旧锻炼计划",
            recurrence: .weekly,
            anchorDate: date(2026, 8, 30, 20)
        )
        let decoded = try JSONDecoder().decode(RecurrenceRule.self, from: Data("\"weekly\"".utf8))
        #expect(decoded == .weekly)
        #expect(event.scale == nil)
        let dashboard = ClockEngine.dashboard(
            at: date(2026, 8, 30, 20, 3),
            calendar: calendar,
            profile: profile,
            events: [event]
        )
        #expect(dashboard.presentations.count == 4)
        #expect(dashboard.presentations.allSatisfy { $0.clock.markers.isEmpty })
        #expect(event.recurrenceRawValue == "weekly")

        event.recurrence = .daily
        let converted = ClockEngine.snapshot(
            scale: .day,
            at: date(2026, 8, 30, 20, 3),
            calendar: calendar,
            profile: profile,
            events: [event]
        )
        #expect(converted.markers.map(\.id) == [event.id])
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

    @Test("人生数字在一秒内可见变化且正反面保持互补")
    func lifeAdvancesWithinOneSecond() {
        let calendar = calendar()
        let birthday = date(2000, 4, 24)
        let now = date(2026, 9, 15, 12)
        let first = LifeClockSnapshot(at: now, calendar: calendar, birthDate: birthday, targetAge: 85)
        let next = LifeClockSnapshot(at: now.addingTimeInterval(1), calendar: calendar, birthDate: birthday, targetAge: 85)
        #expect(next.age > first.age)
        #expect(next.remainingYears < first.remainingYears)
        #expect(next.progress > first.progress)
        #expect(next.remainingProgress < first.remainingProgress)
        #expect(first.progress + first.remainingProgress == 1)
        #expect(abs(first.age + first.remainingYears - 85) < 0.000000001)
        #expect(String(format: "%.8f", first.age) != String(format: "%.8f", next.age))
        #expect(String(format: "%.8f", first.progress * 100) != String(format: "%.8f", next.progress * 100))
        #expect(next.date == now.addingTimeInterval(1))
    }

    @Test("小数年龄使用相邻生日区间而百分比使用完整人生真实时长")
    func lifeUsesActualBirthdayIntervals() {
        for zone in ["Asia/Shanghai", "America/Los_Angeles"] {
            let calendar = calendar(zone)
            let birthday = date(2000, 4, 24, calendar: calendar)
            let lastBirthday = date(2023, 4, 24, calendar: calendar)
            let nextBirthday = date(2024, 4, 24, calendar: calendar)
            let now = date(2023, 11, 8, 12, calendar: calendar)
            let target = date(2085, 4, 24, calendar: calendar)
            let snapshot = LifeClockSnapshot(at: now, calendar: calendar, birthDate: birthday, targetAge: 85)
            let expectedAge = 23 + now.timeIntervalSince(lastBirthday) / nextBirthday.timeIntervalSince(lastBirthday)
            let expectedProgress = now.timeIntervalSince(birthday) / target.timeIntervalSince(birthday)
            #expect(abs(snapshot.age - expectedAge) < 0.000000000001)
            #expect(abs(snapshot.progress - expectedProgress) < 0.000000000001)
        }
    }

    @Test("生日午夜年龄准确进位并持续递增")
    func lifeIsContinuousAcrossBirthday() {
        let calendar = calendar()
        let birthday = date(2000, 4, 24)
        let anniversary = date(2030, 4, 24)
        let before = LifeClockSnapshot(at: anniversary.addingTimeInterval(-1), calendar: calendar, birthDate: birthday, targetAge: 85)
        let exact = LifeClockSnapshot(at: anniversary, calendar: calendar, birthDate: birthday, targetAge: 85)
        let after = LifeClockSnapshot(at: anniversary.addingTimeInterval(1), calendar: calendar, birthDate: birthday, targetAge: 85)
        #expect(before.age < 30)
        #expect(exact.age == 30)
        #expect(after.age > 30)
        #expect(abs(after.age - before.age) < 0.000001)
    }

    @Test("闰日生日在非闰年二月二十八日进位而闰年保留二十九日")
    func lifeLeapBirthdayUsesFebruary28() {
        let calendar = calendar()
        let birthday = date(2000, 2, 29)
        let nonLeap = date(2025, 2, 28)
        let before = LifeClockSnapshot(at: nonLeap.addingTimeInterval(-1), calendar: calendar, birthDate: birthday, targetAge: 85)
        let onBirthday = LifeClockSnapshot(at: nonLeap, calendar: calendar, birthDate: birthday, targetAge: 85)
        let leapEve = LifeClockSnapshot(at: date(2024, 2, 28), calendar: calendar, birthDate: birthday, targetAge: 85)
        let leapBirthday = LifeClockSnapshot(at: date(2024, 2, 29), calendar: calendar, birthDate: birthday, targetAge: 85)
        #expect(before.age < 25)
        #expect(onBirthday.age == 25)
        #expect(leapEve.age < 24)
        #expect(leapBirthday.age == 24)
        let target = LifeClockSnapshot(at: date(2085, 2, 28), calendar: calendar, birthDate: birthday, targetAge: 85)
        #expect(target.age == 85)
        #expect(target.progress == 1)
        #expect(target.isAtEnd)
    }

    @Test("夏令时跳过一小时不使人生时钟跳跃")
    func lifeAdvancesByActualSecondsAcrossDST() {
        let calendar = calendar("America/Los_Angeles")
        let birthday = date(2000, 3, 10, calendar: calendar)
        let beforeDate = date(2024, 3, 10, 1, 59, calendar: calendar).addingTimeInterval(59)
        let afterDate = beforeDate.addingTimeInterval(1)
        #expect(calendar.component(.hour, from: afterDate) == 3)
        let before = LifeClockSnapshot(at: beforeDate, calendar: calendar, birthDate: birthday, targetAge: 85)
        let after = LifeClockSnapshot(at: afterDate, calendar: calendar, birthDate: birthday, targetAge: 85)
        let yearDuration = date(2025, 3, 10, calendar: calendar).timeIntervalSince(date(2024, 3, 10, calendar: calendar))
        #expect(abs((after.age - before.age) - 1 / yearDuration) < 0.000000000001)
        #expect(after.progress > before.progress)
    }

    @Test("设定年龄到期后实际年龄继续增加而剩余归零")
    func lifeKeepsAgingBeyondTarget() {
        let calendar = calendar()
        let birthday = date(2000, 4, 24)
        let target = date(2085, 4, 24)
        let before = LifeClockSnapshot(at: target.addingTimeInterval(-1), calendar: calendar, birthDate: birthday, targetAge: 85)
        let exact = LifeClockSnapshot(at: target, calendar: calendar, birthDate: birthday, targetAge: 85)
        let after = LifeClockSnapshot(at: target.addingTimeInterval(1), calendar: calendar, birthDate: birthday, targetAge: 85)
        #expect(!before.isAtEnd)
        #expect(before.remainingYears > 0)
        #expect(before.progress < 1)
        #expect(exact.age == 85)
        #expect(exact.isAtEnd)
        #expect(after.age > exact.age)
        #expect(after.remainingYears == 0)
        #expect(after.progress == 1)
        #expect(after.remainingProgress == 0)
        #expect(after.isAtEnd)
    }

    @Test("未来生日保持零年龄与完整剩余时间")
    func lifeBeforeBirthDoesNotBecomeNegative() {
        let calendar = calendar()
        let birthday = date(2027, 4, 24)
        let snapshot = LifeClockSnapshot(at: date(2026, 9, 15), calendar: calendar, birthDate: birthday, targetAge: 85)
        #expect(snapshot.age == 0)
        #expect(snapshot.remainingYears == 85)
        #expect(snapshot.progress == 0)
        #expect(snapshot.remainingProgress == 1)
        #expect(!snapshot.isAtEnd)
    }

    @Test("小数天数每秒按真实时长变化，正反面互补")
    func fractionalDaysAdvance() {
        let birth = date(2000, 4, 24)
        let now = date(2026, 9, 15, 12)
        let first = LifeClockSnapshot(at: now, calendar: calendar(), birthDate: birth, targetAge: 85)
        let next = LifeClockSnapshot(at: now.addingTimeInterval(1), calendar: calendar(), birthDate: birth, targetAge: 85)
        #expect(abs((next.elapsedSeconds / 86400 - first.elapsedSeconds / 86400) - 1 / 86400.0) < 1e-10)
        #expect(abs((first.remainingSeconds / 86400 - next.remainingSeconds / 86400) - 1 / 86400.0) < 1e-10)
        #expect(first.elapsedSeconds + first.remainingSeconds == first.targetInstant.timeIntervalSince(first.birthInstant))
        #expect(String(format: "%.8f", first.elapsedSeconds / 86400) != String(format: "%.8f", next.elapsedSeconds / 86400))
    }

    @Test("跨午夜小数天数连续进位")
    func fractionalDayBoundary() {
        let birth = date(2000, 4, 24)
        let boundary = birth.addingTimeInterval(86400)
        let before = LifeClockSnapshot(at: boundary.addingTimeInterval(-0.1), calendar: calendar(), birthDate: birth, targetAge: 85)
        let after = LifeClockSnapshot(at: boundary.addingTimeInterval(0.1), calendar: calendar(), birthDate: birth, targetAge: 85)
        #expect(before.elapsedSeconds / 86400 < 1)
        #expect(after.elapsedSeconds / 86400 > 1)
        #expect(abs(after.elapsedSeconds - before.elapsedSeconds - 0.2) < 0.000001)
    }

    @Test("夏令时按真实秒数推进，目标到期后只有正面继续")
    func fractionalDaysDSTAndDeadline() {
        let cal = calendar("America/Los_Angeles")
        let birth = date(2000, 3, 10, calendar: cal)
        let before = date(2024, 3, 10, 1, 59, calendar: cal).addingTimeInterval(59)
        let first = LifeClockSnapshot(at: before, calendar: cal, birthDate: birth, targetAge: 85)
        let next = LifeClockSnapshot(at: before.addingTimeInterval(1), calendar: cal, birthDate: birth, targetAge: 85)
        #expect(next.elapsedSeconds - first.elapsedSeconds == 1)
        let over = LifeClockSnapshot(at: first.targetInstant.addingTimeInterval(1), calendar: cal, birthDate: birth, targetAge: 85)
        #expect(over.remainingSeconds == 0)
        #expect(over.elapsedSeconds > first.targetInstant.timeIntervalSince(first.birthInstant))
    }

    @Test("旧每周刻点在存储后仍保留原规则直到主动转换")
    @MainActor
    func weeklyStorageRetainsLegacyRule() throws {
        let schema = Schema([UserProfile.self, TimeEvent.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let event = TimeEvent(title: "旧锻炼计划", recurrence: .weekly, anchorDate: date(2026, 8, 30, 20))
        container.mainContext.insert(event)
        try container.mainContext.save()

        let readContext = ModelContext(container)
        let records = try readContext.fetch(FetchDescriptor<TimeEvent>())
        let restored = try #require(records.first)
        #expect(restored.id == event.id)
        #expect(restored.recurrence == .weekly)
        #expect(restored.recurrenceRawValue == "weekly")
        #expect(restored.scale == nil)
        restored.recurrence = .monthly
        try readContext.save()

        let convertedRecords = try ModelContext(container).fetch(FetchDescriptor<TimeEvent>())
        #expect(convertedRecords.first?.recurrence == .monthly)
        #expect(convertedRecords.first?.scale == .month)
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
