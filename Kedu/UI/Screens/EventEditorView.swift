import SwiftData
import SwiftUI

struct EventEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let event: TimeEvent?
    let profile: UserProfile

    @State private var title: String
    @State private var symbolName: String
    @State private var eventColor: EventColor
    @State private var recurrence: RecurrenceRule
    @State private var anchorDate: Date
    @State private var showingDateCalibration = false
    @State private var showingDeleteConfirmation = false
    @State private var saveError: String?
    @FocusState private var titleFocused: Bool

    private let symbols = [
        "circle.fill", "birthday.cake.fill", "creditcard.fill", "pills.fill",
        "figure.run", "briefcase.fill", "heart.fill", "book.fill"
    ]

    init(event: TimeEvent?, defaultRecurrence: RecurrenceRule, profile: UserProfile) {
        self.event = event
        self.profile = profile
        _title = State(initialValue: event?.title ?? "")
        _symbolName = State(initialValue: event?.symbolName ?? "circle.fill")
        _eventColor = State(initialValue: event?.eventColor ?? .jade)
        _recurrence = State(initialValue: event?.recurrence ?? defaultRecurrence)
        _anchorDate = State(initialValue: event?.anchorDate ?? .now)
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack(alignment: .top) {
            theme.background(for: colorScheme).ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    KeduSheetHeader(
                        title: event == nil ? "添加刻点" : "编辑刻点",
                        subtitle: "把一个时刻放进它所属的尺度",
                        closeIdentifier: "event.close"
                    ) {
                        dismiss()
                    }

                    EventPreviewPanel(
                        title: trimmedTitle,
                        symbolName: symbolName,
                        eventColor: eventColor,
                        recurrence: recurrence,
                        anchorDate: anchorDate
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("刻点")

                        KeduGlassSurface(role: .standard, cornerRadius: 24) {
                            HStack(spacing: 12) {
                                Image(systemName: symbolName)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundStyle(eventColor.color)
                                    .frame(width: 44, height: 44)
                                    .background(eventColor.color.opacity(0.12), in: Circle())

                                TextField("给这个时刻起个名字", text: $title)
                                    .font(.system(size: 17, weight: .medium))
                                    .focused($titleFocused)
                                    .submitLabel(.done)
                                    .accessibilityIdentifier("event.title")

                                if !title.isEmpty {
                                    Button {
                                        title = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(theme.tertiaryLabel(for: colorScheme))
                                            .frame(width: 44, height: 44)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("清除名称")
                                }
                            }
                            .padding(.horizontal, 14)
                            .frame(minHeight: 68)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("重复")

                        KeduSegmentedRail(
                            options: RecurrenceRule.allCases,
                            selection: $recurrence,
                            label: { Text($0.title) },
                            accessibilityLabel: { $0.title }
                        )
                        .accessibilityIdentifier("event.recurrence")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("时间")

                        KeduGlassSurface(role: .standard, cornerRadius: 24) {
                            KeduCalibrationField(
                                title: datePickerTitle,
                                value: formattedAnchorDate,
                                helper: "按照\(recurrence.scale.title)尺度显示",
                                systemImage: "clock"
                            ) {
                                showingDateCalibration = true
                            }
                        }
                        .accessibilityIdentifier("event.date")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        sectionTitle("外观")

                        AppearanceSelector(
                            symbols: symbols,
                            symbolName: $symbolName,
                            eventColor: $eventColor
                        )
                    }

                    if event != nil {
                        KeduActionButton(
                            title: "删除刻点",
                            systemImage: "trash",
                            role: .destructive
                        ) {
                            showingDeleteConfirmation = true
                        }
                        .accessibilityIdentifier("event.delete")
                        .padding(.top, 6)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 110)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            if let saveError {
                KeduNoticeBanner(message: saveError)
                    .padding(.horizontal, 20)
                    .padding(.top, 78)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityIdentifier("event.error")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            KeduActionButton(
                title: event == nil ? "保存刻点" : "保存修改",
                systemImage: "checkmark",
                isDisabled: trimmedTitle.isEmpty,
                action: save
            )
            .accessibilityIdentifier("event.save")
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(theme.background(for: colorScheme).opacity(0.96))
        }
        .sheet(isPresented: $showingDateCalibration) {
            EventDateCalibrationSheet(
                date: $anchorDate,
                recurrence: recurrence,
                validRange: validDateRange
            )
        }
        .sheet(isPresented: $showingDeleteConfirmation) {
            KeduConfirmationSheet(
                title: "删除这个刻点？",
                message: "删除后无法恢复，但不会影响其他时间尺度。",
                confirmTitle: "确认删除",
                confirmAction: delete
            )
        }
        .animation(.easeInOut(duration: 0.2), value: saveError)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(theme.navigationLabel(for: colorScheme))
    }

    private var datePickerTitle: String {
        switch recurrence {
        case .once: "日期与时间"
        case .yearly: "每年"
        case .monthly: "每月"
        case .weekly: "每周"
        case .daily: "每天"
        }
    }

    private var formattedAnchorDate: String {
        if recurrence == .daily {
            return anchorDate.formatted(date: .omitted, time: .shortened)
        }
        return anchorDate.formatted(
            .dateTime.year().month(.twoDigits).day(.twoDigits).hour().minute().locale(Locale(identifier: "zh_Hans_CN"))
        )
    }

    private var validDateRange: ClosedRange<Date> {
        guard recurrence == .once else { return Date.distantPast...Date.distantFuture }
        let calendar = ClockEngine.calendar(for: profile)
        let end = calendar.date(byAdding: .year, value: profile.targetAge, to: profile.birthDate) ?? .distantFuture
        return profile.birthDate...end
    }

    private func save() {
        guard !trimmedTitle.isEmpty else { return }

        if let event {
            event.title = trimmedTitle
            event.symbolName = symbolName
            event.eventColor = eventColor
            event.recurrence = recurrence
            event.anchorDate = anchorDate
            event.updatedAt = .now
        } else {
            modelContext.insert(TimeEvent(
                title: trimmedTitle,
                symbolName: symbolName,
                color: eventColor,
                recurrence: recurrence,
                anchorDate: anchorDate
            ))
        }

        do {
            try modelContext.save()
            HapticManager.shared.saved(enabled: profile.hapticsEnabled)
            dismiss()
        } catch {
            saveError = "刻点未能保存，请再试一次。"
        }
    }

    private func delete() {
        guard let event else { return }
        modelContext.delete(event)
        do {
            try modelContext.save()
            showingDeleteConfirmation = false
            Task { @MainActor in
                await Task.yield()
                dismiss()
            }
        } catch {
            saveError = "刻点未能删除，请再试一次。"
            showingDeleteConfirmation = false
        }
    }
}

private struct EventPreviewPanel: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    let title: String
    let symbolName: String
    let eventColor: EventColor
    let recurrence: RecurrenceRule
    let anchorDate: Date

    var body: some View {
        KeduGlassSurface(role: .standard, cornerRadius: AppTheme.Radius.hero) {
            HStack(spacing: 16) {
                Image(systemName: symbolName)
                    .font(.system(size: 23, weight: .medium))
                    .foregroundStyle(eventColor.color)
                    .frame(width: 58, height: 58)
                    .background(eventColor.color.opacity(0.13), in: RoundedRectangle(cornerRadius: 19, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                            .stroke(eventColor.color.opacity(0.3), lineWidth: 0.7)
                    }

                VStack(alignment: .leading, spacing: 5) {
                    Text(title.isEmpty ? "未命名刻点" : title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(title.isEmpty ? theme.secondaryLabel(for: colorScheme) : Color.primary)
                        .lineLimit(1)

                    Text("\(recurrence.title) · \(previewDate)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                        .monospacedDigit()
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 4) {
                    Text(recurrence.scale.title)
                        .font(.system(size: 22, weight: .light, design: .monospaced))
                    Text("尺度")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                }
            }
            .padding(18)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("刻点预览")
        .accessibilityValue("\(title.isEmpty ? "未命名" : title)，\(recurrence.title)，\(recurrence.scale.title)尺度")
        .accessibilityIdentifier("event.preview")
    }

    private var previewDate: String {
        recurrence == .daily
            ? anchorDate.formatted(date: .omitted, time: .shortened)
            : anchorDate.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct AppearanceSelector: View {
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let symbols: [String]
    @Binding var symbolName: String
    @Binding var eventColor: EventColor

    @Namespace private var symbolNamespace
    @Namespace private var colorNamespace

    var body: some View {
        KeduGlassSurface(role: .standard, cornerRadius: AppTheme.Radius.panel) {
            VStack(alignment: .leading, spacing: 18) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                    ForEach(symbols, id: \.self) { symbol in
                        Button {
                            selectSymbol(symbol)
                        } label: {
                            ZStack {
                                if symbolName == symbol {
                                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                                        .fill(eventColor.color.opacity(0.16))
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                                .stroke(eventColor.color.opacity(0.44), lineWidth: 0.7)
                                        }
                                        .matchedGeometryEffect(id: "symbol", in: symbolNamespace)
                                }

                                Image(systemName: symbol)
                                    .font(.system(size: 19, weight: .medium))
                                    .foregroundStyle(symbolName == symbol ? eventColor.color : theme.navigationLabel(for: colorScheme))
                            }
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("符号 \(symbol)")
                        .accessibilityAddTraits(symbolName == symbol ? .isSelected : [])
                    }
                }

                Rectangle()
                    .fill(theme.subtleStroke(for: colorScheme))
                    .frame(height: 0.5)

                HStack(spacing: 8) {
                    ForEach(EventColor.allCases) { color in
                        Button {
                            selectColor(color)
                        } label: {
                            ZStack {
                                if eventColor == color {
                                    Circle()
                                        .fill(color.color.opacity(0.15))
                                        .frame(width: 48, height: 48)
                                        .matchedGeometryEffect(id: "color", in: colorNamespace)
                                }

                                Circle()
                                    .fill(color.color)
                                    .frame(width: 25, height: 25)
                                    .overlay {
                                        if eventColor == color {
                                            Circle().stroke(Color.primary, lineWidth: 1.5).padding(-5)
                                        }
                                    }
                            }
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(color.title)
                        .accessibilityAddTraits(eventColor == color ? .isSelected : [])
                    }
                }
            }
            .padding(14)
        }
        .accessibilityIdentifier("event.appearance")
    }

    private func selectSymbol(_ symbol: String) {
        guard symbol != symbolName else { return }
        if reduceMotion {
            symbolName = symbol
        } else {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                symbolName = symbol
            }
        }
    }

    private func selectColor(_ color: EventColor) {
        guard color != eventColor else { return }
        if reduceMotion {
            eventColor = color
        } else {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                eventColor = color
            }
        }
    }
}

private struct EventDateCalibrationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme

    @Binding var date: Date
    let recurrence: RecurrenceRule
    let validRange: ClosedRange<Date>

    var body: some View {
        ZStack {
            theme.background(for: colorScheme).ignoresSafeArea()

            VStack(spacing: 20) {
                KeduSheetHeader(title: "校准时间", subtitle: "\(recurrence.title) · \(recurrence.scale.title)尺度") {
                    dismiss()
                }

                KeduGlassSurface(role: .standard) {
                    DatePicker(
                        "时间",
                        selection: $date,
                        in: validRange,
                        displayedComponents: recurrence == .daily ? [.hourAndMinute] : [.date, .hourAndMinute]
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .tint(theme.accent)
                    .padding(.horizontal, 8)
                    .accessibilityIdentifier("event.date.picker")
                }

                Spacer()

                KeduActionButton(title: "应用时间", systemImage: "checkmark") {
                    dismiss()
                }
                .accessibilityIdentifier("event.date.apply")
            }
            .padding(20)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }
}
