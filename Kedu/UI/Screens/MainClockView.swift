import SwiftData
import SwiftUI

private enum SheetDestination: Identifiable {
    case edit(TimeEvent)
    case settings
    case library
    case add

    var id: String {
        switch self {
        case .edit(let event): "edit-\(event.id)"
        case .settings: "settings"
        case .library: "library"
        case .add: "add"
        }
    }
}

struct MainClockView: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.keduReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query(sort: \TimeEvent.createdAt) private var events: [TimeEvent]

    let profile: UserProfile
    @State private var selectedScale: ClockScale
    @State private var scalePosition: Double
    @State private var presentedSheet: SheetDestination?
    @State private var lifeIsReversed = false
    @State private var dragStartPosition: Double?

    init(profile: UserProfile) {
        self.profile = profile
        let arguments = CommandLine.arguments
        let requested = arguments.firstIndex(of: "-uiTestingScale").flatMap { index -> ClockScale? in
            guard arguments.indices.contains(index + 1) else { return nil }
            return ClockScale(rawValue: arguments[index + 1])
        }
        let initial = requested ?? .life
        _selectedScale = State(initialValue: initial)
        _scalePosition = State(initialValue: initial.position)
    }

    private var lifeIsActive: Bool {
        selectedScale == .life && presentedSheet == nil && scenePhase == .active
    }

    var body: some View {
        ZStack {
            theme.background(for: colorScheme).ignoresSafeArea()
            GeometryReader { available in
                ScrollView {
                    ZStack {
                        LifeClockView(
                            profile: profile,
                            isActive: lifeIsActive,
                            isVisible: selectedScale == .life,
                            isReversed: $lifeIsReversed
                        )
                        .opacity(selectedScale == .life ? 1 : 0)
                        .allowsHitTesting(selectedScale == .life)
                        .accessibilityHidden(selectedScale != .life)

                        if selectedScale != .life {
                            CalendarClockView(
                                profile: profile, events: events,
                                selection: selectedScale,
                                isActive: presentedSheet == nil && scenePhase == .active,
                                onMarkerTap: openEvent
                            )
                            .transition(.opacity)
                        }
                    }
                    .frame(height: max(440, available.size.height))
                    .contentShape(Rectangle())
                    .simultaneousGesture(scaleSwipe(width: available.size.width))
                }
                .scrollIndicators(.hidden)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ScaleBar(
                selection: $selectedScale,
                position: $scalePosition,
                hapticsEnabled: profile.hapticsEnabled,
                onSettings: { presentedSheet = .settings }
            )
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .sheet(item: $presentedSheet) { destination in
            switch destination {
            case .edit(let event):
                EventEditorView(event: event, defaultRecurrence: event.recurrence, profile: profile)
            case .settings:
                SettingsView(profile: profile)
            case .library:
                EventLibraryView(profile: profile)
            case .add:
                EventEditorView(event: nil, defaultRecurrence: .once, profile: profile)
            }
        }
        .onAppear(perform: openTestingDestination)
        .accessibilityAction(named: "上一个时间尺度") { moveScale(-1) }
        .accessibilityAction(named: "下一个时间尺度") { moveScale(1) }
    }

    private func openTestingDestination() {
        let arguments = CommandLine.arguments
        guard arguments.contains("-uiTesting") else { return }
        if arguments.contains("-uiTestingOpenLibrary") { presentedSheet = .library }
        else if arguments.contains("-uiTestingOpenSettings") { presentedSheet = .settings }
        else if arguments.contains("-uiTestingOpenEditEvent"), let event = events.first { presentedSheet = .edit(event) }
        else if arguments.contains("-uiTestingOpenEventEditor") { presentedSheet = .add }
    }

    private func openEvent(_ id: UUID) {
        guard let event = events.first(where: { $0.id == id && $0.scale != nil }) else { return }
        presentedSheet = .edit(event)
    }

    private func scaleSwipe(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 1.3 else { return }
                if dragStartPosition == nil { dragStartPosition = scalePosition }
                guard let start = dragStartPosition else { return }
                scalePosition = ScalePosition.interactionPosition(
                    start - Double(value.translation.width / max(1, width)), reduceMotion: reduceMotion
                )
                let next = ClockScale.at(position: scalePosition)
                if next != selectedScale {
                    selectedScale = next
                    HapticManager.shared.selectionChanged(enabled: profile.hapticsEnabled)
                }
            }
            .onEnded { value in
                guard let start = dragStartPosition else { return }
                dragStartPosition = nil
                let projected = start - Double(value.predictedEndTranslation.width / max(1, width))
                commit(ScalePosition.snapped(current: scalePosition, predicted: min(start + 1, max(start - 1, projected))))
            }
    }

    private func moveScale(_ offset: Int) {
        commit(ClockScale.at(position: selectedScale.position + Double(offset)))
    }

    private func commit(_ scale: ClockScale) {
        let changed = selectedScale != scale
        selectedScale = scale
        withAnimation(reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.88)) {
            scalePosition = scale.position
        }
        if changed { HapticManager.shared.selectionChanged(enabled: profile.hapticsEnabled) }
    }
}

#Preview("人生 · 石墨") {
    AppRootView().environment(AppTheme())
        .modelContainer(PreviewSupport.container(.multiple))
        .preferredColorScheme(.dark)
}

#Preview("人生 · 暖纸") {
    AppRootView().environment(AppTheme())
        .modelContainer(PreviewSupport.container(.empty))
        .preferredColorScheme(.light)
}
