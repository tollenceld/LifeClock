import SwiftData
import SwiftUI

private enum SheetDestination: Identifiable {
    case add(RecurrenceRule)
    case edit(TimeEvent)
    case settings

    var id: String {
        switch self {
        case .add(let recurrence): "add-\(recurrence.rawValue)"
        case .edit(let event): "edit-\(event.id.uuidString)"
        case .settings: "settings"
        }
    }
}

struct MainClockView: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \TimeEvent.createdAt) private var events: [TimeEvent]

    let profile: UserProfile

    @State private var selectedScale: ClockScale
    @State private var scalePosition: Double
    @State private var presentedSheet: SheetDestination?

    init(profile: UserProfile) {
        self.profile = profile
        let arguments = CommandLine.arguments
        let requestedScale: ClockScale? = arguments.firstIndex(of: "-uiTestingScale").flatMap { index in
            guard arguments.indices.contains(index + 1) else { return nil }
            return ClockScale(rawValue: arguments[index + 1])
        }
        let initialScale = requestedScale ?? .year
        _selectedScale = State(initialValue: initialScale)
        _scalePosition = State(initialValue: initialScale.position)
    }

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { timeline in
                let calendar = ClockEngine.calendar(for: profile)
                let dashboard = ClockEngine.dashboard(
                    at: timeline.date,
                    calendar: calendar,
                    profile: profile,
                    events: events
                )
                let currentPresentation = dashboard[selectedScale]

                ZStack {
                    theme.background(for: colorScheme).ignoresSafeArea()

                    VStack(spacing: 0) {
                        header

                        ClockPageView(
                            presentations: dashboard.presentations,
                            selection: $selectedScale,
                            position: $scalePosition,
                            hapticsEnabled: profile.hapticsEnabled,
                            onMarkerTap: openEvent
                        )
                        .frame(maxHeight: .infinity)

                        EventSummaryRow(
                            marker: currentPresentation.clock.nearestMarker(to: timeline.date),
                            snapshot: currentPresentation.clock,
                            onOpen: openEvent,
                            onAdd: {
                                presentedSheet = .add(recurrence(for: selectedScale))
                            }
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                        ScaleBar(
                            selection: $selectedScale,
                            position: $scalePosition,
                            hapticsEnabled: profile.hapticsEnabled
                        )
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(item: $presentedSheet) { destination in
            switch destination {
            case .add(let recurrence):
                EventEditorView(event: nil, defaultRecurrence: recurrence, profile: profile)
            case .edit(let event):
                EventEditorView(event: event, defaultRecurrence: event.recurrence, profile: profile)
            case .settings:
                SettingsView(profile: profile)
            }
        }
        .onAppear {
            let arguments = CommandLine.arguments
            if arguments.contains("-uiTestingOpenSettings") {
                presentedSheet = .settings
            } else if arguments.contains("-uiTestingOpenEditEvent"), let event = events.first {
                presentedSheet = .edit(event)
            } else if arguments.contains("-uiTestingOpenEventEditor") {
                presentedSheet = .add(.yearly)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("刻度")
                .font(.system(size: 22, weight: .semibold))
                .tracking(-0.4)

            Spacer()

            settingsButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .frame(height: 58)
    }

    @ViewBuilder
    private var settingsButton: some View {
        if #available(iOS 26.0, *) {
            Button {
                presentedSheet = .settings
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("设置")
            .accessibilityIdentifier("settings.button")
        } else {
            Button {
                presentedSheet = .settings
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 44, height: 44)
                    .background(theme.glassFallback(for: colorScheme), in: Circle())
                    .overlay(Circle().stroke(theme.glassStroke(for: colorScheme), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("设置")
            .accessibilityIdentifier("settings.button")
        }
    }

    private func openEvent(_ id: UUID) {
        guard let event = events.first(where: { $0.id == id }) else { return }
        presentedSheet = .edit(event)
    }

    private func recurrence(for scale: ClockScale) -> RecurrenceRule {
        switch scale {
        case .life: .once
        case .year: .yearly
        case .month: .monthly
        case .week: .weekly
        case .day: .daily
        }
    }
}

private struct ClockPageView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let presentations: [ClockPresentationSnapshot]
    @Binding var selection: ClockScale
    @Binding var position: Double
    let hapticsEnabled: Bool
    let onMarkerTap: (UUID) -> Void

    @State private var dragStartPosition: Double?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ScaleInstrumentContent(
                    presentations: presentations,
                    position: position,
                    onMarkerTap: onMarkerTap
                )

                Text("\(selection.accessibilityTitle)仪表")
                    .font(.system(size: 1))
                    .foregroundStyle(Color.primary.opacity(0.001))
                    .frame(width: 1, height: 1)
                    .allowsHitTesting(false)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(selection.accessibilityTitle)仪表")
                    .accessibilityIdentifier("clock.\(selection.rawValue)")
                    .accessibilityAction(named: "上一个时间尺度") {
                        commit(scaleOffset: -1)
                    }
                    .accessibilityAction(named: "下一个时间尺度") {
                        commit(scaleOffset: 1)
                    }
            }
            .contentShape(Rectangle())
            .gesture(scaleSwipe(width: proxy.size.width))
        }
    }

    private func scaleSwipe(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 16)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if dragStartPosition == nil {
                    dragStartPosition = position
                }
                guard let dragStartPosition else { return }

                let proposed = ScalePosition.clamped(
                    dragStartPosition - Double(value.translation.width / max(1, width))
                )
                position = ScalePosition.interactionPosition(
                    proposed,
                    reduceMotion: reduceMotion
                )
                synchronizeSelection()
            }
            .onEnded { value in
                guard let dragStartPosition else { return }
                let predicted = ScalePosition.clamped(
                    dragStartPosition - Double(value.predictedEndTranslation.width / max(1, width))
                )
                let target = ScalePosition.snapped(current: position, predicted: predicted)
                self.dragStartPosition = nil
                commit(target)
            }
    }

    private func synchronizeSelection() {
        let newSelection = ClockScale.at(position: position)
        guard newSelection != selection else { return }
        selection = newSelection
        HapticManager.shared.selectionChanged(enabled: hapticsEnabled)
    }

    private func commit(scaleOffset: Int) {
        let currentIndex = Int(selection.position)
        let targetIndex = min(
            ClockScale.allCases.count - 1,
            max(0, currentIndex + scaleOffset)
        )
        commit(ClockScale.allCases[targetIndex])
    }

    private func commit(_ scale: ClockScale) {
        let changed = selection != scale
        selection = scale
        if reduceMotion {
            position = scale.position
        } else {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
                position = scale.position
            }
        }
        if changed {
            HapticManager.shared.selectionChanged(enabled: hapticsEnabled)
        }
    }
}

