import SwiftData
import SwiftUI

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.keduReduceMotion) private var reduceMotion

    @State private var birthDate = CivilBirthday.calendar.date(
        from: DateComponents(year: 2000, month: 1, day: 1)
    ) ?? .now
    @State private var targetAge = 85
    @State private var saveError = false
    @State private var completed = false

    private var currentAge: Int {
        Int(LifeClockSnapshot(at: .now, calendar: Calendar(identifier: .gregorian), birthDate: birthDate, targetAge: targetAge).age)
    }

    var body: some View {
        ZStack {
            theme.background(for: colorScheme).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("刻度")
                            .font(.callout.monospaced().weight(.medium))
                            .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                        Spacer()
                        Text("仅需一次设置")
                            .font(.caption2.monospaced().weight(.medium))
                            .foregroundStyle(theme.tertiaryLabel(for: colorScheme))
                    }
                    .frame(minHeight: 44)

                    Text("时间有形，\n生活有刻度。")
                        .font(.largeTitle.weight(.light))
                        .tracking(-0.9)
                        .padding(.top, 24)

                    Text("从你的生日开始，看见此刻在人生中的位置。")
                        .font(.subheadline)
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
                    .font(.caption2.monospaced())
                    .foregroundStyle(theme.secondaryLabel(for: colorScheme))

                KeduActionButton(title: "进入刻度", systemImage: "arrow.right", isDisabled: completed) {
                    completeOnboarding()
                }
                .accessibilityIdentifier("onboarding.finish")
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(theme.background(for: colorScheme).opacity(0.96))
        }
        .alert("暂时无法保存", isPresented: $saveError) {
            Button("好", role: .cancel) { }
        } message: {
            Text("你的设置仍在这里，请再试一次。")
        }
        .onChange(of: birthDate) { _, _ in
            targetAge = min(150, max(targetAge, currentAge + 1))
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: currentAge)
    }

    private func completeOnboarding() {
        guard !completed else { return }
        completed = true
        let normalizedBirthDate = CivilBirthday.calendar.startOfDay(for: min(.now, birthDate))
        let normalizedAge = min(150, max(currentAge + 1, targetAge))
        let profile = UserProfile(birthDate: normalizedBirthDate, targetAge: normalizedAge)
        profile.setBirthday(normalizedBirthDate, calendar: CivilBirthday.calendar)
        modelContext.insert(profile)

        do {
            try modelContext.save()
            HapticManager.shared.saved(enabled: true)
        } catch {
            modelContext.rollback()
            completed = false
            saveError = true
        }
    }
}

private struct LifeSetupInstrument: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @Binding var birthDate: Date
    @Binding var targetAge: Int
    let currentAge: Int

    private var calendar: Calendar { CivilBirthday.calendar }
    private var setupWeave: some View {
        let profile = UserProfile(birthDate: birthDate, targetAge: targetAge)
        let date = Date.now
        let contexts = ClockScale.allCases.map {
            TimePhaseContext.make(scale: $0, at: date, calendar: calendar, profile: profile, events: [])
        }
        let life = contexts[Int(ClockScale.life.position)]
        return TimeWeaveField(contexts: contexts,
                              snapshot: TimePhaseSnapshot(scale: .life, interval: life.clock.interval, at: date),
                              zoom: PhaseZoom.level(for: .life), showsMinute: false)
    }

    var body: some View {
        KeduGlassSurface(role: .standard, cornerRadius: AppTheme.Radius.hero) {
            VStack(spacing: 18) {
                HStack(alignment: .firstTextBaseline) {
                    Text("人生刻度")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(currentAge) / \(targetAge)")
                        .font(.caption.monospaced().weight(.medium))
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

                    valueSummary(title: "预计寿命", value: "\(targetAge) 岁", trailing: true)
                }

                setupWeave
                    .frame(height: 110)
                    .accessibilityHidden(true)

                Rectangle()
                    .fill(theme.subtleStroke(for: colorScheme))
                    .frame(height: 0.5)

                VStack(alignment: .leading, spacing: 10) {
                    DatePicker("你的生日", selection: $birthDate,
                               in: CivilBirthday.allowedRange(calendar: calendar),
                               displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .tint(theme.accent)
                        .font(.subheadline)
                        .frame(minHeight: 48)
                        .accessibilityIdentifier("onboarding.birthDate")
                    Text("只用于计算时间，始终留在你的设备上。")
                        .font(.caption).foregroundStyle(theme.secondaryLabel(for: colorScheme))
                }

                Rectangle()
                    .fill(theme.subtleStroke(for: colorScheme))
                    .frame(height: 0.5)

                AgeCalibrationControl(
                    targetAge: $targetAge,
                    minimumAge: min(150, max(currentAge + 1, 1))
                )
                .accessibilityIdentifier("onboarding.targetAge")

                Text("死之终依据你设定的预计寿命计算，并非死亡预测。")
                    .font(.caption).foregroundStyle(theme.secondaryLabel(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
        }
    }

    private func valueSummary(title: String, value: String, trailing: Bool = false) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(theme.secondaryLabel(for: colorScheme))
            Text(value)
                .font(.callout.monospaced().weight(.medium))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity, alignment: trailing ? .trailing : .leading)
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
                Text("调整预计寿命")
                    .font(.caption2.monospaced().weight(.medium))
                    .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                Spacer()
                Text("\(targetAge) 岁")
                    .font(.title3.monospaced().weight(.medium))
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
        .accessibilityLabel("预计寿命")
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.accentInk(for: colorScheme))
                .frame(width: 44, height: 44)
                .background(theme.fieldFill(for: colorScheme), in: Circle())
                .overlay(Circle().stroke(theme.subtleStroke(for: colorScheme), lineWidth: 0.6))
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(delta > 0 ? "增加预计寿命" : "减少预计寿命")
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
