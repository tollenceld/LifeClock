import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var birthDate = Calendar.current.date(
        from: DateComponents(year: 2000, month: 1, day: 1)
    ) ?? .now
    @State private var targetAge = 85

    private var currentAge: Int {
        max(0, Calendar.current.dateComponents([.year], from: birthDate, to: .now).year ?? 0)
    }

    var body: some View {
        ZStack {
            theme.background(for: colorScheme).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("刻度")
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                        Spacer()
                        Text("仅需一次设置")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(theme.tertiaryLabel(for: colorScheme))
                    }
                    .frame(height: 44)

                    Text("设定你的刻度")
                        .font(.system(size: 34, weight: .medium))
                        .tracking(-0.9)
                        .padding(.top, 24)

                    Text("标记起点，再放下一条可以随时修改的远线。")
                        .font(.system(size: 15))
                        .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                        .padding(.top, 8)

                    LifeSetupInstrument(
                        birthDate: $birthDate,
                        targetAge: $targetAge,
                        currentAge: currentAge
                    )
                    .padding(.top, 28)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 124)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text("生日与人生刻度只保存在这台设备上。")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(theme.secondaryLabel(for: colorScheme))

                KeduActionButton(title: "进入刻度", systemImage: "arrow.right") {
                    completeOnboarding()
                }
                .accessibilityIdentifier("onboarding.finish")
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(theme.background(for: colorScheme).opacity(0.96))
        }
        .onChange(of: birthDate) { _, _ in
            targetAge = min(150, max(targetAge, currentAge + 1))
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: currentAge)
    }

    private func completeOnboarding() {
        let normalizedBirthDate = Calendar.current.startOfDay(for: min(.now, birthDate))
        let normalizedAge = min(150, max(currentAge + 1, targetAge))
        let profile = UserProfile(birthDate: normalizedBirthDate, targetAge: normalizedAge)
        modelContext.insert(profile)

        do {
            try modelContext.save()
            HapticManager.shared.saved(enabled: true)
        } catch {
            modelContext.delete(profile)
        }
    }
}

private struct LifeSetupInstrument: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @Binding var birthDate: Date
    @Binding var targetAge: Int
    let currentAge: Int

    private var calendar: Calendar { .autoupdatingCurrent }
    private var progress: Double { min(1, max(0, Double(currentAge) / Double(max(1, targetAge)))) }

    var body: some View {
        KeduGlassSurface(role: .standard, cornerRadius: AppTheme.Radius.hero) {
            VStack(spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text("人生刻度")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text("\(currentAge) / \(targetAge)")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                        .monospacedDigit()
                }

                HStack(alignment: .center, spacing: 12) {
                    valueSummary(
                        title: "生日",
                        value: birthDate.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).locale(Locale(identifier: "zh_Hans_CN")))
                    )

                    Circle()
                        .fill(theme.accent)
                        .frame(width: 7, height: 7)
                        .overlay(Circle().stroke(theme.accent.opacity(0.25), lineWidth: 7))
                        .accessibilityHidden(true)

                    valueSummary(title: "预期年龄", value: "\(targetAge) 岁", trailing: true)
                }

                KeduTickRail(progress: progress, divisions: 43)

                Rectangle()
                    .fill(theme.subtleStroke(for: colorScheme))
                    .frame(height: 0.5)

                VStack(alignment: .leading, spacing: 10) {
                    Text("调整生日")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(theme.secondaryLabel(for: colorScheme))

                    HStack(spacing: 8) {
                        DateCalibrationColumn(
                            label: "年",
                            value: calendar.component(.year, from: birthDate),
                            decrement: { adjustDate(.year, by: -1) },
                            increment: { adjustDate(.year, by: 1) }
                        )
                        DateCalibrationColumn(
                            label: "月",
                            value: calendar.component(.month, from: birthDate),
                            decrement: { adjustDate(.month, by: -1) },
                            increment: { adjustDate(.month, by: 1) }
                        )
                        DateCalibrationColumn(
                            label: "日",
                            value: calendar.component(.day, from: birthDate),
                            decrement: { adjustDate(.day, by: -1) },
                            increment: { adjustDate(.day, by: 1) }
                        )
                    }
                }
                .accessibilityIdentifier("onboarding.birthDate")

                Rectangle()
                    .fill(theme.subtleStroke(for: colorScheme))
                    .frame(height: 0.5)

                AgeCalibrationControl(
                    targetAge: $targetAge,
                    minimumAge: max(currentAge + 1, 1)
                )
                .accessibilityIdentifier("onboarding.targetAge")
            }
            .padding(18)
        }
    }

    private func valueSummary(title: String, value: String, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.secondaryLabel(for: colorScheme))
            Text(value)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: trailing ? .trailing : .leading)
    }

    private func adjustDate(_ component: Calendar.Component, by value: Int) {
        guard let candidate = calendar.date(byAdding: component, value: value, to: birthDate) else { return }
        let earliest = calendar.date(byAdding: .year, value: -150, to: .now) ?? .distantPast
        let clamped = min(.now, max(earliest, candidate))
        guard clamped != birthDate else { return }
        birthDate = clamped
        HapticManager.shared.selectionChanged(enabled: true)
    }
}