private struct ScaleInstrumentContent: View, @preconcurrency Animatable {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let presentations: [ClockPresentationSnapshot]
    var position: Double
    let onMarkerTap: (UUID) -> Void

    var animatableData: Double {
        get { position }
        set { position = newValue }
    }

    var body: some View {
        let interpolation = ScalePosition.interpolation(at: position)
        let lower = presentations[Int(interpolation.lower.position)]
        let upper = presentations[Int(interpolation.upper.position)]
        let progress = interpolation.progress

        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                MetricStrip(snapshot: lower.clock)
                    .opacity(1 - progress)
                    .offset(x: -18 * progress)

                if lower.scale != upper.scale {
                    MetricStrip(snapshot: upper.clock)
                        .opacity(progress)
                        .offset(x: 18 * (1 - progress))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 8)

            GeometryReader { proxy in
                let insightHeight = min(132, max(112, proxy.size.height * 0.30))

                VStack(spacing: 0) {
                    TimeFieldView(
                        source: lower,
                        target: upper,
                        progress: progress,
                        onMarkerTap: onMarkerTap
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    .frame(maxHeight: .infinity)

                    Rectangle()
                        .fill(theme.tertiaryLabel(for: colorScheme).opacity(0.16))
                        .frame(height: 0.5)
                        .padding(.horizontal, 14)

                    InsightTransitionView(
                        source: lower,
                        target: upper,
                        progress: progress
                    )
                    .frame(height: insightHeight)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(theme.tertiaryLabel(for: colorScheme).opacity(0.18), lineWidth: 0.5)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 2)
        }
    }

    private struct MetricStrip: View {
        @Environment(AppTheme.self) private var theme
        @Environment(\.colorScheme) private var colorScheme

        let snapshot: ClockSnapshot

        var body: some View {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text(snapshot.headline)
                    .font(.system(size: 52, weight: .light, design: .monospaced))
                    .monospacedDigit()
                    .tracking(-1.6)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)

                Spacer(minLength: 8)

                Text(snapshot.countText)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text(snapshot.progressText)
                    .font(.system(size: 17, weight: .medium, design: .monospaced))
                    .monospacedDigit()
            }
        }
    }
}

