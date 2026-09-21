import SwiftUI

/// One consistent hierarchy for every time scale: context, a precise duration, and its unit.
struct ImmersiveTimeReadout: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let title: String
    let value: Double
    let unit: String
    let ink: Color
    let identifier: String

    var body: some View {
        let parts = String(format: "%.8f", locale: Locale(identifier: "en_US_POSIX"), max(0, value))
            .split(separator: ".", omittingEmptySubsequences: false)
        VStack(spacing: 24) {
            Text(title)
                .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 17 : 13, weight: .regular))
                .tracking(4)
                .foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                digits(parts, size: dynamicTypeSize.isAccessibilitySize ? 76 : 68)
                digits(parts, size: 54)
                digits(parts, size: 44)
            }
            Text(unit)
                .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 16 : 11, weight: .medium))
                .tracking(5)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title + "，" + unit)
        .accessibilityValue(String(format: "%.8f", locale: Locale(identifier: "en_US_POSIX"), max(0, value)))
        .accessibilityIdentifier(identifier)
    }

    private func digits(_ parts: [Substring], size: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(String(parts.first ?? "0"))
                .font(.system(size: size, weight: .ultraLight))
                .foregroundStyle(ink)
            Text("." + String(parts.last ?? "00000000"))
                .font(.system(size: size * 0.31, weight: .light))
                .foregroundStyle(ink.opacity(0.72))
        }
        .monospacedDigit()
        .fixedSize()
        .transaction { $0.animation = nil }
    }
}

/// A small window of real seconds; the main value already incorporates them as a fraction.
/// It has no separate seconds readout and never substitutes an accelerated duration.
struct LiveTimeTrace: View, Equatable {
    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.origin == rhs.origin && lhs.target == rhs.target && lhs.reversed == rhs.reversed
        && lhs.isActive == rhs.isActive && lhs.reduceMotion == rhs.reduceMotion && lhs.ink == rhs.ink
        && (lhs.isActive && !lhs.reduceMotion || lhs.sampledAt == rhs.sampledAt)
    }

    let origin: Date
    let target: Date
    let reversed: Bool
    let isActive: Bool
    let reduceMotion: Bool
    let sampledAt: Date
    let ink: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !isActive || reduceMotion)) { timeline in
            let date = isActive && !reduceMotion ? timeline.date : sampledAt
            let duration = max(0, reversed ? target.timeIntervalSince(date) : date.timeIntervalSince(origin))
            Canvas { context, size in
                let center = size.width / 2
                let step: CGFloat = 25
                let position = reduceMotion ? 0 : duration
                let base = floor(position)
                for offset in -9...9 {
                    let tick = base + Double(offset)
                    let x = center + CGFloat(tick - position) * step
                    guard x >= 0, x <= size.width else { continue }
                    let opacity = pow(max(0, 1 - abs(x - center) / center), 1.8)
                    let height: CGFloat = Int(tick).isMultiple(of: 5) ? 15 : 6
                    let line = Path { p in
                        p.move(to: CGPoint(x: x, y: (size.height - height) / 2))
                        p.addLine(to: CGPoint(x: x, y: (size.height + height) / 2))
                    }
                    context.stroke(line, with: .color(ink.opacity(opacity * 0.4)), lineWidth: 1)
                }
                let needle = Path { p in
                    p.move(to: CGPoint(x: center, y: size.height / 2 - 12))
                    p.addLine(to: CGPoint(x: center, y: size.height / 2 + 12))
                }
                context.stroke(needle, with: .color(ink.opacity(0.8)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

struct DuplexFaceControl: View {
    @Environment(\.colorScheme) private var colorScheme
    let reversed: Bool
    let onSelect: (Bool) -> Void

    private var warm: Color { LifeTimerPalette.ink(reversed: false, scheme: colorScheme) }
    private var cool: Color { LifeTimerPalette.ink(reversed: true, scheme: colorScheme) }

    var body: some View {
        HStack(spacing: 15) {
            face("生之时", reversed: false, color: warm)
            Canvas { context, size in
                for side in 0..<2 {
                    let x: CGFloat = side == 0 ? 9 : 15
                    let curve = Path { p in
                        p.move(to: CGPoint(x: x, y: 7))
                        p.addQuadCurve(to: CGPoint(x: x, y: 25), control: CGPoint(x: side == 0 ? 0 : 24, y: 16))
                    }
                    context.stroke(curve, with: .color((side == 0 ? warm : cool).opacity((side == 1) == reversed ? 0.9 : 0.3)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                }
            }
            .frame(width: 24, height: 32)
            .accessibilityHidden(true)
            face("死之时", reversed: true, color: cool)
        }
    }

    private func face(_ name: String, reversed target: Bool, color: Color) -> some View {
        Button { onSelect(target) } label: {
            Text(name).font(.system(size: 12, weight: .regular)).tracking(2)
                .foregroundStyle(color.opacity(reversed == target ? 1 : 0.38))
                .frame(minWidth: 70, minHeight: 44)
                .overlay(alignment: .bottom) {
                    Capsule().fill(color.opacity(reversed == target ? 0.65 : 0))
                        .frame(width: 20, height: 1).padding(.bottom, 4)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(target ? "life.face.remaining" : "life.face.elapsed")
        .accessibilityAddTraits(reversed == target ? .isSelected : [])
        .accessibilityHint(target ? "切换到剩余人生" : "切换到已过人生")
    }
}

enum LifeTimerPalette {
    static func ink(reversed: Bool, scheme: ColorScheme) -> Color {
        if reversed {
            return scheme == .dark ? Color(red: 0.48, green: 0.79, blue: 0.82) : Color(red: 0.10, green: 0.40, blue: 0.44)
        }
        return scheme == .dark ? Color(red: 0.88, green: 0.69, blue: 0.43) : Color(red: 0.53, green: 0.32, blue: 0.09)
    }
}

