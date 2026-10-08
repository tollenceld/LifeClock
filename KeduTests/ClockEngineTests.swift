import Foundation
import SwiftData
import Testing
@testable import Kedu

struct TimeWeaveTests {
    @Test("分钟织口按真实时间推进，跨分钟连续换向")
    func minuteLoupe() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(TimeWeaveGeometry.minuteFraction(at: start) == 0)
        #expect(abs(TimeWeaveGeometry.minuteFraction(at: start.addingTimeInterval(15)) - 0.25) < 0.000001)
        #expect(TimeWeaveGeometry.minuteFraction(at: start.addingTimeInterval(59.9)) > 0.99)
        #expect(TimeWeaveGeometry.minuteFraction(at: start.addingTimeInterval(60)) == 0)
        #expect(TimeWeaveGeometry.minuteFraction(at: Date(timeIntervalSince1970: -15)) == 0.75)
        #expect(abs(TimeWeaveGeometry.minutePosition(at: start.addingTimeInterval(59.9))
                    - TimeWeaveGeometry.minutePosition(at: start.addingTimeInterval(60))) < 0.002)
        #expect(abs(TimeWeaveGeometry.minutePosition(at: start.addingTimeInterval(119.9))
                    - TimeWeaveGeometry.minutePosition(at: start.addingTimeInterval(120))) < 0.002)
    }

    @Test("分钟织口不会加速整体人生进度")
    func independentScales() {
        let birth = Date(timeIntervalSince1970: 0)
        let interval = DateInterval(start: birth, duration: 85 * 365.25 * 86_400)
        let date = birth.addingTimeInterval(26 * 365.25 * 86_400)
        let before = TimePhaseSnapshot(scale: .life, interval: interval, at: date)
        let after = TimePhaseSnapshot(scale: .life, interval: interval, at: date.addingTimeInterval(15))
        #expect(after.progress > before.progress)
        #expect(after.progress - before.progress < 0.000001)
        #expect(abs(TimeWeaveGeometry.minuteFraction(at: after.date) - TimeWeaveGeometry.minuteFraction(at: before.date) - 0.25) < 0.000001)
    }

    @Test("织面缩放插值只改变空间，越界参数夹紧")
    func spatialInterpolation() {
        #expect(TimeWeaveGeometry.mix(0.2, 0.8, -1) == 0.2)
        #expect(TimeWeaveGeometry.mix(0.2, 0.8, 2) == 0.8)
        #expect(abs(TimeWeaveGeometry.mix(0.2, 0.8, 0.5) - 0.5) < 0.000001)
    }
}

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
    @Test("相界与通用人生快照共享闰日终点")
    func phaseSharesLeapBirthdayAnchors() {
        let cal = calendar()
        let profile = UserProfile(birthDate: date(2000, 2, 29, 12), targetAge: 85)
        let now = date(2085, 2, 28)
        let life = LifeClockSnapshot(at: now, calendar: cal, birthDate: profile.birthDate, targetAge: 85)
        let context = TimePhaseContext.make(scale: .life, at: now, calendar: cal, profile: profile, events: [])
        let phase = TimePhaseSnapshot(scale: .life, interval: context.clock.interval, at: now)
        #expect(context.clock.interval.start == life.birthInstant)
        #expect(context.clock.interval.end == life.targetInstant)
        #expect(context.clock.progress == life.progress)
        #expect(context.clock.headline == "85岁")
        #expect(phase.isAtEnd && phase.remainingSeconds == 0)
        #expect(context.grain.first == 0 && context.grain.last == 1)
    }

    @Test("四尺度相界同一时刻互补且按真实秒数移动")
    func phaseSamplesAreComplementary() {
        let profile = UserProfile(birthDate: date(2000, 4, 24))
        let now = date(2026, 10, 2, 12)
        for scale in ClockScale.allCases {
            let context = TimePhaseContext.make(scale: scale, at: now, calendar: calendar(), profile: profile, events: [])
            let first = TimePhaseSnapshot(scale: scale, interval: context.clock.interval, at: now)
            let next = TimePhaseSnapshot(scale: scale, interval: context.clock.interval, at: now.addingTimeInterval(1))
            #expect(abs(first.elapsedSeconds + first.remainingSeconds - first.interval.duration) < 1e-6)
            #expect(next.elapsedSeconds - first.elapsedSeconds == 1)
            #expect(first.remainingSeconds - next.remainingSeconds == 1)
            #expect(next.progress > first.progress)
            #expect(PhaseFieldGeometry.boundaryY(progress: next.progress, height: 300) > PhaseFieldGeometry.boundaryY(progress: first.progress, height: 300))
        }
    }

    @Test("相界在出生前与设定终点后有界，累计继续")
    func phaseClampsOnlyTheLifeBoundary() {
        let interval = DateInterval(start: date(2000, 1, 1), end: date(2085, 1, 1))
        let before = TimePhaseSnapshot(scale: .life, interval: interval, at: interval.start.addingTimeInterval(-1))
        let after = TimePhaseSnapshot(scale: .life, interval: interval, at: interval.end.addingTimeInterval(1))
        #expect(before.elapsedSeconds == 0 && before.progress == 0)
        #expect(after.elapsedSeconds == interval.duration + 1)
        #expect(after.remainingSeconds == 0 && after.progress == 1)
        #expect(PhaseFieldGeometry.boundaryY(progress: 0, height: 300) == 32)
        #expect(PhaseFieldGeometry.boundaryY(progress: 1, height: 300) == 268)
    }

    @Test("时间颗粒遵守自然日、月份与实际夏令时")
    func grainUsesActualCalendarBoundaries() {
        let cal = calendar("America/Los_Angeles")
        let profile = UserProfile(birthDate: date(2000, 1, 1, calendar: cal))
        let shortDay = TimePhaseContext.make(scale: .day, at: date(2024, 3, 10, 12, calendar: cal), calendar: cal, profile: profile, events: [])
        let longDay = TimePhaseContext.make(scale: .day, at: date(2024, 11, 3, 12, calendar: cal), calendar: cal, profile: profile, events: [])
        #expect(shortDay.grain.count == 47)
        #expect(longDay.grain.count == 51)
        let month = TimePhaseContext.make(scale: .month, at: date(2024, 3, 10, calendar: cal), calendar: cal, profile: profile, events: [])
        #expect(month.grain.count == 32)
        #expect(abs((month.grain[10] - month.grain[9]) * month.clock.interval.duration - 23 * 3600) < 1e-6)
        let year = TimePhaseContext.make(scale: .year, at: date(2024, 3, 10, calendar: cal), calendar: cal, profile: profile, events: [])
        #expect(year.grain.count == 13)
        #expect(year.grain[2] - year.grain[1] < year.grain[1] - year.grain[0])
    }

    @Test("跨日月年刷新后使用新周期，旧周期不产生负数")
    func phaseRollsCalendarIntervals() {
        let profile = UserProfile(birthDate: date(2000, 1, 1))
        let boundary = date(2027, 1, 1)
        for scale in [ClockScale.day, .month, .year] {
            let old = TimePhaseContext.make(scale: scale, at: boundary.addingTimeInterval(-0.1), calendar: calendar(), profile: profile, events: [])
            let new = TimePhaseContext.make(scale: scale, at: boundary, calendar: calendar(), profile: profile, events: [])
            let ending = TimePhaseSnapshot(scale: scale, interval: old.clock.interval, at: boundary)
            let starting = TimePhaseSnapshot(scale: scale, interval: new.clock.interval, at: boundary)
            #expect(ending.progress == 1 && ending.remainingSeconds == 0)
            #expect(starting.progress == 0 && starting.elapsedSeconds == 0)
            #expect(old.clock.interval.end == new.clock.interval.start)
        }
    }

    @Test("视觉缩放独立于保留的人生日月年导航顺序")
    func phaseZoomPreservesMagnification() {
        #expect(ClockScale.allCases == [.life, .day, .month, .year])
        #expect(PhaseZoom.level(for: .day) == 0)
        #expect(PhaseZoom.level(for: .life) == 3)
        #expect(PhaseZoom.level(at: 1.5) == 0.5)
        let pair = PhaseZoom.interpolation(at: 2.4)
        #expect(pair.lower == .year && pair.upper == .life)
        #expect(abs(pair.progress - 0.4) < 1e-9)
        #expect(PhaseZoom.interpolation(at: -1).lower == .day)
        #expect(PhaseZoom.interpolation(at: 9).upper == .life)
    }

    @Test("相界刻点触控分组避免重叠但保留日期")
    func phaseMarkerClustersPreserveEvents() {
        let profile = UserProfile(birthDate: date(2000, 1, 1))
        let now = date(2026, 10, 2, 12)
        let events = [TimeEvent(title: "一", recurrence: .daily, anchorDate: now),
                      TimeEvent(title: "二", recurrence: .daily, anchorDate: now)]
        let clock = ClockEngine.snapshot(scale: .day, at: now, calendar: calendar(), profile: profile, events: events)
        let groups = PhaseFieldGeometry.markerGroups(clock: clock, height: 240)
        #expect(groups.count == 1 && groups[0].markers.count == 2)
        #expect(Set(groups[0].markers.map(\.id)) == Set(events.map(\.id)))
        #expect(groups[0].markers.allSatisfy { $0.occurrence == now })
    }

}

