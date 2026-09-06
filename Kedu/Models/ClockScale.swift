import Foundation

enum ClockScale: String, CaseIterable, Codable, Identifiable, Sendable {
    case life
    case year
    case month
    case week
    case day

    var id: String { rawValue }

    var position: Double {
        Double(Self.allCases.firstIndex(of: self) ?? 0)
    }

    static func at(position: Double) -> ClockScale {
        let index = min(
            allCases.count - 1,
            max(0, Int(ScalePosition.clamped(position).rounded()))
        )
        return allCases[index]
    }

    var title: String {
        switch self {
        case .life: "人生"
        case .year: "年"
        case .month: "月"
        case .week: "周"
        case .day: "日"
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .life: "人生时钟"
        case .year: "年度时钟"
        case .month: "月度时钟"
        case .week: "每周时钟"
        case .day: "今日时钟"
        }
    }
}

struct ScalePositionInterpolation: Equatable, Sendable {
    let lower: ClockScale
    let upper: ClockScale
    let progress: Double
}

enum ScalePosition {
    static var bounds: ClosedRange<Double> {
        0...Double(ClockScale.allCases.count - 1)
    }

    static func clamped(_ position: Double) -> Double {
        min(bounds.upperBound, max(bounds.lowerBound, position))
    }

    static func interpolation(at position: Double) -> ScalePositionInterpolation {
        let value = clamped(position)
        let lowerIndex = Int(floor(value))
        let upperIndex = min(ClockScale.allCases.count - 1, lowerIndex + 1)
        return ScalePositionInterpolation(
            lower: ClockScale.allCases[lowerIndex],
            upper: ClockScale.allCases[upperIndex],
            progress: upperIndex == lowerIndex ? 0 : value - Double(lowerIndex)
        )
    }

    static func interactionPosition(_ position: Double, reduceMotion: Bool) -> Double {
        let value = clamped(position)
        return reduceMotion ? ClockScale.at(position: value).position : value
    }

    static func snapped(current: Double, predicted: Double) -> ClockScale {
        let current = clamped(current)
        let predicted = clamped(predicted)
        let projectedDistance = abs(predicted - current)
        let target = projectedDistance >= 0.16 ? predicted : current
        return ClockScale.at(position: target)
    }
}

enum RecurrenceRule: String, CaseIterable, Codable, Identifiable, Sendable {
    case once
    case yearly
    case monthly
    case weekly
    case daily

    var id: String { rawValue }

    var title: String {
        switch self {
        case .once: "一次性"
        case .yearly: "每年"
        case .monthly: "每月"
        case .weekly: "每周"
        case .daily: "每天"
        }
    }

    var scale: ClockScale {
        switch self {
        case .once: .life
        case .yearly: .year
        case .monthly: .month
        case .weekly: .week
        case .daily: .day
        }
    }
}

enum EventColor: String, CaseIterable, Codable, Identifiable, Sendable {
    case amber
    case jade
    case cobalt
    case coral
    case violet

    var id: String { rawValue }

    var title: String {
        switch self {
        case .amber: "琥珀"
        case .jade: "青玉"
        case .cobalt: "钴蓝"
        case .coral: "珊瑚"
        case .violet: "紫罗兰"
        }
    }
}
