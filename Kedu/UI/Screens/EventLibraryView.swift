import SwiftData
import SwiftUI

private enum EventLibrarySheet: Identifiable {
    case create
    case edit(TimeEvent)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let event): "edit.\(event.id.uuidString)"
        }
    }
}

/// A stable, searchable route to every marker, including markers outside the current period.
struct EventLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \TimeEvent.anchorDate) private var events: [TimeEvent]
    let profile: UserProfile
    @State private var search = ""
    @State private var presentedSheet: EventLibrarySheet?

    private var filtered: [TimeEvent] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return events.filter { query.isEmpty || $0.title.localizedStandardContains(query) }
    }

    private var historicalEvents: [TimeEvent] {
        filtered.filter { $0.recurrence == .weekly }
    }

    var body: some View {
        ZStack {
            theme.background(for: colorScheme).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    KeduSheetHeader(title: "刻点集", subtitle: "记录与周期刻点", closeIdentifier: "events.close") { dismiss() }
                    HStack {
                        Text("\(events.count)").font(.system(size: 56, weight: .light, design: .rounded))
                        Text("个刻点").font(.subheadline).foregroundStyle(theme.secondaryLabel(for: colorScheme))
                        Spacer()
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(theme.secondaryLabel(for: colorScheme))
                        TextField("寻找一个刻点", text: $search).accessibilityIdentifier("events.search")
                            .submitLabel(.search)
                        if !search.isEmpty {
                            Button { search = "" } label: {
                                Image(systemName: "xmark.circle.fill").frame(width: 44, height: 44)
                            }.buttonStyle(.plain).accessibilityLabel("清除搜索").accessibilityIdentifier("events.search.clear")
                        }
                    }
                    .padding(16).background(theme.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 18))

                    if events.isEmpty {
                        ContentUnavailableView("还没有刻点", systemImage: "circle.dotted", description: Text("记录一个日期，或添加每年、每月、每天的周期刻点。"))
                    } else if filtered.isEmpty {
                        ContentUnavailableView.search(text: search)
                    } else {
                        ForEach(ClockScale.allCases) { scale in
                            let group = filtered.filter { $0.scale == scale }
                            if !group.isEmpty {
                                eventGroup(title: scale == .life ? "独立刻点 · 一次性" : scale.title + " · " + ruleTitle(scale), events: group,
                                           explanation: scale == .life ? "一次性刻点仅在这里保存与查看，不出现在人生主场。" : nil)
                            }
                        }

                        if !historicalEvents.isEmpty {
                            eventGroup(
                                title: "历史刻点",
                                events: historicalEvents,
                                explanation: "原每周规则已停用。可以保留记录，或在编辑中选择新的重复规则。",
                                titleIdentifier: "events.history"
                            )
                        }
                    }
                }
                .padding(24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            KeduActionButton(title: "添加刻点", systemImage: "plus") { presentedSheet = .create }
                .accessibilityIdentifier("events.add")
                .padding(20).background(theme.background(for: colorScheme))
        }
        .sheet(item: $presentedSheet) { destination in
            switch destination {
            case .create:
                EventEditorView(event: nil, defaultRecurrence: .once, profile: profile)
            case .edit(let event):
                EventEditorView(event: event, defaultRecurrence: event.recurrence, profile: profile)
            }
        }
    }

    private func ruleTitle(_ scale: ClockScale) -> String {
        RecurrenceRule.supportedCases.first { $0.scale == scale }?.title ?? ""
    }

    private func eventGroup(title: String, events: [TimeEvent], explanation: String? = nil, titleIdentifier: String = "") -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.caption.weight(.medium))
                    .accessibilityIdentifier(titleIdentifier)
                Spacer()
                Text("\(events.count)").font(.caption.monospaced())
            }
            .foregroundStyle(theme.secondaryLabel(for: colorScheme))

            if let explanation {
                Text(explanation)
                    .font(.caption)
                    .foregroundStyle(theme.secondaryLabel(for: colorScheme))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 0) {
                ForEach(events) { event in
                    Button { presentedSheet = .edit(event) } label: {
                        row(event)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("events.row.\(event.title)")
                }
            }
            .background(theme.surface(for: colorScheme), in: RoundedRectangle(cornerRadius: 22))
        }
    }

    private func row(_ event: TimeEvent) -> some View {
        HStack(spacing: 14) {
            Image(systemName: event.symbolName).font(.system(size: 19))
                .foregroundStyle(event.eventColor.ink(for: colorScheme)).frame(width: 44, height: 44)
                .background(event.eventColor.color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 5) {
                Text(event.title).font(.body).lineLimit(2)
                Text(event.recurrence == .weekly ? "每周 · 已停用 · \(dateLabel(event))" : dateLabel(event))
                    .font(.caption)
                    .foregroundStyle(theme.secondaryLabel(for: colorScheme))
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption2.weight(.medium)).foregroundStyle(theme.secondaryLabel(for: colorScheme))
        }
        .padding(16).contentShape(Rectangle())
    }

    private func dateLabel(_ event: TimeEvent) -> String {
        let anchor = event.anchor(in: ClockEngine.calendar(for: profile))
        switch event.recurrence {
        case .daily: return anchor.formatted(.dateTime.hour().minute().locale(Locale(identifier: "zh_Hans_CN")))
        case .weekly: return anchor.formatted(.dateTime.weekday(.wide).hour().minute().locale(Locale(identifier: "zh_Hans_CN")))
        case .monthly: return anchor.formatted(.dateTime.day().hour().minute().locale(Locale(identifier: "zh_Hans_CN")))
        case .yearly: return anchor.formatted(.dateTime.month().day().hour().minute().locale(Locale(identifier: "zh_Hans_CN")))
        case .once: return anchor.formatted(.dateTime.year().month().day().hour().minute().locale(Locale(identifier: "zh_Hans_CN")))
        }
    }
}