private struct DateCalibrationColumn: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let label: String
    let value: Int
    let decrement: () -> Void
    let increment: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            adjustmentButton("chevron.up", action: increment)

            Text(value.formatted(.number.grouping(.never)))
                .font(.system(size: 24, weight: .regular, design: .monospaced))
                .monospacedDigit()
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity, minHeight: 38)

            Text(label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(theme.secondaryLabel(for: colorScheme))

            adjustmentButton("chevron.down", action: decrement)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(theme.fieldFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.subtleStroke(for: colorScheme), lineWidth: 0.55)
        }
    }

    private func adjustmentButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(theme.accent)
                .frame(maxWidth: .infinity, minHeight: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(systemName == "chevron.up" ? "增加\(label)" : "减少\(label)")
    }
}

private struct AgeCalibrationControl: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @Binding var targetAge: Int
    let minimumAge: Int
    @State private var dragStartAge: Int?

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text("调整预期年龄")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                Spacer()
                Text("\(targetAge) 岁")
                    .font(.system(size: 18, weight: .medium, design: .monospaced))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            HStack(spacing: 12) {
                ageButton("minus", delta: -1)

                KeduTickRail(progress: normalizedAge, divisions: 35)
                    .contentShape(Rectangle())
                    .gesture(ageDrag)

                ageButton("plus", delta: 1)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("预期年龄")
        .accessibilityValue("\(targetAge) 岁")
        .accessibilityAdjustableAction { direction in
            adjust(direction == .increment ? 1 : -1)
        }
    }

    private var normalizedAge: Double {
        Double(targetAge - minimumAge) / Double(max(1, 150 - minimumAge))
    }

    private var ageDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStartAge == nil { dragStartAge = targetAge }
                guard let dragStartAge else { return }
                let delta = Int((value.translation.width / 5).rounded())
                let next = min(150, max(minimumAge, dragStartAge + delta))
                if next != targetAge {
                    targetAge = next
                    HapticManager.shared.selectionChanged(enabled: true)
                }
            }
            .onEnded { _ in dragStartAge = nil }
    }

    private func ageButton(_ systemName: String, delta: Int) -> some View {
        Button { adjust(delta) } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.accent)
                .frame(width: 44, height: 44)
                .background(theme.fieldFill(for: colorScheme), in: Circle())
                .overlay(Circle().stroke(theme.subtleStroke(for: colorScheme), lineWidth: 0.6))
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(delta > 0 ? "增加预期年龄" : "减少预期年龄")
    }

    private func adjust(_ delta: Int) {
        let next = min(150, max(minimumAge, targetAge + delta))
        guard next != targetAge else { return }
        targetAge = next
        HapticManager.shared.selectionChanged(enabled: true)
    }
}

#Preview("单屏引导 · 深色") {
    OnboardingView()
        .environment(AppTheme())
        .modelContainer(PreviewSupport.container(.empty))
        .preferredColorScheme(.dark)
}

#Preview("单屏引导 · 浅色") {
    OnboardingView()
        .environment(AppTheme())
        .modelContainer(PreviewSupport.container(.empty))
        .preferredColorScheme(.light)
}
