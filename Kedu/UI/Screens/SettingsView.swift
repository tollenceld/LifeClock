import SwiftData
import SwiftUI

private enum SettingsSheet: String, Identifiable {
    case birthday
    case targetAge
    case eventLibrary

    var id: String { rawValue }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @AppStorage("appearance") private var appearance: AppAppearance = .system
    @Bindable var profile: UserProfile

    @State private var presentedSheet: SettingsSheet?
    @State private var notice: String?

    private var currentAge: Int {
        max(0, Calendar.current.dateComponents([.year], from: profile.birthDate, to: .now).year ?? 0)
    }

    private var hapticsBinding: Binding<Bool> {
        Binding(
            get: { profile.hapticsEnabled },
            set: { updateHaptics($0) }
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            theme.background(for: colorScheme).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    KeduSheetHeader(
                        title: "设置",
                        subtitle: "校准属于你的时间仪器",
                        closeIdentifier: "settings.close"
                    ) {
                        dismiss()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("人生刻度")

                        LifeCalibrationOverview(
                            birthDate: profile.birthDate,
                            currentAge: currentAge,
                            targetAge: profile.targetAge
                        )

                        KeduGlassGroup(spacing: 10) {
                            VStack(spacing: 0) {
                                KeduCalibrationField(
                                    title: "生日",
                                    value: profile.birthDate.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).locale(Locale(identifier: "zh_Hans_CN"))),
                                    helper: "修改后将重新计算人生刻度",
                                    systemImage: "calendar"
                                ) {
                                    presentedSheet = .birthday
                                }
                                .accessibilityIdentifier("settings.birthday")

                                divider

                                KeduCalibrationField(
                                    title: "预期年龄",
                                    value: "\(profile.targetAge) 岁",
                                    helper: "范围为当前年龄之后至 150 岁",
                                    systemImage: "ruler"
                                ) {
                                    presentedSheet = .targetAge
                                }
                                .accessibilityIdentifier("settings.targetAge")
                            }
                            .padding(.horizontal, 4)
                            .background(theme.elevatedSurface(for: colorScheme).opacity(0.22), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("刻点")

                        KeduGlassSurface(role: .standard, cornerRadius: 24) {
                            KeduCalibrationField(
                                title: "刻点集",
                                value: "查看全部",
                                helper: "寻找、添加和整理值得记住的时刻",
                                systemImage: "circle.grid.2x2"
                            ) {
                                presentedSheet = .eventLibrary
                            }
                            .accessibilityIdentifier("events.library")
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        sectionTitle("外观")
                        HStack(spacing: 10) {
                            ForEach(AppAppearance.allCases) { option in
                                Button { appearance = option } label: {
                                    VStack(spacing: 10) {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(option == .light ? Color(red: 0.96, green: 0.94, blue: 0.89) : Color(red: 0.08, green: 0.09, blue: 0.08))
                                            .overlay {
                                                HStack(spacing: 4) {
                                                    ForEach(0..<5) { index in
                                                        Capsule().fill(index == 3 ? theme.accent : (option == .light ? Color.black.opacity(0.6) : Color.white.opacity(0.7)))
                                                            .frame(width: 3, height: index == 2 ? 25 : 15)
                                                    }
                                                }
                                            }
                                            .frame(height: 52)
                                        Text(option.title).font(.system(size: 12, weight: .medium))
                                    }
                                    .padding(10).frame(maxWidth: .infinity)
                                    .background(theme.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 18))
                                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(appearance == option ? theme.accent : .clear, lineWidth: 1))
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("appearance.\(option.rawValue)")
                                .accessibilityAddTraits(appearance == option ? .isSelected : [])
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("触感")

                        Toggle(isOn: hapticsBinding) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("轻触反馈")
                                    .font(.system(size: 15, weight: .medium))
                                Text("拖动刻度、切换与保存时提供克制反馈")
                                    .font(.system(size: 10))
                                    .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                            }
                        }
                        .toggleStyle(KeduPrecisionToggleStyle())
                        .padding(16)
                        .background(theme.elevatedSurface(for: colorScheme).opacity(0.22), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .accessibilityIdentifier("settings.haptics")
                    }

                    HStack(alignment: .firstTextBaseline) {
                        Label("数据仅保存在本机", systemImage: "checkmark.shield")
                        Spacer()
                        Text("版本 1.0")
                    }
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }
            .scrollIndicators(.hidden)

            if let notice {
                KeduNoticeBanner(message: notice)
                    .padding(.horizontal, 20)
                    .padding(.top, 78)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityIdentifier("settings.notice")
            }
        }
        .sheet(item: $presentedSheet) { destination in
            switch destination {
            case .birthday:
                BirthdayCalibrationSheet(initialDate: profile.birthDate) { value in
                    updateBirthday(value)
                }
            case .targetAge:
                AgeCalibrationSheet(
                    initialAge: profile.targetAge,
                    minimumAge: currentAge + 1
                ) { value in
                    updateTargetAge(value)
                }
            case .eventLibrary:
                EventLibraryView(profile: profile)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: notice)
    }

    private var divider: some View {
        Rectangle()
            .fill(theme.subtleStroke(for: colorScheme))
            .frame(height: 0.5)
            .padding(.leading, 72)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(theme.navigationLabel(for: colorScheme))
    }

    private func updateBirthday(_ value: Date) {
        let oldBirthday = profile.birthDate
        let oldTargetAge = profile.targetAge
        profile.birthDate = Calendar.current.startOfDay(for: min(.now, value))
        profile.targetAge = min(150, max(profile.targetAge, currentAge + 1))
        persist {
            profile.birthDate = oldBirthday
            profile.targetAge = oldTargetAge
        }
    }

    private func updateTargetAge(_ value: Int) {
        let oldValue = profile.targetAge
        profile.targetAge = min(150, max(currentAge + 1, value))
        persist { profile.targetAge = oldValue }
    }

    private func updateHaptics(_ enabled: Bool) {
        let oldValue = profile.hapticsEnabled
        profile.hapticsEnabled = enabled
        persist { profile.hapticsEnabled = oldValue }
    }

    private func persist(revert: () -> Void) {
        do {
            try modelContext.save()
            notice = nil
            HapticManager.shared.saved(enabled: profile.hapticsEnabled)
        } catch {
            revert()
            notice = "设置未能保存，请再试一次。"
        }
    }
}

private struct LifeCalibrationOverview: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let birthDate: Date
    let currentAge: Int
    let targetAge: Int

