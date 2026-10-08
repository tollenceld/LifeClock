import SwiftData
import SwiftUI

private enum SettingsSheet: String, Identifiable {
    case birthday
    case targetAge
    case eventLibrary
    case localData
    case about

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

    private var birthday: Date { profile.birthday(in: ClockEngine.calendar(for: profile)) }

    private var currentAge: Int {
        let calendar = profile.lifeCalendar(from: ClockEngine.calendar(for: profile))
        return Int(LifeClockSnapshot(at: .now, calendar: calendar, birthDate: profile.birthday(in: calendar), targetAge: profile.targetAge).age)
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
                        subtitle: "生日、预计寿命与外观",
                        closeIdentifier: "settings.close"
                    ) {
                        dismiss()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("人生刻度")

                        LifeCalibrationOverview(
                            profile: profile,
                            currentAge: currentAge
                        )

                        KeduGlassGroup(spacing: 10) {
                            VStack(spacing: 0) {
                                KeduCalibrationField(
                                    title: "生日",
                                    value: birthday.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).locale(Locale(identifier: "zh_Hans_CN"))),
                                    helper: "修改后将重新计算人生刻度",
                                    systemImage: "calendar"
                                ) {
                                    presentedSheet = .birthday
                                }
                                .accessibilityIdentifier("settings.birthday")

                                divider

                                KeduCalibrationField(
                                    title: "预计寿命",
                                    value: "\(profile.targetAge) 岁",
                                    helper: "1 至 150 岁，作为人生时间尺度",
                                    systemImage: "ruler"
                                ) {
                                    presentedSheet = .targetAge
                                }
                                .accessibilityIdentifier("settings.targetAge")
                            }
                            .padding(.horizontal, 4)
                            .background(theme.elevatedSurface(for: colorScheme).opacity(0.22), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        }
                        Text("死之终依据你设定的预计寿命计算，并非死亡预测。")
                            .font(.caption)
                            .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("settings.lifeBasis")
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
                                Button {
                                    guard appearance != option else { return }
                                    appearance = option
                                    HapticManager.shared.selectionChanged(enabled: profile.hapticsEnabled)
                                } label: {
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
                                        Text(option.title).font(.caption.weight(.medium))
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
                                    .font(.subheadline.weight(.medium))
                                Text("切换尺度与确认设置时提供轻触反馈")
                                    .font(.caption2)
                                    .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                            }
                        }
                        .toggleStyle(.switch)
                        .tint(theme.accent)
                        .padding(16)
                        .background(theme.elevatedSurface(for: colorScheme).opacity(0.22), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .accessibilityIdentifier("settings.haptics")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("数据与说明")
                        KeduGlassSurface {
                            VStack(spacing: 0) {
                                KeduCalibrationField(title: "本地数据", value: "备份与恢复", systemImage: "externaldrive") {
                                    presentedSheet = .localData
                                }.accessibilityIdentifier("settings.data")
                                divider
                                KeduCalibrationField(title: "关于刻度", value: "计算依据与隐私", systemImage: "info.circle") {
                                    presentedSheet = .about
                                }.accessibilityIdentifier("settings.about")
                            }
                        }
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Label("数据仅保存在本机", systemImage: "checkmark.shield")
                        Spacer()
                        Text(AppInformationView.version)
                    }
                    .font(.caption2.monospaced())
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
                let calendar = profile.lifeCalendar(from: ClockEngine.calendar(for: profile))
                BirthdayCalibrationSheet(initialDate: profile.birthday(in: calendar), calendar: calendar) { value in
                    updateBirthday(value, calendar: calendar)
                }
            case .targetAge:
                AgeCalibrationSheet(
                    initialAge: profile.targetAge,
                    minimumAge: 1,
                    hapticsEnabled: profile.hapticsEnabled
                ) { value in
                    updateTargetAge(value)
                }
            case .eventLibrary:
                EventLibraryView(profile: profile)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            case .localData:
                LocalDataView(profile: profile)
            case .about:
                AppInformationView()
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
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(theme.navigationLabel(for: colorScheme))
    }

    private func updateBirthday(_ value: Date, calendar: Calendar) {
        let oldBirthday = profile.birthDate
        let oldComponents = profile.birthDateComponents
        let oldTimeZone = profile.birthTimeZoneIdentifier
        profile.setBirthday(min(.now, value), calendar: calendar)
        persist {
            profile.birthDate = oldBirthday
            profile.birthDateComponents = oldComponents
            profile.birthTimeZoneIdentifier = oldTimeZone
        }
    }

    private func updateTargetAge(_ value: Int) {
        let oldValue = profile.targetAge
        profile.targetAge = min(150, max(1, value))
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let profile: UserProfile
    let currentAge: Int
    private var targetAge: Int { profile.targetAge }
    private var birthDate: Date { profile.birthday(in: ClockEngine.calendar(for: profile)) }

    var body: some View {
        let calendar = profile.lifeCalendar(from: ClockEngine.calendar(for: profile))
        let snapshot = LifeClockSnapshot(at: .now, calendar: calendar, birthDate: profile.birthday(in: calendar), targetAge: targetAge)
        let contexts = ClockScale.allCases.map {
            TimePhaseContext.make(scale: $0, at: snapshot.date, calendar: calendar, profile: profile, events: [])
        }
        KeduGlassSurface(role: .standard, cornerRadius: AppTheme.Radius.hero) {
            VStack(spacing: 16) {
                (dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 18)) : AnyLayout(HStackLayout(alignment: .firstTextBaseline))) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("生日")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                        Text(birthDate.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).locale(Locale(identifier: "zh_Hans_CN"))))
                            .font(.title3.monospaced().weight(.medium))
                            .monospacedDigit()
                    }

                    if !dynamicTypeSize.isAccessibilitySize { Spacer() }

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("预计寿命")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                        Text("\(targetAge) 岁")
                            .font(.title3.monospaced().weight(.medium))
                            .monospacedDigit()
                    }
                }

                TimeWeaveField(contexts: contexts,
                               snapshot: TimePhaseSnapshot(scale: .life, interval: DateInterval(start: snapshot.birthInstant, end: snapshot.targetInstant), at: snapshot.date),
                               zoom: PhaseZoom.level(for: .life), showsMinute: false)
                    .frame(height: 120)
                    .accessibilityHidden(true)
                LifeEquivalentReadout(years: snapshot.age)

                HStack {
                    Text("当前 \(currentAge) 岁")
                    Spacer()
                    Text(snapshot.progress.formatted(.percent.precision(.fractionLength(1))))
                }
                .font(.caption2.monospaced().weight(.medium))
                .foregroundStyle(theme.secondaryLabel(for: colorScheme))
            }
            .padding(18)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("人生刻度")
        .accessibilityValue("当前 \(currentAge) 岁，此刻 \(snapshot.progress.formatted(.percent.precision(.fractionLength(1))))，预计寿命 \(targetAge) 岁，已度过约 \(snapshot.age.formatted(.number.precision(.fractionLength(4)))) 年")
    }
}

