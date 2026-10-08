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
        .environment(\.calendar, CivilBirthday.calendar)
        #if DEBUG
        .environment(\.keduReduceMotionOverride, AppLaunchOptions.contains("-uiTestingReduceMotion"))
        .environment(\.keduReduceTransparencyOverride, AppLaunchOptions.contains("-uiTestingReduceTransparency"))
        #endif
        .preferredColorScheme(appearance.colorScheme)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: profiles.first?.onboardingCompleted)
    }
}
