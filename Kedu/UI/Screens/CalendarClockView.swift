import SwiftUI

/// Calendar and event work happens once a minute, outside the live readout.
struct CalendarClockView: View {
    let profile: UserProfile
    let events: [TimeEvent]
    let selection: ClockScale
    let isActive: Bool
    let onMarkerTap: (UUID) -> Void

    var body: some View {
        TimelineView(.everyMinute) { timeline in
            let clock = ClockEngine.snapshot(
                scale: selection, at: timeline.date, calendar: ClockEngine.calendar(for: profile),
                profile: profile, events: events
            )
            CalendarDurationView(clock: clock, isActive: isActive, onMarkerTap: onMarkerTap)
                .id(selection)
        }
    }
}

private struct CalendarDurationView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.keduReduceMotion) private var reduceMotion
    let clock: ClockSnapshot
    let isActive: Bool
    let onMarkerTap: (UUID) -> Void
    @State private var now = Date.now

    private var ink: Color { LifeTimerPalette.ink(reversed: false, scheme: colorScheme) }
    private var title: String {
        switch clock.scale {
        case .day: "今日 · 已度过"
        case .month: "本月 · 已度过"
        default: "今年 · 已度过"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 36)
            VStack(spacing: 36) {
                ImmersiveTimeReadout(
                    title: title,
                    value: min(clock.interval.duration, max(0, now.timeIntervalSince(clock.interval.start))) / 86400,
                    unit: "天", ink: ink, identifier: "clock.\(clock.scale.rawValue)"
                )
                LiveTimeTrace(
                    origin: clock.interval.start, target: clock.interval.end, reversed: false,
                    isActive: isActive, reduceMotion: reduceMotion, sampledAt: now, ink: ink
                ).equatable().frame(height: 38).padding(.horizontal, 24)
            }
            .padding(.vertical, 30)
            Spacer(minLength: 36)
            PeriodEventRuler(clock: clock, ink: ink, onMarkerTap: onMarkerTap)
                .padding(.bottom, 24)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("timefield.\(clock.scale.rawValue)")
        .task(id: isActive) {
            guard isActive else { return }
            now = .now
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { break }
                guard !Task.isCancelled else { break }
                now = .now
            }
        }
    }
}

/// Event positions use real dates. Shared 44 pt bins expose overlapping markers in a menu.
private struct PeriodEventRuler: View {
    let clock: ClockSnapshot
    let ink: Color
    let onMarkerTap: (UUID) -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text(clock.headline).font(.system(size: 12, weight: .regular)).tracking(2)
                .foregroundStyle(.secondary)
            GeometryReader { proxy in
                let width = max(1, proxy.size.width - 44)
                let bins = max(1, Int(width / 44))
                let groups = Dictionary(grouping: clock.markers) { marker in
                    min(bins - 1, max(0, Int(ratio(marker.occurrence) * Double(bins))))
                }
                ZStack(alignment: .topLeading) {
                    Canvas { context, size in
                        let count = clock.scale == .year ? 12 : clock.totalUnits
                        for tick in 0...max(1, count) {
                            let x = 22 + width * CGFloat(tick) / CGFloat(max(1, count))
                            let line = Path { p in
                                p.move(to: CGPoint(x: x, y: 18))
                                p.addLine(to: CGPoint(x: x, y: tick == 0 || tick == count ? 30 : 23))
                            }
                            context.stroke(line, with: .color(.secondary.opacity(0.24)), lineWidth: 1)
                        }
                        let x = 22 + width * clock.progress
                        context.fill(Path(ellipseIn: CGRect(x: x - 2, y: 14, width: 4, height: 4)), with: .color(ink))
                        for marker in clock.markers {
                            let x = 22 + width * ratio(marker.occurrence)
                            context.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: 26, width: 3, height: 3)), with: .color(marker.color.color.opacity(0.65)))
                        }
                    }.accessibilityHidden(true)
                    ForEach(groups.keys.sorted(), id: \.self) { bin in
                        let markers = groups[bin] ?? []
                        if let marker = markers.first {
                            Group {
                                if markers.count == 1 {
                                    Button { onMarkerTap(marker.id) } label: {
                                        Image(systemName: marker.symbolName).frame(width: 44, height: 44)
                                    }
                                    .accessibilityLabel(marker.title)
                                    .accessibilityIdentifier("marker.\(marker.id)")
                                } else {
                                    Menu {
                                        ForEach(markers) { item in
                                            Button(item.title, systemImage: item.symbolName) { onMarkerTap(item.id) }
                                                .accessibilityIdentifier("marker.\(item.id)")
                                        }
                                    } label: {
                                        Image(systemName: "circle.grid.2x2").frame(width: 44, height: 44)
                                    }
                                    .accessibilityLabel("\(markers.count) 个刻点")
                                }
                            }
                            .font(.system(size: 13)).foregroundStyle(marker.color.color)
                            .buttonStyle(.plain)
                            .position(x: 22 + width * (Double(bin) + 0.5) / Double(bins), y: 46)
                        }
                    }
                }
            }.frame(height: 68)
        }
    }

    private func ratio(_ date: Date) -> Double {
        min(1, max(0, date.timeIntervalSince(clock.interval.start) / max(1, clock.interval.duration)))
    }
}
