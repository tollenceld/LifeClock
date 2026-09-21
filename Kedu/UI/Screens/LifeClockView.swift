import SwiftUI

/// Only this screen's clock ticks at 10 Hz. Calendar snapshots and SwiftData queries stay outside it.
struct LifeClockView: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.keduReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let profile: UserProfile
    let isActive: Bool
    let isVisible: Bool
    @Binding var isReversed: Bool
    @State private var now = Date.now
    @State private var angle = 0.0
    @State private var turning = false
    @State private var faceOpacity = 1.0
    @State private var flipTask: Task<Void, Never>?

    var body: some View {
        let snapshot = LifeClockSnapshot(
            at: now, calendar: ClockEngine.calendar(for: profile),
            birthDate: profile.birthDate, targetAge: profile.targetAge
        )
        let ink = LifeTimerPalette.ink(reversed: isReversed, scheme: colorScheme)
        VStack(spacing: 0) {
            Spacer(minLength: 36)
            VStack(spacing: 36) {
                ImmersiveTimeReadout(
                    title: isReversed ? "还剩" : "已度过",
                    value: (isReversed ? snapshot.remainingSeconds : snapshot.elapsedSeconds) / 86400,
                    unit: "天", ink: ink, identifier: "life.days"
                )
                LiveTimeTrace(
                    origin: snapshot.birthInstant, target: snapshot.targetInstant, reversed: isReversed,
                    isActive: isActive && !(isReversed && snapshot.isAtEnd), reduceMotion: reduceMotion,
                    sampledAt: now, ink: ink
                ).equatable().frame(height: 38).padding(.horizontal, 24)
            }
            .padding(.vertical, 30)
            .contentShape(Rectangle())
            .opacity(faceOpacity)
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
            .onTapGesture(perform: flip)
            .accessibilityElement(children: .contain)
            .accessibilityAction(named: "查看另一面") { flip() }
            .accessibilityIdentifier("life.flip")
            Spacer(minLength: 36)
            DuplexFaceControl(reversed: isReversed) { target in
                if target != isReversed { flip() }
            }
            .padding(.bottom, 38)
        }
        .padding(.bottom, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("clock.life")
        .overlay(alignment: .topLeading) {
            if CommandLine.arguments.contains("-uiTesting") {
                Text(isActive ? "active" : "paused")
                    .font(.system(size: 1)).opacity(0.001)
                    .frame(width: 1, height: 1)
                    .allowsHitTesting(false)
                    .accessibilityIdentifier("life.refresh")
                    .accessibilityValue(isActive ? "active" : "paused")
            }
        }
        .task(id: isActive) {
            guard isActive else { return }
            now = .now
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(100)) }
                catch { break }
                guard !Task.isCancelled else { break }
                now = .now

            }
        }
        .onChange(of: isVisible) { _, visible in
            if !visible { cancelFlip() }
        }
        .onDisappear(perform: cancelFlip)
    }

    private func flip() {
        guard !turning else { return }
        HapticManager.shared.selectionChanged(enabled: profile.hapticsEnabled)
        if reduceMotion {
            turning = true
            flipTask = Task { @MainActor in
                withAnimation(.easeOut(duration: 0.1)) { faceOpacity = 0 }
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                guard !Task.isCancelled else { return }
                isReversed.toggle()
                withAnimation(.easeIn(duration: 0.1)) { faceOpacity = 1 }
                do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
                turning = false
            }
            return
        }
        turning = true
        flipTask = Task { @MainActor in
            withAnimation(.easeIn(duration: 0.25)) { angle = 90 }
            do { try await Task.sleep(for: .milliseconds(250)) }
            catch { return }
            guard !Task.isCancelled else { return }
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                isReversed.toggle()
                angle = -90
            }
            // Commit the edge-on reverse face before beginning the second half.
            await Task.yield()
            withAnimation(.easeOut(duration: 0.25)) { angle = 0 }
            do { try await Task.sleep(for: .milliseconds(250)) }
            catch { return }
            turning = false
        }
    }

    private func cancelFlip() {
        flipTask?.cancel()
        flipTask = nil
        angle = 0
        faceOpacity = 1
        turning = false
    }
}
