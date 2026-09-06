import UIKit

@MainActor
final class HapticManager {
    static let shared = HapticManager()

    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()

    private init() {
        selection.prepare()
    }

    func selectionChanged(enabled: Bool) {
        guard enabled else { return }
        selection.selectionChanged()
        selection.prepare()
    }

    func saved(enabled: Bool) {
        guard enabled else { return }
        notification.notificationOccurred(.success)
    }
}

