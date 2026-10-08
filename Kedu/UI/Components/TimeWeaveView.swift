import SwiftUI

/// Overall progress and the minute under observation are deliberately separate scales.
enum TimeWeaveGeometry {
    static func minuteFraction(at date: Date) -> Double {
        let seconds = date.timeIntervalSince1970
        return (seconds - floor(seconds / 60) * 60) / 60
    }

    static func minutePosition(at date: Date) -> Double {
        let minute = Int(floor(date.timeIntervalSince1970 / 60))
        let fraction = minuteFraction(at: date)
        // The shuttle changes direction on each minute. Adjacent minutes join at
        // the same edge, so the real clock never produces a jump across the field.
        return minute.isMultiple(of: 2) ? fraction : 1 - fraction
    }

    static func mix(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * min(1, max(0, t))
    }
}

struct TimeWeaveGlyph: View {
    var body: some View {
        Canvas { context, size in
            for column in 0...5 {
                let x = 2 + (size.width - 4) * Double(column) / 5
                context.stroke(Path { p in
                    p.move(to: CGPoint(x: x, y: 2))
                    p.addLine(to: CGPoint(x: x, y: size.height - 2))
                }, with: .foreground, lineWidth: 0.6)
            }
            for row in 0...3 {
                let y = 2 + Double(row) * 3.2
                context.stroke(Path { p in
                    p.move(to: CGPoint(x: 1, y: y))
                    p.addLine(to: CGPoint(x: size.width - 1, y: y))
                }, with: .foreground, lineWidth: 1)
            }
        }
    }
}

/// One instrument, four intervals. Facts sit together beneath their shared woven field.
struct TimeWeaveInstrument: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    let contexts: [TimePhaseContext]
    let snapshot: TimePhaseSnapshot
    let zoom: Double
    let availableHeight: CGFloat
    let onMarkerTap: (UUID) -> Void

    private var life: Bool { snapshot.scale == .life }
    private var context: TimePhaseContext { contexts[Int(snapshot.scale.position)] }
    private var prefix: String { life ? "life" : "clock.\(snapshot.scale.rawValue)" }
    private var wideType: Bool { typeSize >= .xxLarge }

    var body: some View {
        VStack(spacing: wideType ? 26 : 22) {
            (wideType ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
                      : AnyLayout(HStackLayout(alignment: .firstTextBaseline))) {
                Text(snapshot.scale.title)
                    .font(.system(.title2, design: .serif)).tracking(4)
                    .accessibilityIdentifier(life ? "life.title" : "\(prefix).title")
                if !wideType { Spacer(minLength: 12) }
                Text("此刻  " + snapshot.progress.formatted(.percent.precision(.fractionLength(1))))
                    .font(.caption).monospacedDigit()
                    .foregroundStyle(theme.secondaryLabel(for: scheme))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("此刻")
                    .accessibilityValue(snapshot.progress.formatted(.percent.precision(.fractionLength(1))))
                    .accessibilityIdentifier("\(prefix).progress")
                    .accessibilitySortPriority(3)
            }
            .foregroundStyle(theme.primaryLabel(for: scheme))

            TimeWeaveField(contexts: contexts, snapshot: snapshot, zoom: zoom,
                           onMarkerTap: life ? nil : onMarkerTap)
                .frame(height: wideType ? 170 : min(340, max(150, availableHeight * 0.47)))
                .accessibilityHidden(life)

            // The growing and shrinking readings share a baseline; neither is a separate card.
            (wideType ? AnyLayout(VStackLayout(alignment: .leading, spacing: 28))
                      : AnyLayout(HStackLayout(alignment: .top, spacing: 20))) {
                reading(past: true)
                reading(past: false)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    basis(start: true)
                    Spacer(minLength: 8)
                    basis(start: false)
                }
                VStack(alignment: .leading, spacing: 12) {
                    basis(start: true)
                    basis(start: false)
                }
            }
            .padding(.top, 2)
            if life && snapshot.isAtEnd {
                Text("已达设定终点").font(.caption)
                    .foregroundStyle(theme.secondaryLabel(for: scheme))
                    .accessibilityIdentifier("life.endpoint")
            }
        }
        .frame(maxWidth: 440)
    }

    private func reading(past: Bool) -> some View {
        ImmersiveTimeReadout(title: life ? (past ? "生之始" : "死之终") : (past ? "已度过" : "尚余"),
                             value: (past ? snapshot.elapsedSeconds : snapshot.remainingSeconds) / 86_400,
                             unit: "天", ink: past ? theme.primaryLabel(for: scheme) : theme.futureInk(for: scheme),
                             identifier: past ? (life ? "life.days" : prefix) : "\(prefix).remaining",
                             detail: life ? (past ? "已度过" : "预计尚余") : nil,
                             stacksPrecision: !wideType, digitScale: wideType ? 1 : 0.94,
                             precisionScale: 0.85)
            .accessibilitySortPriority(past ? 4 : 2)
    }

    private func basis(start: Bool) -> some View {
        Text(start ? context.startLabel : context.endLabel)
            .font(.caption).monospacedDigit()
            .foregroundStyle(theme.secondaryLabel(for: scheme))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier(life ? (start ? "life.birth" : "life.basis") : "\(prefix).\(start ? "start" : "end")")
            .accessibilitySortPriority(1)
    }
}