@MainActor
struct ReleaseReadinessTests {
    private var calendar: Calendar { CivilBirthday.calendar }
    private func container() throws -> ModelContainer {
        let schema = Schema([UserProfile.self, TimeEvent.self])
        return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)])
    }
    private func fixture() -> (UserProfile, TimeEvent) {
        let birthday = calendar.date(from: DateComponents(year: 2000, month: 4, day: 24))!
        let profile = UserProfile(birthDate: birthday)
        profile.setBirthday(birthday, calendar: calendar)
        let event = TimeEvent(title: "原有刻点", recurrence: .weekly, anchorDate: .now)
        event.setAnchor(event.anchorDate, calendar: calendar)
        return (profile, event)
    }

    @Test("生日在跨时区后保持同一个公历日期")
    func civilBirthdaySurvivesTravel() {
        var shanghai = calendar
        shanghai.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        var losAngeles = calendar
        losAngeles.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let date = shanghai.date(from: DateComponents(year: 2000, month: 4, day: 24))!
        let profile = UserProfile(birthDate: date)
        profile.setBirthday(date, calendar: shanghai)
        let birthday = profile.birthday(in: losAngeles)
        #expect(CivilBirthday.key(for: birthday, calendar: losAngeles) == "2000-04-24")
        let phase = TimePhaseContext.make(scale: .life, at: .now, calendar: losAngeles, profile: profile, events: [])
        let basis = profile.lifeCalendar(from: losAngeles)
        #expect(CivilBirthday.key(for: phase.clock.interval.start, calendar: basis) == "2000-04-24")
        #expect(CivilBirthday.key(for: phase.clock.interval.end, calendar: basis) == "2085-04-24")
        let original = TimePhaseContext.make(scale: .life, at: phase.clock.interval.start, calendar: shanghai, profile: profile, events: [])
        #expect(original.clock.interval == phase.clock.interval)
        let instant = Date.now
        #expect(TimePhaseSnapshot(scale: .life, interval: original.clock.interval, at: instant)
                == TimePhaseSnapshot(scale: .life, interval: phase.clock.interval, at: instant))
    }

    @Test("周期刻点保持本地钟点，一次性刻点保持绝对时间")
    func recurringScheduleSurvivesTravel() {
        var origin = calendar; origin.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        var destination = calendar; destination.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let date = origin.date(from: DateComponents(year: 2026, month: 4, day: 24, hour: 18, minute: 30))!
        let recurring = TimeEvent(title: "每天", recurrence: .daily, anchorDate: date)
        recurring.setAnchor(date, calendar: origin)
        #expect(destination.component(.hour, from: recurring.anchor(in: destination)) == 18)
        #expect(destination.component(.minute, from: recurring.anchor(in: destination)) == 30)
        let once = TimeEvent(title: "一次", recurrence: .once, anchorDate: date)
        once.setAnchor(date, calendar: origin)
        #expect(once.anchor(in: destination) == date)
    }

    @Test("备份往返保留历史规则、稳定 ID 与偏好")
    func backupRoundTrip() throws {
        let (profile, event) = fixture()
        let backup = LocalBackup(profile: profile, events: [event], appearance: .dark)
        let decoded = try LocalBackup.decode(backup.encoded())
        #expect(decoded.profile.birthday == "2000-04-24")
        #expect(decoded.events.first?.id == event.id)
        #expect(decoded.events.first?.recurrence == "weekly")
        #expect(decoded.events.first?.anchorDateComponents == event.anchorDateComponents)
        #expect(decoded.appearance == "dark")
    }

    @Test("未知版本、无效生日、重复 ID 和错误类型均拒绝")
    func backupRejectsInvalidPayloads() throws {
        let (profile, event) = fixture()
        let data = try LocalBackup(profile: profile, events: [event], appearance: .light).encoded()
        let base = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        for mutation in 0..<5 {
            var payload = base
            if mutation == 0 { payload["version"] = 99 }
            if mutation == 1 {
                var value = payload["profile"] as! [String: Any]
                value["birthday"] = "2000-02-31"; payload["profile"] = value
            }
            if mutation == 2 { payload["events"] = (payload["events"] as! [[String: Any]]) + (payload["events"] as! [[String: Any]]) }
            if mutation == 3 { payload["format"] = "Other.App" }
            if mutation == 4 {
                var value = payload["profile"] as! [String: Any]
                value["targetAge"] = 151; payload["profile"] = value
            }
            let invalid = try JSONSerialization.data(withJSONObject: payload)
            #expect(throws: BackupError.self) { try LocalBackup.decode(invalid) }
        }
        #expect(throws: BackupError.self) { try LocalBackup.decode(Data("null".utf8)) }
    }

    @Test("超大文件在解码前拒绝")
    func backupRejectsOversizedData() {
        #expect(throws: BackupError.self) {
            try LocalBackup.decode(Data(repeating: 32, count: LocalBackup.maximumBytes + 1))
        }
    }

    @Test("恢复同一份备份不复制刻点且保留资料身份")
    func backupRestoreIsIdempotent() throws {
        let store = try container()
        let context = store.mainContext
        let (profile, event) = fixture()
        context.insert(profile); context.insert(event); try context.save()
        let backup = LocalBackup(profile: profile, events: [event], appearance: .system)
        profile.targetAge = 120; event.title = "修改过"; try context.save()
        let extra = TimeEvent(title: "额外刻点", recurrence: .once, anchorDate: .now)
        context.insert(extra); try context.save()
        let id = profile.id
        try backup.restore(in: context, into: profile)
        try backup.restore(in: context, into: profile)
        #expect(profile.id == id)
        #expect(profile.targetAge == 85)
        let restored = try context.fetch(FetchDescriptor<TimeEvent>())
        #expect(restored.count == 1)
        #expect(restored.first?.title == "原有刻点")
        #expect(restored.first?.id == event.id)
        #expect(restored.first?.recurrence == .weekly)
    }

    @Test("恢复保存失败完整回滚原有资料与刻点")
    func backupRestoreRollsBack() throws {
        let store = try container()
        let context = store.mainContext
        let (profile, event) = fixture()
        context.insert(profile); context.insert(event); try context.save()
        let backup = LocalBackup(profile: profile, events: [event], appearance: .light)
        profile.targetAge = 120; event.title = "要保留的名称"; try context.save()
        context.insert(TimeEvent(title: "要保留的额外刻点", recurrence: .once, anchorDate: .now)); try context.save()
        #expect(throws: CocoaError.self) {
            try backup.restore(in: context, into: profile) { _ in throw CocoaError(.fileWriteOutOfSpace) }
        }
        #expect(profile.targetAge == 120)
        let kept = try context.fetch(FetchDescriptor<TimeEvent>())
        #expect(kept.count == 2)
        #expect(kept.contains { $0.title == "要保留的名称" })
        #expect(kept.contains { $0.title == "要保留的额外刻点" })
        // Check the retained UI object, a fresh reader, and the next successful
        // save. An apparent rollback must not later persist a failed restore.
        let reader = ModelContext(store)
        #expect(try reader.fetch(FetchDescriptor<UserProfile>()).first?.targetAge == 120)
        try context.save()
        #expect(try ModelContext(store).fetch(FetchDescriptor<UserProfile>()).first?.targetAge == 120)
    }

    @Test("存储打开失败可重试且不删除已有数据")
    func storageFailureIsRecoverable() throws {
        let store = try container()
        let (profile, event) = fixture()
        store.mainContext.insert(profile); store.mainContext.insert(event); try store.mainContext.save()
        var attempts = 0
        let storage = AppStorageController(factory: {
            attempts += 1
            if attempts == 1 { throw CocoaError(.fileReadNoPermission) }
            return store
        })
        #expect(storage.container == nil)
        #expect(storage.loadFailed)
        storage.load()
        #expect(storage.container != nil)
        #expect(!storage.loadFailed)
        #expect(try store.mainContext.fetchCount(FetchDescriptor<TimeEvent>()) == 1)
        #expect(try store.mainContext.fetch(FetchDescriptor<UserProfile>()).first?.id == profile.id)
    }

    @Test("日期校验拒绝溢出日期并覆盖 150 岁边界")
    func civilDatesValidateBoundaries() {
        #expect(CivilBirthday.date(from: "2025-02-29", calendar: calendar) == nil)
        #expect(CivilBirthday.date(from: "2000-02-29", calendar: calendar) != nil)
        #expect(CivilBirthday.date(from: "999999999999-01-01", calendar: calendar) == nil)
        #expect(CivilSchedule.date(from: "2026-04-24T25:00", calendar: calendar) == nil)
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 3))!
        #expect(CivilBirthday.key(for: CivilBirthday.allowedRange(at: now, calendar: calendar).lowerBound, calendar: calendar) == "1876-10-03")
    }
}