private struct InsightTransitionView: View {
    let source: ClockPresentationSnapshot
    let target: ClockPresentationSnapshot
    let progress: Double

    var body: some View {
        let activePresentation = progress < 0.5 ? source : target

        ZStack {
            InsightContent(presentation: source)
                .opacity(1 - progress)
                .offset(x: -10 * progress)
                .accessibilityHidden(true)

            if source.scale != target.scale {
                InsightContent(presentation: target)
                    .opacity(progress)
                    .offset(x: 10 * (1 - progress))
                    .accessibilityHidden(true)
            }

            VStack(spacing: 0) {
                Text("\(activePresentation.scale.accessibilityTitle)阶段信息")
                    .accessibilityLabel("\(activePresentation.scale.accessibilityTitle)阶段信息")
                    .accessibilityValue(
                        "\(activePresentation.stageTitle)，\(activePresentation.stageDetail)，\(activePresentation.remainingText)"
                    )
                    .accessibilityIdentifier("insight.\(activePresentation.scale.rawValue)")

                Text("\(activePresentation.scale.accessibilityTitle)尺度关系")
                    .accessibilityLabel("\(activePresentation.scale.accessibilityTitle)尺度关系")
                    .accessibilityValue(
                        activePresentation.relatedProgress
                            .map { "\($0.scale.title) \($0.progressText)" }
                            .joined(separator: "，")
                    )
                    .accessibilityIdentifier("relations.\(activePresentation.scale.rawValue)")
            }
            .font(.system(size: 1))
            .foregroundStyle(Color.primary.opacity(0.001))
            .frame(width: 1, height: 1)
            .allowsHitTesting(false)
        }
    }
}

private struct InsightContent: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let presentation: ClockPresentationSnapshot

    var body: some View {
        VStack(spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(presentation.stageTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)

                    Text(presentation.stageDetail)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(presentation.remainingText)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .lineLimit(1)

                    if presentation.periodEventCount > 0 {
                        Text("本周期 \(presentation.periodEventCount) 个刻点")
                            .font(.system(size: 9, weight: .regular))
                            .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                            .lineLimit(1)
                    }
                }
            }

            FocusProgressBand(values: presentation.focusProgress)

            ScaleRelationshipRows(
                values: presentation.relatedProgress,
                selectedScale: presentation.scale
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("insight.\(presentation.scale.rawValue)")
    }
}

private struct FocusProgressBand: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let values: [Double]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Capsule()
                    .fill(color(for: value))
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }

    private func color(for value: Double) -> Color {
        if value >= 0.999 { return theme.completedDot(for: colorScheme).opacity(0.78) }
        if value > 0 { return theme.accent }
        return theme.futureDot(for: colorScheme)
    }
}

