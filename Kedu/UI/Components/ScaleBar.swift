import SwiftUI

struct ScaleBar: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.keduReduceMotion) private var reduceMotion
    @Namespace private var glassNamespace
    @Binding var selection: ClockScale
    @Binding var position: Double
    let hapticsEnabled: Bool
    let onSettings: () -> Void

    private let calendarScales: [ClockScale] = [.day, .month, .year]

    var body: some View {
        KeduGlassGroup(spacing: 6) {
            HStack(spacing: 12) {
                lifeButton
                calendarRail
            }
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.88), value: selection == .life)
        }
        .frame(height: 58)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("时间尺度导航")
    }

    private var lifeButton: some View {
        Button { select(.life) } label: {
            HStack(spacing: 8) {
                Image(systemName: "circle.dotted").font(.system(size: 23, weight: .regular))
                if selection == .life {
                    Text("人生").font(.system(size: 15, weight: .medium))
                        .fixedSize().transition(.opacity)
                }
            }
            .foregroundStyle(selection == .life ? Color.primary : theme.navigationLabel(for: colorScheme))
            .frame(width: selection == .life ? 96 : 58, height: 58)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .modifier(NavigationGlass(identity: "life", namespace: glassNamespace))
        .accessibilityLabel("人生时钟")
        .accessibilityIdentifier("scale.life")
        .accessibilityAddTraits(selection == .life ? .isSelected : [])
    }

    private var calendarRail: some View {
        GeometryReader { proxy in
            let width = proxy.size.width / 4
            ZStack {
                if selection != .life {
                    Capsule()
                        .fill(theme.navigationSelectionFill(for: colorScheme))
                        .overlay(Capsule().stroke(theme.navigationSelectionStroke(for: colorScheme), lineWidth: 0.5))
                        .frame(width: max(44, width - 8), height: 48)
                        .position(x: width * CGFloat(min(2, max(0, position - 1)) + 0.5), y: 29)
                        .accessibilityHidden(true)
                }
                HStack(spacing: 0) {
                    HStack(spacing: 0) {
                    ForEach(calendarScales) { scale in
                        Button { select(scale) } label: {
                            Text(scale.title)
                                .font(.system(size: 17, weight: selection == scale ? .semibold : .regular))
                                .foregroundStyle(selection == scale ? Color.primary : theme.navigationLabel(for: colorScheme))
                                .frame(maxWidth: .infinity, minHeight: 58)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(scale.accessibilityTitle)
                        .accessibilityIdentifier("scale.\(scale.rawValue)")
                        .accessibilityAddTraits(selection == scale ? .isSelected : [])
                    }
                    }
                    .frame(width: width * 3)
                    .contentShape(Rectangle())
                    .simultaneousGesture(scrubGesture(width: width * 3))
                    Button(action: onSettings) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 21, weight: .regular))
                            .foregroundStyle(theme.navigationLabel(for: colorScheme))
                            .frame(width: width, height: 58)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("设置")
                    .accessibilityIdentifier("settings.button")
                }
            }
            .modifier(NavigationGlass(identity: "calendar", namespace: glassNamespace))
            .contentShape(Capsule())
        }
        .frame(height: 58)
    }

    private func scrubGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                let normalized = min(1, max(0, value.location.x / max(1, width)))
                position = ScalePosition.interactionPosition(min(3, max(1, 0.5 + Double(normalized) * 3)), reduceMotion: reduceMotion)
                let next = ClockScale.at(position: position)
                if next != selection {
                    selection = next
                    HapticManager.shared.selectionChanged(enabled: hapticsEnabled)
                }
            }
            .onEnded { value in
                let projected = min(3, max(1, 0.5 + Double(value.predictedEndLocation.x / max(1, width)) * 3))
                select(ScalePosition.snapped(current: position, predicted: projected))
            }
    }

    private func select(_ scale: ClockScale) {
        let changed = selection != scale
        selection = scale
        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.86)) {
            position = scale.position
        }
        if changed { HapticManager.shared.selectionChanged(enabled: hapticsEnabled) }
    }
}

private struct NavigationGlass: ViewModifier {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
    let identity: String
    let namespace: Namespace.ID

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .capsule)
                .glassEffectID(identity, in: namespace)
        } else {
            content.background(theme.glassFallback(for: colorScheme), in: Capsule())
                .overlay(Capsule().stroke(theme.glassStroke(for: colorScheme), lineWidth: 0.5))
        }
    }
}
