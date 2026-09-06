import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var birthDate: Date
    var targetAge: Int
    var weekStartsOnMonday: Bool
    var onboardingCompleted: Bool
    var hapticsEnabled: Bool

    init(
        id: UUID = UUID(),
        birthDate: Date,
        targetAge: Int = 85,
        weekStartsOnMonday: Bool = true,
        onboardingCompleted: Bool = true,
        hapticsEnabled: Bool = true
    ) {
        self.id = id
        self.birthDate = birthDate
        self.targetAge = targetAge
        self.weekStartsOnMonday = weekStartsOnMonday
        self.onboardingCompleted = onboardingCompleted
        self.hapticsEnabled = hapticsEnabled
    }
}

