import SwiftUI

struct ScaleBar: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var selection: ClockScale
    @Binding var position: Double
    let hapticsEnabled: Bool

    var body: some View {
        GeometryReader { proxy in
            let itemWidth = proxy.size.width / CGFloat(ClockScale.allCases.count)

            ZStack {
                selectionIndicator(width: itemWidth)
                    .position(
                        x: itemWidth * CGFloat(ScalePosition.clamped(position) + 0.5),
                        y: proxy.size.height / 2
                    )

                HStack(spacing: 0) {
                    ForEach(ClockScale.allCases) { scale in
                        scaleButton(scale)
                            .frame(width: itemWidth)
                            .frame(minHeight: 56)
                    }
                }
            }
            .background {
                glassTrack
            }
            .contentShape(Capsule())
            .simultaneousGesture(scrubGesture(width: proxy.size.width))
        }
        .frame(height: 64)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("时间尺度导航")
    }

    private func selectionIndicator(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 23, style: .continuous)
            .fill(theme.navigationSelectionFill(for: colorScheme))
            .overlay {
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .stroke(theme.navigationSelectionStroke(for: colorScheme), lineWidth: 0.7)
            }
            .frame(width: max(48, width - 8), height: 50)
            .shadow(
                color: theme.accent.opacity(colorScheme == .dark ? 0.08 : 0.06),
                radius: 10,
                y: 3
            )
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var glassTrack: some View {
        if #available(iOS 26.0, *) {
            Capsule()
                .fill(.clear)
                .glassEffect(.regular, in: .capsule)
        } else {
            Capsule()
                .fill(theme.glassFallback(for: colorScheme))
                .overlay(Capsule().stroke(theme.glassStroke(for: colorScheme), lineWidth: 0.5))
        }
    }

    private func scaleButton(_ scale: ClockScale) -> some View {
        Button {
            select(scale)
        } label: {
            VStack(spacing: 5) {
                Text(scale.title)
                    .font(.system(size: 14, weight: selection == scale ? .semibold : .medium))
                    .foregroundStyle(
                        selection == scale
                            ? Color.primary
                            : theme.navigationLabel(for: colorScheme)
                    )
                    .lineLimit(1)
                    .fixedSize()

                Circle()
                    .fill(selection == scale ? theme.accent : .clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(scale.accessibilityTitle)
        .accessibilityAddTraits(selection == scale ? .isSelected : [])
        .accessibilityIdentifier("scale.\(scale.rawValue)")
    }

    private func scrubGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                let usableWidth = max(1, width)
                let normalized = min(1, max(0, value.location.x / usableWidth))
                position = Double(normalized) * ScalePosition.bounds.upperBound
                synchronizeSelection()
            }
            .onEnded { value in
                let usableWidth = max(1, width)
                let current = Double(min(1, max(0, value.location.x / usableWidth)))
                    * ScalePosition.bounds.upperBound
                let predicted = Double(min(1, max(0, value.predictedEndLocation.x / usableWidth)))
                    * ScalePosition.bounds.upperBound
                commit(ScalePosition.snapped(current: current, predicted: predicted))
            }
    }

    private func synchronizeSelection() {
        let scale = ClockScale.at(position: position)
        guard scale != selection else { return }
        selection = scale
        HapticManager.shared.selectionChanged(enabled: hapticsEnabled)
    }

    private func select(_ scale: ClockScale) {
        guard selection != scale || position != scale.position else { return }
        selection = scale
        if reduceMotion {
            position = scale.position
        } else {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.84)) {
                position = scale.position
            }
        }
        HapticManager.shared.selectionChanged(enabled: hapticsEnabled)
    }

    private func commit(_ scale: ClockScale) {
        let changed = selection != scale
        selection = scale
        if reduceMotion {
            position = scale.position
        } else {
            withAnimation(.spring(response: 0.40, dampingFraction: 0.86)) {
                position = scale.position
            }
        }
        if changed {
            HapticManager.shared.selectionChanged(enabled: hapticsEnabled)
        }
    }
}
