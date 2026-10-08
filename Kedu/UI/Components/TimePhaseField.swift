import SwiftUI

/// Native menus must keep stable identity while the neighbouring date is sampled.
struct PhaseMarkerControls: View, Equatable {
    let clock: ClockSnapshot
    let size: CGSize
    let onMarkerTap: (UUID) -> Void

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.size == rhs.size && lhs.clock.scale == rhs.clock.scale
        && lhs.clock.interval == rhs.clock.interval
        && lhs.clock.markers.count == rhs.clock.markers.count
        && zip(lhs.clock.markers, rhs.clock.markers).allSatisfy {
            $0.id == $1.id && $0.title == $1.title && $0.occurrence == $1.occurrence
        }
    }

    var body: some View {
        ForEach(PhaseFieldGeometry.markerGroups(clock: clock, height: size.height)) { group in
            Group {
                if let marker = group.markers.first, group.markers.count == 1 {
                    Button { onMarkerTap(marker.id) } label: { markerHitArea }
                        .accessibilityLabel(marker.title)
                        .accessibilityValue(marker.occurrence.formatted(date: .abbreviated, time: .shortened))
                        .accessibilityIdentifier("marker.\(marker.id)")
                } else {
                    Menu {
                        ForEach(group.markers) { marker in
                            Button(marker.title) { onMarkerTap(marker.id) }
                                .accessibilityIdentifier("marker.\(marker.id)")
                        }
                    } label: { markerHitArea }
                    .accessibilityLabel("\(group.markers.count) 个刻点")
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("轻点编辑刻点")
            .position(x: size.width - 22, y: PhaseFieldGeometry.boundaryY(progress: group.position, height: size.height))
        }
    }

    private var markerHitArea: some View {
        Circle().fill(Color.primary.opacity(0.3)).frame(width: 3, height: 3)
            .frame(width: 44, height: 44).contentShape(Rectangle())
    }


}