private struct BirthdayCalibrationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @State private var date: Date
    let calendar: Calendar
    let commit: (Date) -> Void

    init(initialDate: Date, calendar: Calendar, commit: @escaping (Date) -> Void) {
        _date = State(initialValue: initialDate)
        self.calendar = calendar
        self.commit = commit
    }

    var body: some View {
        ZStack {
            theme.background(for: colorScheme).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    KeduSheetHeader(title: "校准生日", subtitle: "选择你来到这里的那一天") {
                        dismiss()
                    }

                    KeduGlassSurface(role: .standard) {
                        DatePicker(
                            "生日",
                            selection: $date,
                            in: CivilBirthday.allowedRange(calendar: calendar),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.wheel)
                        .environment(\.calendar, calendar)
                        .environment(\.timeZone, calendar.timeZone)
                        .labelsHidden()
                        .tint(theme.accent)
                        .padding(.horizontal, 8)
                    }

                }
                .padding(20)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            KeduActionButton(title: "应用生日", systemImage: "checkmark") {
                commit(date)
                dismiss()
            }
            .accessibilityIdentifier("settings.birthday.apply")
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(theme.background(for: colorScheme))
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
    let hapticsEnabled: Bool
    let commit: (Int) -> Void

    init(initialAge: Int, minimumAge: Int, hapticsEnabled: Bool, commit: @escaping (Int) -> Void) {
        _age = State(initialValue: initialAge)
        self.minimumAge = minimumAge
        self.hapticsEnabled = hapticsEnabled
        self.commit = commit
    }

    var body: some View {
        ZStack {
            theme.background(for: colorScheme).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    KeduSheetHeader(title: "校准预计寿命", subtitle: "死之终依据此设置计算，并非死亡预测") {
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
                                .font(.caption2.monospaced())
                                .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                        }
                        .padding(22)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("预计寿命")
                    .accessibilityValue("\(age) 岁")
                    .accessibilityAdjustableAction { direction in
                        adjust(direction == .increment ? 1 : -1)
                    }

                }
                .padding(20)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            KeduActionButton(title: "应用预计寿命", systemImage: "checkmark") {
                commit(age)
                dismiss()
            }
            .accessibilityIdentifier("settings.age.apply")
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(theme.background(for: colorScheme))
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
                    HapticManager.shared.selectionChanged(enabled: hapticsEnabled)
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
        .accessibilityLabel(delta > 0 ? "增加预计寿命" : "减少预计寿命")
    }

    private func adjust(_ delta: Int) {
        let next = min(150, max(minimumAge, age + delta))
        guard next != age else { return }
        age = next
        HapticManager.shared.selectionChanged(enabled: hapticsEnabled)
    }
}

#Preview("设置 · 深色") {
    SettingsView(profile: PreviewSupport.profile())
        .environment(AppTheme())
        .modelContainer(PreviewSupport.container(.single))
        .preferredColorScheme(.dark)
}
