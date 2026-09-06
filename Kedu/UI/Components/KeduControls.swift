import SwiftUI

enum KeduGlassRole {
    case standard
    case interactive
    case emphasized
}

struct KeduGlassGroup<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    init(spacing: CGFloat = 12, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                content()
            }
        } else {
            content()
        }
    }
}

struct KeduGlassSurface<Content: View>: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let role: KeduGlassRole
    let cornerRadius: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        role: KeduGlassRole = .standard,
        cornerRadius: CGFloat = AppTheme.Radius.panel,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.role = role
        self.cornerRadius = cornerRadius
        self.content = content
    }

    var body: some View {
        if #available(iOS 26.0, *) {
            switch role {
            case .standard:
                content()
                    .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
            case .interactive:
                content()
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
            case .emphasized:
                content()
                    .glassEffect(
                        .regular.tint(theme.accent.opacity(0.11)).interactive(),
                        in: .rect(cornerRadius: cornerRadius)
                    )
            }
        } else {
            content()
                .background(theme.glassFallback(for: colorScheme), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(theme.glassStroke(for: colorScheme), lineWidth: 0.65)
                }
        }
    }
}

struct KeduSheetHeader: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    var subtitle: String?
    var closeIdentifier: String = "sheet.close"
    let closeAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 32, weight: .semibold))
                    .tracking(-0.8)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 16)

            closeButton
        }
        .frame(minHeight: 56)
    }

    @ViewBuilder
    private var closeButton: some View {
        if #available(iOS 26.0, *) {
            Button(action: closeAction) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .tint(theme.accent.opacity(0.12))
            .accessibilityLabel("关闭")
            .accessibilityIdentifier(closeIdentifier)
        } else {
            Button(action: closeAction) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(theme.glassFallback(for: colorScheme), in: Circle())
                    .overlay(Circle().stroke(theme.glassStroke(for: colorScheme), lineWidth: 0.65))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("关闭")
            .accessibilityIdentifier(closeIdentifier)
        }
    }
}

enum KeduActionRole {
    case primary
    case secondary
    case destructive
}

struct KeduActionButton: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    var systemImage: String?
    var role: KeduActionRole = .primary
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                switch role {
                case .primary:
                    button
                        .buttonStyle(.glassProminent)
                        .tint(theme.accent)
                case .secondary:
                    button
                        .buttonStyle(.glass)
                case .destructive:
                    button
                        .buttonStyle(.glass)
                        .tint(theme.danger.opacity(0.22))
                        .foregroundStyle(theme.danger)
                }
            } else {
                button
                    .buttonStyle(KeduFallbackActionStyle(role: role))
            }
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.46 : 1)
    }

    private var button: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.system(size: 16, weight: .semibold))
            .frame(maxWidth: .infinity, minHeight: 54)
            .contentShape(Rectangle())
        }
    }
}

private struct KeduFallbackActionStyle: ButtonStyle {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let role: KeduActionRole

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .background(fill.opacity(configuration.isPressed ? 0.72 : 1), in: RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppTheme.Radius.control, style: .continuous)
                    .stroke(theme.glassStroke(for: colorScheme), lineWidth: role == .primary ? 0 : 0.65)
            }
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch role {
        case .primary: .black
        case .secondary: .primary
        case .destructive: theme.danger
        }
    }

    private var fill: AnyShapeStyle {
        switch role {
        case .primary: AnyShapeStyle(theme.accent)
        case .secondary, .destructive: AnyShapeStyle(theme.glassFallback(for: colorScheme))
        }
    }
}