/// The solid weft records the past; bare warp leaves the future visibly unfinished.
/// The current weft is a one-minute loupe, never an accelerated lifetime animation.
struct TimeWeaveField: View, Animatable {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var scheme
    @Environment(\.keduReduceMotion) private var reduceMotion
    @Environment(\.keduReduceTransparency) private var reduceTransparency
    let contexts: [TimePhaseContext]
    let snapshot: TimePhaseSnapshot
    nonisolated var zoom: Double
    var showsMinute = true
    var onMarkerTap: ((UUID) -> Void)? = nil

    nonisolated var animatableData: Double {
        get { zoom }
        set { zoom = newValue }
    }

    var body: some View {
        let pair = PhaseZoom.interpolation(at: zoom)
        let source = contexts[Int(pair.lower.position)]
        let target = contexts[Int(pair.upper.position)]
        let from = TimePhaseSnapshot(scale: pair.lower, interval: source.clock.interval, at: snapshot.date).progress
        let to = TimePhaseSnapshot(scale: pair.upper, interval: target.clock.interval, at: snapshot.date).progress
        let progress = TimeWeaveGeometry.mix(from, to, pair.progress)
        VStack(spacing: 8) {
            Canvas { ctx, size in
                let left = size.width * 0.10
                let right = size.width * 0.84
                let top = PhaseFieldGeometry.inset
                let bottom = size.height - top
                let y = PhaseFieldGeometry.boundaryY(progress: progress, height: size.height)
                let ink = theme.primaryLabel(for: scheme)
                let subtle = theme.futureInk(for: scheme)
                let breadth = right - left
                // The panel has no case, dial, track or illustrative frame.
                // A slight edge taper gives the same field a woven, tangible surface.
                var warp = Path()
                for column in 0...52 {
                    let fraction = Double(column) / 52
                    let x = left + breadth * fraction
                    warp.move(to: CGPoint(x: x, y: top))
                    warp.addLine(to: CGPoint(x: x, y: bottom))
                }
                ctx.stroke(warp, with: .color(subtle.opacity(reduceTransparency ? 0.36 : 0.20)), lineWidth: 0.5)
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: left, y: bottom))
                    p.addLine(to: CGPoint(x: right, y: bottom))
                }, with: .color(subtle.opacity(0.35)), lineWidth: 0.5)
                // Preserve the stitch size in calibration thumbnails and on compact
                // screens; squeezing a full-size weave would create a solid stripe.
                let rows = min(120, max(12, Int((bottom - top) / 2.1)))
                var heavyWeft = Path()
                var fineWeft = Path()
                var crossings = Path()
                for row in 0...rows {
                    let fraction = Double(row) / Double(rows)
                    let rowY = top + (bottom - top) * fraction
                    guard rowY <= y else { continue }
                    let edge = 3 + 2 * sin(Double(row) * 1.7)
                    let path = Path { p in
                        p.move(to: CGPoint(x: left + edge, y: rowY))
                        p.addLine(to: CGPoint(x: right - edge, y: rowY))
                    }
                    if row.isMultiple(of: 3) { heavyWeft.addPath(path) }
                    else { fineWeft.addPath(path) }
                    for column in stride(from: row % 2, to: 52, by: 2) {
                        let x = left + breadth * Double(column) / 52
                        crossings.move(to: CGPoint(x: x, y: rowY - 0.6))
                        crossings.addLine(to: CGPoint(x: x, y: rowY + 0.6))
                    }
                }
                // Batch the interlacing into three strokes instead of thousands of
                // draw calls. No independent animation timer or persistence reads.
                ctx.stroke(heavyWeft, with: .color(ink.opacity(0.76)), lineWidth: 0.75)
                ctx.stroke(fineWeft, with: .color(ink.opacity(0.48)), lineWidth: 0.75)
                ctx.stroke(crossings, with: .color(theme.background(for: scheme)), lineWidth: 1)
                let count = max(source.grain.count, target.grain.count)
                for index in 0..<count {
                    if size.height < 180 && index > 0 && index < count - 1 && !index.isMultiple(of: 5) { continue }
                    let a = source.grain[min(index, source.grain.count - 1)]
                    let b = target.grain[min(index, target.grain.count - 1)]
                    let fraction = TimeWeaveGeometry.mix(a, b, pair.progress)
                    let visibility = TimeWeaveGeometry.mix(index < source.grain.count ? 1 : 0,
                                                          index < target.grain.count ? 1 : 0, pair.progress)
                    let rowY = PhaseFieldGeometry.boundaryY(progress: fraction, height: size.height)
                    let path = Path { p in
                        p.move(to: CGPoint(x: left - 8, y: rowY))
                        p.addLine(to: CGPoint(x: left - 4, y: rowY))
                    }
                    ctx.stroke(path, with: .color(ink.opacity((fraction <= progress ? 0.65 : 0.25) * visibility)), lineWidth: 0.65)
                }
                // One fine copper weft joins solid history to unfinished space.
                ctx.stroke(Path { p in
                    p.move(to: CGPoint(x: left - 2, y: y))
                    p.addLine(to: CGPoint(x: right + 2, y: y))
                }, with: .color(theme.boundaryInk(for: scheme)), lineWidth: 1)
                if showsMinute && !snapshot.isAtEnd && !reduceMotion {
                    let x = left + breadth * TimeWeaveGeometry.minutePosition(at: snapshot.date)
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 2, y: y - 2, width: 4, height: 4)), with: .color(theme.boundaryInk(for: scheme)))
                }
            }
            .allowsHitTesting(false)
            .overlay {
                if snapshot.scale != .life {
                    GeometryReader { proxy in
                        ForEach(contexts[Int(snapshot.scale.position)].clock.markers) { marker in
                            let ratio = marker.occurrence.timeIntervalSince(snapshot.interval.start) / max(1, snapshot.interval.duration)
                            Circle().fill(theme.secondaryLabel(for: scheme)).frame(width: 3, height: 3)
                                .position(x: proxy.size.width - 22,
                                          y: PhaseFieldGeometry.boundaryY(progress: ratio, height: proxy.size.height))
                        }
                    }.accessibilityHidden(true).allowsHitTesting(false)
                }
            }
            .overlay {
                if let onMarkerTap, snapshot.scale != .life {
                    GeometryReader { proxy in
                        PhaseMarkerControls(clock: contexts[Int(snapshot.scale.position)].clock,
                                            size: proxy.size, onMarkerTap: onMarkerTap).equatable()
                    }
                }
            }
            // Caption belongs outside the drawing, so the native hit areas share the
            // exact same calendar-to-pixel transform as the ink marks above.
            if showsMinute {
                Text(snapshot.isAtEnd ? "设定终点" : "这一分钟  " + snapshot.date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits)).replacingOccurrences(of: " ", with: ""))
                    .font(.caption2).monospacedDigit().tracking(1)
                    .foregroundStyle(theme.secondaryLabel(for: scheme))
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 16)
                    .accessibilityHidden(true)
            }
        }
    }
}
