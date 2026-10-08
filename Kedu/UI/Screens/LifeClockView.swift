import SwiftUI
import UIKit

/// Owns cached calendar material. The 10 Hz date lives in the small child below.
struct TimePhaseClockView: View {
    let profile: UserProfile
    let events: [TimeEvent]
    let selection: ClockScale
    let scalePosition: Double
    let isActive: Bool
    let availableHeight: CGFloat
    let onMarkerTap: (UUID) -> Void
    @State private var contexts: [TimePhaseContext] = []
    @State private var refreshedAt = Date.distantPast

    private struct Revision: Hashable {
        let birthDate: Date
        let targetAge: Int
        let timeZoneIdentifier: String?
        let active: Bool
        let eventIDs: [UUID]
        let eventRevisions: [Date]
    }

    private var revision: Revision {
        Revision(birthDate: profile.birthday(in: ClockEngine.calendar(for: profile)), targetAge: profile.targetAge,
                 timeZoneIdentifier: profile.birthTimeZoneIdentifier, active: isActive,
                 eventIDs: events.map(\.id), eventRevisions: events.map(\.updatedAt))
    }

    var body: some View {
        Group {
            if contexts.count == ClockScale.allCases.count {
                PhaseLiveReadout(contexts: contexts, selection: selection, scalePosition: scalePosition,
                                 isActive: isActive, availableHeight: availableHeight,
                                 refreshedAt: refreshedAt, onRefresh: refresh, onMarkerTap: onMarkerTap)
            }
        }
        .task(id: revision) { refresh(at: .now) }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            refresh(at: .now)
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            refresh(at: .now)
        }
    }

    private func refresh(at date: Date) {
        let calendar = ClockEngine.calendar(for: profile)
        contexts = ClockScale.allCases.map {
            TimePhaseContext.make(scale: $0, at: date, calendar: calendar, profile: profile, events: events)
        }
        refreshedAt = date
    }
}

private struct PhaseLiveReadout: View {
    @Environment(\.keduReduceMotion) private var reduceMotion
    let contexts: [TimePhaseContext]
    let selection: ClockScale
    let scalePosition: Double
    let isActive: Bool
    let availableHeight: CGFloat
    let refreshedAt: Date
    let onRefresh: (Date) -> Void
    let onMarkerTap: (UUID) -> Void
    @State private var now = Date.now

    var body: some View {
        let context = contexts[Int(selection.position)]
        let snapshot = TimePhaseSnapshot(scale: selection, interval: context.clock.interval, at: now)
        let zoom = reduceMotion ? PhaseZoom.level(for: selection) : PhaseZoom.level(at: scalePosition)
        TimeWeaveInstrument(contexts: contexts, snapshot: snapshot, zoom: zoom,
                            availableHeight: availableHeight, onMarkerTap: onMarkerTap)
        .padding(.horizontal, 4).padding(.vertical, selection == .life ? 16 : 24)
        .frame(minHeight: availableHeight, alignment: .center)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(selection == .life ? "clock.life" : "timefield.\(selection.rawValue)")
        #if DEBUG
        .overlay(alignment: .topLeading) {
            if AppLaunchOptions.isTesting {
                Text(isActive ? "active" : "paused")
                    .font(.system(size: 1)).opacity(0.001)
                    .frame(width: 1, height: 1).allowsHitTesting(false)
                    .accessibilityIdentifier("life.refresh")
                    .accessibilityValue(isActive ? "active" : "paused")
            }
        }
        #endif
        .task(id: isActive) {
            guard isActive else { return }
            sample()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(100)) } catch { break }
                guard !Task.isCancelled else { break }
                sample()
            }
        }
    }

    private func sample() {
        let date = Date.now
        now = date
        let day = contexts[Int(ClockScale.day.position)].clock.interval
        if date >= day.end || date < day.start || date.timeIntervalSince(refreshedAt) >= 60 || date < refreshedAt {
            onRefresh(date)
        }
    }
}
