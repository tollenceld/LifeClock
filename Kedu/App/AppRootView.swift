import SwiftData
import SwiftUI

struct AppRootView: View {
    @Query(sort: \UserProfile.birthDate) private var profiles: [UserProfile]

    var body: some View {
        Group {
            if let profile = profiles.first, profile.onboardingCompleted {
                MainClockView(profile: profile)
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: profiles.first?.onboardingCompleted)
    }
}

