import SwiftUI

@MainActor
@Observable
final class AppTheme {
    let accent = Color(red: 1.0, green: 0.61, blue: 0.02)
    let danger = Color(red: 0.94, green: 0.29, blue: 0.25)

    enum Spacing {
        static let xSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        static let large: CGFloat = 24
        static let xLarge: CGFloat = 32
    }

    enum Radius {
        static let control: CGFloat = 18
        static let panel: CGFloat = 26
        static let hero: CGFloat = 32
    }

    func accentInk(for scheme: ColorScheme) -> Color {
        scheme == .dark ? accent : Color(red: 0.62, green: 0.33, blue: 0.01)
    }

    func background(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.047, green: 0.051, blue: 0.050)
            : Color(red: 0.965, green: 0.956, blue: 0.935)
    }

    func surface(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.078, green: 0.086, blue: 0.083)
            : Color(red: 0.985, green: 0.978, blue: 0.958)
    }

    func elevatedSurface(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.12, green: 0.12, blue: 0.135)
            : Color.white.opacity(0.74)
    }

    func fieldFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.34) : Color.black.opacity(0.045)
    }

    func subtleStroke(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.11) : Color.black.opacity(0.09)
    }

    func opticalHighlight(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.24) : Color.white.opacity(0.88)
    }

    func disabledFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.055)
    }

    func completedDot(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.85, green: 0.87, blue: 0.81) : Color.black.opacity(0.74)
    }

    func futureDot(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.13) : Color.black.opacity(0.12)
    }

    func secondaryLabel(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.60) : Color.black.opacity(0.59)
    }

    func navigationLabel(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.72) : Color.black.opacity(0.68)
    }

    func navigationSelectionFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.09) : Color.black.opacity(0.065)
    }

    func navigationSelectionStroke(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.10)
    }

    func tertiaryLabel(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.40) : Color.black.opacity(0.44)
    }

    func glassStroke(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.17) : Color.white.opacity(0.72)
    }

    func glassFallback(for scheme: ColorScheme) -> Material {
        scheme == .dark ? .ultraThinMaterial : .thinMaterial
    }
}

extension EventColor {
    var color: Color {
        switch self {
        case .amber: Color(red: 1.0, green: 0.62, blue: 0.04)
        case .jade: Color(red: 0.24, green: 0.67, blue: 0.58)
        case .cobalt: Color(red: 0.28, green: 0.48, blue: 0.86)
        case .coral: Color(red: 0.90, green: 0.40, blue: 0.33)
        case .violet: Color(red: 0.57, green: 0.40, blue: 0.78)
        }
    }
}


enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: "跟随系统"
        case .light: "暖纸"
        case .dark: "石墨"
        }
    }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

// Keep the system preference authoritative; the override only lets UI tests exercise the same branch.
extension EnvironmentValues {
    @Entry var keduReduceMotionOverride = false

    var keduReduceMotion: Bool {
        accessibilityReduceMotion || keduReduceMotionOverride
    }
}