struct KeduSegmentedRail<Option: Hashable, Label: View>: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> Label
    var accessibilityLabel: (Option) -> String = { String(describing: $0) }

    @Namespace private var selectionNamespace

    var body: some View {
        KeduGlassSurface(role: .interactive, cornerRadius: AppTheme.Radius.control) {
            HStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    Button {
                        guard option != selection else { return }
                        if reduceMotion {
                            selection = option
                        } else {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) {
                                selection = option
                            }
                        }
                    } label: {
                        ZStack {
                            if option == selection {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(theme.accent.opacity(colorScheme == .dark ? 0.23 : 0.16))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(theme.accent.opacity(0.44), lineWidth: 0.7)
                                    }
                                    .matchedGeometryEffect(id: "selection", in: selectionNamespace)
                            }

                            label(option)
                                .font(.system(size: 13, weight: option == selection ? .semibold : .medium))
                                .foregroundStyle(option == selection ? theme.accent : theme.navigationLabel(for: colorScheme))
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(accessibilityLabel(option))
                    .accessibilityAddTraits(option == selection ? .isSelected : [])
                }
            }
            .padding(4)
        }
    }
}

struct KeduPrecisionToggleStyle: ToggleStyle {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        Button {
            if reduceMotion {
                configuration.isOn.toggle()
            } else {
                withAnimation(.spring(response: 0.34, dampingFraction: 0.78)) {
                    configuration.isOn.toggle()
                }
            }
        } label: {
            HStack(spacing: 14) {
                configuration.label
                    .frame(maxWidth: .infinity, alignment: .leading)

                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(configuration.isOn ? theme.accent.opacity(0.88) : theme.fieldFill(for: colorScheme))
                        .overlay {
                            Capsule().stroke(
                                configuration.isOn ? theme.accent.opacity(0.65) : theme.subtleStroke(for: colorScheme),
                                lineWidth: 0.7
                            )
                        }

                    Circle()
                        .fill(configuration.isOn ? Color.black.opacity(0.82) : theme.navigationLabel(for: colorScheme))
                        .padding(4)
                        .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                }
                .frame(width: 58, height: 32)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "已开启" : "已关闭")
    }
}

struct KeduCalibrationField: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let value: String
    var helper: String?
    var systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(theme.accent)
                    .frame(width: 44, height: 44)
                    .background(theme.fieldFill(for: colorScheme), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                    Text(value)
                        .font(.system(size: 17, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    if let helper {
                        Text(helper)
                            .font(.system(size: 10))
                            .foregroundStyle(theme.tertiaryLabel(for: colorScheme))
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(theme.tertiaryLabel(for: colorScheme))
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 72)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct KeduTickRail: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let progress: Double
    var divisions = 31

    var body: some View {
        Canvas { context, size in
            let clamped = min(1, max(0, progress))
            let active = Int((Double(divisions - 1) * clamped).rounded())
            let spacing = size.width / CGFloat(max(1, divisions - 1))

            for index in 0..<divisions {
                let x = CGFloat(index) * spacing
                let isMajor = index.isMultiple(of: 5)
                let height: CGFloat = index == active ? size.height : (isMajor ? size.height * 0.62 : size.height * 0.34)
                let color = index == active ? theme.accent : theme.secondaryLabel(for: colorScheme).opacity(0.58)
                let rect = CGRect(x: x - 0.75, y: (size.height - height) / 2, width: 1.5, height: height)
                context.fill(Path(roundedRect: rect, cornerRadius: 0.75), with: .color(color))
            }
        }
        .frame(height: 28)
        .accessibilityHidden(true)
    }
}

struct KeduNoticeBanner: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let message: String
    var isError = true

    var body: some View {
        KeduGlassSurface(role: .interactive, cornerRadius: 16) {
            HStack(spacing: 10) {
                Image(systemName: isError ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(isError ? theme.danger : theme.accent)
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 48)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
    }
}

struct KeduConfirmationSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let message: String
    let confirmTitle: String
    let confirmAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            KeduSheetHeader(title: title, subtitle: message) {
                dismiss()
            }

            Spacer(minLength: 0)

            KeduActionButton(title: confirmTitle, systemImage: "trash", role: .destructive) {
                confirmAction()
            }
            .accessibilityIdentifier("confirmation.destructive")

            KeduActionButton(title: "取消", role: .secondary) {
                dismiss()
            }
        }
        .padding(20)
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.hidden)
    }
}