private struct ScaleRelationshipRows: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let values: [ScaleProgressSnapshot]
    let selectedScale: ClockScale

    var body: some View {
        VStack(spacing: 3) {
            ForEach(values) { value in
                let selected = value.scale == selectedScale
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(selected ? theme.accent : .clear)
                            .frame(width: 4, height: 4)

                        Text(value.scale.title)
                            .font(.system(size: 9, weight: selected ? .semibold : .medium))
                    }
                    .foregroundStyle(selected ? Color.primary : theme.navigationLabel(for: colorScheme))
                    .frame(width: 30, alignment: .leading)

                    SegmentedRelationshipBar(progress: value.progress, selected: selected)

                    Text(value.progressText)
                        .font(.system(size: 9, weight: selected ? .medium : .regular, design: .monospaced))
                        .foregroundStyle(selected ? Color.primary : theme.secondaryLabel(for: colorScheme))
                        .monospacedDigit()
                        .frame(width: 42, alignment: .trailing)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("尺度关系")
        .accessibilityValue(values.map { "\($0.scale.title) \($0.progressText)" }.joined(separator: "，"))
        .accessibilityIdentifier("relations.\(selectedScale.rawValue)")
    }
}

private struct SegmentedRelationshipBar: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let progress: Double
    let selected: Bool

    var body: some View {
        GeometryReader { proxy in
            let count = 12
            let spacing: CGFloat = 2
            let segmentWidth = max(1, (proxy.size.width - spacing * CGFloat(count - 1)) / CGFloat(count))

            HStack(spacing: spacing) {
                ForEach(0..<count, id: \.self) { index in
                    let start = Double(index) / Double(count)
                    let filled = progress > start
                    Capsule()
                        .fill(segmentColor(filled: filled, index: index, count: count))
                        .frame(width: segmentWidth)
                }
            }
        }
        .frame(height: 4)
        .accessibilityHidden(true)
    }

    private func segmentColor(filled: Bool, index: Int, count: Int) -> Color {
        guard filled else { return theme.futureDot(for: colorScheme) }
        let currentIndex = min(count - 1, max(0, Int(progress * Double(count))))
        if selected, index == currentIndex { return theme.accent }
        return theme.completedDot(for: colorScheme).opacity(selected ? 0.72 : 0.42)
    }
}

private struct EventSummaryRow: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let marker: EventMarkerSnapshot?
    let snapshot: ClockSnapshot
    let onOpen: (UUID) -> Void
    let onAdd: () -> Void

    var body: some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
                .background(theme.glassFallback(for: colorScheme), in: Capsule())
                .overlay(Capsule().stroke(theme.glassStroke(for: colorScheme), lineWidth: 0.5))
        }
    }

    private var content: some View {
        HStack(spacing: 10) {
            eventContent

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 48, height: 48)
                    .background(theme.accent, in: Circle())
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("添加刻点")
            .accessibilityIdentifier("event.add")
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .frame(height: 60)
    }

    @ViewBuilder
    private var eventContent: some View {
        if let marker {
            Button {
                onOpen(marker.id)
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: marker.symbolName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(marker.color.color)
                        .frame(width: 22)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(marker.title)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                        Text(relativeDescription(for: marker))
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                            .monospacedDigit()
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("event.summary")
        } else {
            HStack(spacing: 11) {
                Image(systemName: "circle.dotted")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text("还没有刻点")
                        .font(.system(size: 14, weight: .medium))
                    Text("为\(snapshot.scale.title)添加第一个事件")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                }
                Spacer()
            }
        }
    }

    private func relativeDescription(for marker: EventMarkerSnapshot) -> String {
        let days = Calendar.autoupdatingCurrent.dateComponents([.day], from: .now, to: marker.occurrence).day ?? 0
        if days == 0 {
            return marker.occurrence.formatted(date: .omitted, time: .shortened)
        }
        return days > 0 ? "\(days) 天后" : "\(abs(days)) 天前"
    }
}

#Preview("主界面 · 深色") {
    AppRootView()
        .environment(AppTheme())
        .modelContainer(PreviewSupport.container(.multiple))
        .preferredColorScheme(.dark)
}

#Preview("主界面 · 浅色空状态") {
    AppRootView()
        .environment(AppTheme())
        .modelContainer(PreviewSupport.container(.empty))
        .preferredColorScheme(.light)
}

#Preview("主界面 · 超大字体") {
    AppRootView()
        .environment(AppTheme())
        .modelContainer(PreviewSupport.container(.single))
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility2)
}
