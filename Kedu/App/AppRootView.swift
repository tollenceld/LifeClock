import SwiftData
import SwiftUI

struct AppRootView: View {
    @AppStorage("appearance") private var appearance: AppAppearance = .system
    @Environment(\.keduReduceMotion) private var reduceMotion
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
        .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
        .environment(\.keduReduceMotionOverride, CommandLine.arguments.contains("-uiTesting") && CommandLine.arguments.contains("-uiTestingReduceMotion"))
        .preferredColorScheme(appearance.colorScheme)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: profiles.first?.onboardingCompleted)
    }
}