    private var progress: Double { min(1, max(0, Double(currentAge) / Double(max(1, targetAge)))) }

    var body: some View {
        KeduGlassSurface(role: .standard, cornerRadius: AppTheme.Radius.hero) {
            VStack(spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("生日")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                        Text(birthDate.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).locale(Locale(identifier: "zh_Hans_CN"))))
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("预期年龄")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                        Text("\(targetAge) 岁")
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .monospacedDigit()
                    }
                }

                KeduTickRail(progress: progress, divisions: 45)

                HStack {
                    Text("当前 \(currentAge) 岁")
                    Spacer()
                    Text(progress.formatted(.percent.precision(.fractionLength(1))))
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.secondaryLabel(for: colorScheme))
            }
            .padding(18)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("人生刻度")
        .accessibilityValue("当前 \(currentAge) 岁，预期年龄 \(targetAge) 岁")
    }
}

private struct BirthdayCalibrationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @State private var date: Date
    let commit: (Date) -> Void

    init(initialDate: Date, commit: @escaping (Date) -> Void) {
        _date = State(initialValue: initialDate)
        self.commit = commit
    }

    var body: some View {
        ZStack {
            theme.background(for: colorScheme).ignoresSafeArea()

            VStack(spacing: 20) {
                KeduSheetHeader(title: "校准生日", subtitle: "选择你来到这里的那一天") {
                    dismiss()
                }

                KeduGlassSurface(role: .standard) {
                    DatePicker(
                        "生日",
                        selection: $date,
                        in: (Calendar.current.date(byAdding: .year, value: -150, to: .now) ?? .distantPast)...Date.now,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .tint(theme.accent)
                    .padding(.horizontal, 8)
                }

                Spacer()

                KeduActionButton(title: "应用生日", systemImage: "checkmark") {
                    commit(date)
                    dismiss()
                }
                .accessibilityIdentifier("settings.birthday.apply")
            }
            .padding(20)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }
}

private struct AgeCalibrationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @State private var age: Int
    @State private var dragStartAge: Int?
    let minimumAge: Int
    let commit: (Int) -> Void

    init(initialAge: Int, minimumAge: Int, commit: @escaping (Int) -> Void) {
        _age = State(initialValue: initialAge)
        self.minimumAge = minimumAge
        self.commit = commit
    }

    var body: some View {
        ZStack {
            theme.background(for: colorScheme).ignoresSafeArea()

            VStack(spacing: 24) {
                KeduSheetHeader(title: "校准预期年龄", subtitle: "这不是预测，只是一把属于你的尺") {
                    dismiss()
                }

                KeduGlassSurface(role: .standard, cornerRadius: AppTheme.Radius.hero) {
                    VStack(spacing: 24) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(age)")
                                .font(.system(size: 76, weight: .light, design: .monospaced))
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            Text("岁")
                                .font(.system(size: 15, design: .monospaced))
                                .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                        }

                        HStack(spacing: 12) {
                            ageButton("minus", delta: -1)
                            KeduTickRail(progress: normalizedAge, divisions: 41)
                                .contentShape(Rectangle())
                                .gesture(ageDrag)
                            ageButton("plus", delta: 1)
                        }

                        Text("左右拖动刻度，或使用两侧按钮微调")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                    }
                    .padding(22)
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("预期年龄")
                .accessibilityValue("\(age) 岁")
                .accessibilityAdjustableAction { direction in
                    adjust(direction == .increment ? 1 : -1)
                }

                Spacer()

                KeduActionButton(title: "应用年龄", systemImage: "checkmark") {
                    commit(age)
                    dismiss()
                }
                .accessibilityIdentifier("settings.age.apply")
            }
            .padding(20)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    private var normalizedAge: Double {
        Double(age - minimumAge) / Double(max(1, 150 - minimumAge))
    }

    private var ageDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragStartAge == nil { dragStartAge = age }
                guard let dragStartAge else { return }
                let delta = Int((value.translation.width / 5).rounded())
                let next = min(150, max(minimumAge, dragStartAge + delta))
                if next != age {
                    age = next
                    HapticManager.shared.selectionChanged(enabled: true)
                }
            }
            .onEnded { _ in dragStartAge = nil }
    }

    private func ageButton(_ symbol: String, delta: Int) -> some View {
        Button { adjust(delta) } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.accentInk(for: colorScheme))
                .frame(width: 48, height: 48)
                .background(theme.fieldFill(for: colorScheme), in: Circle())
                .overlay(Circle().stroke(theme.subtleStroke(for: colorScheme), lineWidth: 0.6))
        }
        .buttonStyle(.plain)
        .buttonRepeatBehavior(.enabled)
    }

    private func adjust(_ delta: Int) {
        let next = min(150, max(minimumAge, age + delta))
        guard next != age else { return }
        age = next
        HapticManager.shared.selectionChanged(enabled: true)
    }
}

#Preview("设置 · 深色") {
    SettingsView(profile: PreviewSupport.profile())
        .environment(AppTheme())
        .modelContainer(PreviewSupport.container(.single))
        .preferredColorScheme(.dark)
}
