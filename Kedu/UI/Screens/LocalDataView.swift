import SwiftData
import SwiftUI
import UniformTypeIdentifiers

private struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw BackupError.invalidFile }
        self.data = data
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct LocalDataView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \TimeEvent.createdAt) private var events: [TimeEvent]
    @AppStorage("appearance") private var appearance: AppAppearance = .system
    let profile: UserProfile
    @State private var document: BackupDocument?
    @State private var exporting = false
    @State private var importing = false
    @State private var pendingBackup: LocalBackup?
    @State private var message: String?
    @State private var isError = false
    @State private var isReading = false
    @State private var readTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            theme.background(for: colorScheme).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    KeduSheetHeader(title: "本地数据", subtitle: "备份与恢复", closeIdentifier: "data.close") { dismiss() }
                    Text("生日、预计寿命与 \(events.count) 个刻点保存在这台设备上。")
                        .font(.body)
                    Text("更换设备或删除 App 前，可以先保存一份备份。")
                        .font(.subheadline).foregroundStyle(theme.secondaryLabel(for: colorScheme))
                    KeduActionButton(title: "导出备份", systemImage: "square.and.arrow.up", isDisabled: isReading) { exportBackup() }
                        .accessibilityIdentifier("data.export")
                    KeduActionButton(title: "恢复备份", systemImage: "arrow.down.doc", role: .secondary, isDisabled: isReading) { importing = true }
                        .accessibilityIdentifier("data.import")
                    Text("备份包含生日和全部刻点，未加密。请保存到你信任的位置。App 不会自动上传或同步。")
                        .font(.caption).foregroundStyle(theme.secondaryLabel(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)
                    if isReading { ProgressView("正在读取备份…") }
                    if let message {
                        KeduNoticeBanner(message: message, isError: isError)
                            .accessibilityIdentifier("data.notice")
                    }
                }.padding(20)
            }
        }
        .fileExporter(isPresented: $exporting, document: document, contentType: .json, defaultFilename: "刻度备份") { result in
            switch result {
            case .success: notify("备份已保存。", error: false)
            case .failure(let error): if !Self.isCancellation(error) { notify("备份未能保存，请再试一次。", error: true) }
            }
            document = nil
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url): readBackup(url)
            case .failure(let error): if !Self.isCancellation(error) { notify("暂时无法读取文件，请再试一次。", error: true) }
            }
        }
        .sheet(isPresented: Binding(get: { pendingBackup != nil }, set: { if !$0 { pendingBackup = nil } })) {
            if let backup = pendingBackup {
                BackupRestoreConfirmation(backup: backup) { restore(backup) }
            }
        }
        .onDisappear { readTask?.cancel() }
        #if DEBUG
        .task {
            if AppLaunchOptions.contains("-uiTestingPreviewBackup") {
                let previewProfile = UserProfile(birthDate: profile.birthDate, targetAge: 90, hapticsEnabled: false)
                previewProfile.birthDateComponents = profile.birthDateComponents
                previewProfile.birthTimeZoneIdentifier = profile.birthTimeZoneIdentifier
                let preview = LocalBackup(profile: previewProfile,
                                          events: [TimeEvent(title: "备份中的刻点", recurrence: .weekly, anchorDate: .now)],
                                          appearance: .light)
                pendingBackup = try? LocalBackup.decode(preview.encoded())
            }
        }
        #endif
    }

    private func exportBackup() {
        do {
            let backup = LocalBackup(profile: profile, events: events, appearance: appearance)
            document = BackupDocument(data: try backup.encoded())
            message = nil
            exporting = true
        } catch { notify(error.localizedDescription, error: true) }
    }

    private func readBackup(_ url: URL) {
        isReading = true
        readTask?.cancel()
        readTask = Task {
            defer { isReading = false }
            do {
                let backup = try await Task.detached {
                    let accessed = url.startAccessingSecurityScopedResource()
                    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                    // Limit the read itself before decoding a provider's file.
                    let handle = try FileHandle(forReadingFrom: url)
                    defer { try? handle.close() }
                    let data = try handle.read(upToCount: LocalBackup.maximumBytes + 1) ?? Data()
                    return try LocalBackup.decode(data)
                }.value
                guard !Task.isCancelled else { return }
                pendingBackup = backup
                message = nil
            } catch {
                guard !Task.isCancelled else { return }
                notify(error is BackupError ? error.localizedDescription : "备份无法读取，当前数据未被更改。", error: true)
            }
        }
    }

    private func restore(_ backup: LocalBackup) {
        do {
            try backup.restore(in: modelContext, into: profile)
            appearance = AppAppearance(rawValue: backup.appearance) ?? .system
            pendingBackup = nil
            HapticManager.shared.saved(enabled: profile.hapticsEnabled)
            notify("备份已恢复。", error: false)
        } catch {
            pendingBackup = nil
            notify("备份未能恢复，原有数据已保留。请再试一次。", error: true)
        }
    }

    private func notify(_ text: String, error: Bool) { message = text; isError = error }
    private static func isCancellation(_ error: Error) -> Bool {
        let error = error as NSError
        return error.domain == NSCocoaErrorDomain && error.code == NSUserCancelledError
    }
}

private struct BackupRestoreConfirmation: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppTheme.self) private var theme
    @Environment(\.colorScheme) private var colorScheme
    let backup: LocalBackup
    let restore: () -> Void
    var body: some View {
        ZStack {
            theme.background(for: colorScheme).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    KeduSheetHeader(title: "恢复这份备份？", closeIdentifier: "data.restore.close") { dismiss() }
                    Text("生日 · \(backup.profile.birthday)")
                    Text("预计寿命 · \(backup.profile.targetAge) 岁")
                    Text("\(backup.events.count) 个刻点")
                    Text("备份于 \(backup.exportedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundStyle(theme.secondaryLabel(for: colorScheme))
                    Text("恢复会替换当前生日、预计寿命、偏好与全部刻点。若想保留现有数据，请先取消并导出一份备份。")
                        .font(.body).fixedSize(horizontal: false, vertical: true)
                    KeduActionButton(title: "替换并恢复", systemImage: "arrow.clockwise", role: .destructive, action: restore)
                        .accessibilityIdentifier("data.restore.confirm")
                    KeduActionButton(title: "取消", role: .secondary) { dismiss() }
                }.padding(20)
            }
        }
    }
}
