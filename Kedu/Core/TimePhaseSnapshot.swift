import Foundation

/// Cheap to sample: no calendar, persistence or event work on the live clock.
struct TimePhaseSnapshot: Equatable, Sendable {
    let scale: ClockScale
    let interval: DateInterval
    let date: Date
    let elapsedSeconds: TimeInterval
    let remainingSeconds: TimeInterval
    let progress: Double

    init(scale: ClockScale, interval: DateInterval, at date: Date) {
        self.scale = scale
        self.interval = interval
        self.date = date
        let elapsed = max(0, date.timeIntervalSince(interval.start))
        elapsedSeconds = scale == .life ? elapsed : min(interval.duration, elapsed)
        remainingSeconds = max(0, interval.end.timeIntervalSince(date))
        progress = min(1, max(0, elapsed / max(1, interval.duration)))
    }

    var isAtEnd: Bool { date >= interval.end }
}

/// Calendar-dependent material is prepared only on invalidation, never per animation frame.
struct TimePhaseContext {
    let clock: ClockSnapshot
    let grain: [Double]
    let startLabel: String
    let endLabel: String

    static func make(scale: ClockScale, at date: Date, calendar: Calendar,
                     profile: UserProfile, events: [TimeEvent]) -> Self {
        let calendar = scale == .life ? profile.lifeCalendar(from: calendar) : calendar
        let clock = ClockEngine.snapshot(scale: scale, at: date, calendar: calendar, profile: profile, events: events)
        let interval = clock.interval
        let boundaries: [Date]
        let labels: (String, String)
        let dateFormat = Date.FormatStyle(date: .numeric, time: .omitted, locale: Locale(identifier: "zh_Hans_CN"), calendar: calendar, timeZone: calendar.timeZone)
        switch scale {
        case .life:
            boundaries = stride(from: 0, to: max(1, profile.targetAge), by: 1).map {
                LifeTimeAnchors.birthday(atAge: $0, birth: interval.start, calendar: calendar)
            } + [interval.end]
            labels = ("出生 · " + interval.start.formatted(dateFormat), "预计寿命 · \(profile.targetAge) 岁")
        case .day:
            let count = Int((interval.duration / 1_800).rounded())
            boundaries = (0...count).map { interval.start.addingTimeInterval(Double($0) * 1_800) }
            labels = ("今日 · " + interval.start.formatted(dateFormat), "午夜 · 24:00")
        case .month:
            let count = calendar.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1
            boundaries = (0...count).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
            labels = ("本月 · " + interval.start.formatted(dateFormat), "下月 · " + interval.end.formatted(dateFormat))
        case .year:
            boundaries = (0...12).compactMap { calendar.date(byAdding: .month, value: $0, to: interval.start) }
            labels = ("今年 · \(calendar.component(.year, from: date))", "来年 · \(calendar.component(.year, from: interval.end))")
        }
        return Self(clock: clock, grain: boundaries.map {
            min(1, max(0, $0.timeIntervalSince(interval.start) / max(1, interval.duration)))
        }, startLabel: labels.0, endLabel: labels.1)
    }
}

/// Visual magnification is independent of the retained navigation order.
enum PhaseZoom {
    static let scales: [ClockScale] = [.day, .month, .year, .life]

    static func level(for scale: ClockScale) -> Double {
        Double(scales.firstIndex(of: scale) ?? 0)
    }

    static func level(at navigationPosition: Double) -> Double {
        let pair = ScalePosition.interpolation(at: navigationPosition)
        return level(for: pair.lower) + (level(for: pair.upper) - level(for: pair.lower)) * pair.progress
    }

    static func interpolation(at level: Double) -> ScalePositionInterpolation {
        let level = min(3, max(0, level))
        let lower = Int(floor(level))
        let upper = min(3, lower + 1)
        return .init(lower: scales[lower], upper: scales[upper], progress: level - Double(lower))
    }
}

struct PhaseMarkerGroup: Identifiable {
    let id: Int
    let markers: [EventMarkerSnapshot]
    let position: Double
}

enum PhaseFieldGeometry {
    static let inset: Double = 32

    static func boundaryY(progress: Double, height: Double) -> Double {
        inset + min(1, max(0, progress)) * max(0, height - inset * 2)
    }

    static func markerGroups(clock: ClockSnapshot, height: Double) -> [PhaseMarkerGroup] {
        let bins = max(1, Int(max(0, height - inset * 2) / 44))
        let groups = Dictionary(grouping: clock.markers) { marker in
            let ratio = marker.occurrence.timeIntervalSince(clock.interval.start) / max(1, clock.interval.duration)
            return min(bins - 1, max(0, Int(ratio * Double(bins))))
        }
        return groups.keys.sorted().map { bin in
            let markers = groups[bin] ?? []
            // Hit areas use non-overlapping bins; the tiny ink marks retain exact dates.
            return PhaseMarkerGroup(id: bin, markers: markers, position: (Double(bin) + 0.5) / Double(bins))
        }
    }
}