private enum LegacyLocalSchema {
    @Model final class UserProfile {
        @Attribute(.unique) var id: UUID
        var birthDate: Date
        var targetAge: Int
        var weekStartsOnMonday: Bool
        var onboardingCompleted: Bool
        var hapticsEnabled: Bool
        init(birthDate: Date) {
            id = UUID(); self.birthDate = birthDate; targetAge = 85
            weekStartsOnMonday = true; onboardingCompleted = true; hapticsEnabled = false
        }
    }
    @Model final class TimeEvent {
        @Attribute(.unique) var id: UUID
        var title: String
        var symbolName: String
        var colorRawValue: String
        var recurrenceRawValue: String
        var anchorDate: Date
        var createdAt: Date
        var updatedAt: Date
        init() {
            id = UUID(); title = "旧版历史刻点"; symbolName = "book.fill"; colorRawValue = "jade"
            recurrenceRawValue = "weekly"; anchorDate = .now; createdAt = .now; updatedAt = .now
        }
    }
}

extension ReleaseReadinessTests {
    @Test("旧版磁盘资料可轻量迁移，日期与历史刻点不丢失")
    func migratesOriginalDiskSchema() throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "migration.sqlite")
        let birth = calendar.date(from: DateComponents(year: 2000, month: 4, day: 24))!
        var originalID: UUID!
        do {
            let schema = Schema([LegacyLocalSchema.UserProfile.self, LegacyLocalSchema.TimeEvent.self])
            #expect(Set(schema.entities.map(\.name)) == Set(["UserProfile", "TimeEvent"]))
            let old = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
            let profile = LegacyLocalSchema.UserProfile(birthDate: birth)
            originalID = profile.id
            old.mainContext.insert(profile)
            old.mainContext.insert(LegacyLocalSchema.TimeEvent())
            try old.mainContext.save()
        }
        let schema = Schema([UserProfile.self, TimeEvent.self])
        let migrated = try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: url)])
        let storage = AppStorageController(factory: { migrated })
        #expect(storage.container != nil)
        let profile = try #require(migrated.mainContext.fetch(FetchDescriptor<UserProfile>()).first)
        #expect(profile.id == originalID)
        #expect(profile.birthDate == birth)
        #expect(profile.birthDateComponents == "2000-04-24")
        #expect(profile.targetAge == 85)
        #expect(!profile.hapticsEnabled)
        let event = try #require(migrated.mainContext.fetch(FetchDescriptor<TimeEvent>()).first)
        #expect(event.title == "旧版历史刻点")
        #expect(event.recurrence == .weekly)
        #expect(event.anchorDateComponents != nil)
    }
}
