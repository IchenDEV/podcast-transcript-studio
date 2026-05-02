import SwiftUI
import UniformTypeIdentifiers
import PodcastTranscriptStudioCore

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel
    @AppStorage(AppIconPreference.storageKey) private var appIconPreferenceRawValue = AppIconPreference.system.rawValue

    @State private var jobsDirectoryPath = ""
    @State private var exportsDirectoryPath = ""
    @State private var logsDirectoryPath = ""
    @State private var modelsDirectoryPath = ""
    @State private var huggingFaceToken = ""
    @State private var settingsMessage: String?
    @State private var folderTarget: FolderTarget?
    @State private var showRuntimeDetails = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                iconSection

                modelSection

                SettingsGroup(title: "数据目录", icon: "folder") {
                    EditablePathRow(
                        title: "任务目录",
                        value: $jobsDirectoryPath,
                        icon: "tray.full",
                        description: "转写任务和中间文件",
                        onChoose: { folderTarget = .jobs }
                    )
                    Divider()
                    EditablePathRow(
                        title: "导出目录",
                        value: $exportsDirectoryPath,
                        icon: "square.and.arrow.up",
                        description: "TXT、JSON、SRT 输出位置",
                        onChoose: { folderTarget = .exports }
                    )
                    Divider()
                    EditablePathRow(
                        title: "日志目录",
                        value: $logsDirectoryPath,
                        icon: "doc.text.magnifyingglass",
                        description: "本地转写日志",
                        onChoose: { folderTarget = .logs }
                    )
                }

                runtimeSection
            }
            .frame(maxWidth: 980, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.top, 54)
            .padding(.bottom, 96)
        }
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .bottom) {
            settingsActionBar
        }
        .onAppear(perform: syncDrafts)
        .onChange(of: viewModel.configuration) { _, _ in
            syncDrafts()
        }
        .fileImporter(
            isPresented: Binding(
                get: { folderTarget != nil },
                set: { if !$0 { folderTarget = nil } }
            ),
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderSelection(result)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 7) {
                Text("设置")
                    .font(.system(size: 30, weight: .semibold))
                Text("管理本地模型、文件目录和运行环境。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 18)

            SettingsSummaryPill(
                title: "模型",
                value: "\(installedModelCount)/\(viewModel.modelAssetStatuses.count)",
                icon: "shippingbox"
            )
            SettingsSummaryPill(
                title: "目录",
                value: "3",
                icon: "folder"
            )
        }
    }

    private var modelSection: some View {
        SettingsGroup(title: "本地模型", icon: "shippingbox") {
            VStack(alignment: .leading, spacing: 16) {
                EditablePathRow(
                    title: "模型目录",
                    value: $modelsDirectoryPath,
                    icon: "cpu",
                    description: "下载后的模型会放在这里",
                    onChoose: { folderTarget = .models }
                )

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("模型状态")
                                .font(.headline)
                            Text("Whisper 负责转写，pyannote 负责说话人识别。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(installedModelCount) 个可用")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(installedModelCount == viewModel.modelAssetStatuses.count ? .green : .secondary)
                    }

                    LazyVGrid(columns: modelGridColumns, spacing: 10) {
                        ForEach(viewModel.modelAssetStatuses) { status in
                            ModelStatusCard(status: status)
                        }
                    }
                }
                .padding(.horizontal, 18)

                Divider()

                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Hugging Face Token")
                            .font(.callout.weight(.medium))
                        SecureField("访问 pyannote 模型时填写", text: $huggingFaceToken)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .frame(height: 38)
                            .neutralGlass(
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous),
                                material: .thinMaterial,
                                strokeOpacity: 0.36,
                                shadowOpacity: 0.0
                            )
                    }

                    Button {
                        Task {
                            await viewModel.downloadModels(huggingFaceToken: huggingFaceToken)
                        }
                    } label: {
                        if viewModel.modelDownloadState.isRunning {
                            Label("正在下载", systemImage: "arrow.down.circle")
                        } else {
                            Label("下载模型", systemImage: "arrow.down.circle")
                        }
                    }
                    .buttonStyle(GlassToolbarButtonStyle(prominent: true))
                    .disabled(viewModel.modelDownloadState.isRunning)
                    .frame(width: 132)
                }
                .padding(.horizontal, 18)

                if viewModel.modelDownloadState.phase != .idle {
                    DownloadStateBanner(state: viewModel.modelDownloadState)
                        .padding(.horizontal, 18)
                }
            }
            .padding(.vertical, 18)
        }
    }

    private var iconSection: some View {
        SettingsGroup(title: "应用图标", icon: "app") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dock 图标")
                            .font(.callout.weight(.medium))
                        Text("选择后立即应用。跟随系统会按浅色、深色外观自动切换。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 10) {
                    ForEach(AppIconPreference.allCases) { preference in
                        AppIconChoiceButton(
                            preference: preference,
                            selectedPreference: selectedIconPreference,
                            configuration: viewModel.configuration
                        ) {
                            appIconPreferenceRawValue = preference.rawValue
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
    }

    private var runtimeSection: some View {
        SettingsGroup(title: "运行时", icon: "gearshape.2") {
            DisclosureGroup(isExpanded: $showRuntimeDetails) {
                VStack(spacing: 0) {
                    Divider()
                    SettingsPathRow(title: "Python Runtime", value: viewModel.configuration.runtimeDirectory.path, icon: "curlybraces")
                    Divider()
                    SettingsPathRow(title: "脚本目录", value: viewModel.configuration.scriptsDirectory.path, icon: "terminal")
                    Divider()
                    SettingsPathRow(title: "内置模型目录", value: viewModel.configuration.bundledModelsDirectory.path, icon: "archivebox")
                }
            } label: {
                HStack(spacing: 12) {
                    SettingsIcon(icon: "terminal")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("查看打包运行环境")
                            .font(.callout.weight(.medium))
                        Text("调试本地 Python、脚本和内置模型路径时使用")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
            }
        }
    }

    private var settingsActionBar: some View {
        HStack(spacing: 12) {
            Spacer(minLength: 0)

            if let settingsMessage {
                Text(settingsMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .transition(.opacity)
            }

            Button {
                resetSettings()
            } label: {
                Label("恢复默认", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(GlassToolbarButtonStyle(prominent: false))
            .frame(width: 132)

            Button {
                saveSettings()
            } label: {
                Label("保存配置", systemImage: "checkmark.circle")
            }
            .buttonStyle(GlassToolbarButtonStyle(prominent: true))
            .frame(width: 132)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var installedModelCount: Int {
        viewModel.modelAssetStatuses.filter(\.isInstalled).count
    }

    private var selectedIconPreference: AppIconPreference {
        AppIconPreference(rawValue: appIconPreferenceRawValue) ?? .system
    }

    private var modelGridColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 210), spacing: 10),
            GridItem(.flexible(minimum: 210), spacing: 10),
        ]
    }

    private func syncDrafts() {
        jobsDirectoryPath = viewModel.configuration.jobsDirectory.path
        exportsDirectoryPath = viewModel.configuration.exportsDirectory.path
        logsDirectoryPath = viewModel.configuration.logsDirectory.path
        modelsDirectoryPath = viewModel.configuration.modelsDirectory.path
    }

    private func saveSettings() {
        do {
            let overrides = AppConfigurationOverrides(
                jobsDirectoryPath: normalizedDirectoryPath(jobsDirectoryPath),
                exportsDirectoryPath: normalizedDirectoryPath(exportsDirectoryPath),
                logsDirectoryPath: normalizedDirectoryPath(logsDirectoryPath),
                modelsDirectoryPath: normalizedDirectoryPath(modelsDirectoryPath)
            )
            try viewModel.updateConfiguration(overrides: overrides)
            settingsMessage = "配置已保存"
        } catch {
            settingsMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    private func resetSettings() {
        do {
            try viewModel.resetConfiguration()
            appIconPreferenceRawValue = AppIconPreference.system.rawValue
            settingsMessage = "已恢复默认配置"
        } catch {
            settingsMessage = "恢复失败：\(error.localizedDescription)"
        }
    }

    private func normalizedDirectoryPath(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return URL(fileURLWithPath: (trimmed as NSString).expandingTildeInPath, isDirectory: true).standardizedFileURL.path
    }

    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        defer { folderTarget = nil }

        switch result {
        case .success(let urls):
            guard let url = urls.first, let target = folderTarget else { return }
            let path = url.standardizedFileURL.path
            switch target {
            case .jobs:
                jobsDirectoryPath = path
            case .exports:
                exportsDirectoryPath = path
            case .logs:
                logsDirectoryPath = path
            case .models:
                modelsDirectoryPath = path
            }
        case .failure(let error):
            settingsMessage = "选择目录失败：\(error.localizedDescription)"
        }
    }
}

private enum FolderTarget: String, Identifiable {
    case jobs
    case exports
    case logs
    case models

    var id: String { rawValue }
}

private struct SettingsSummaryPill: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .neutralGlass(
            in: Capsule(),
            material: .thinMaterial,
            strokeOpacity: 0.32,
            shadowOpacity: 0.02
        )
    }
}

private struct AppIconChoiceButton: View {
    let preference: AppIconPreference
    let selectedPreference: AppIconPreference
    let configuration: AppConfiguration
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var isSelected: Bool {
        preference == selectedPreference
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AppIconPreviewImage(
                    variant: preference.resolvedVariant(for: colorScheme),
                    configuration: configuration
                )
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.white.opacity(colorScheme == .dark ? 0.08 : 0.42))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: preference.systemImage)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(isSelected ? .blue : .secondary)
                            .symbolRenderingMode(.hierarchical)
                        Text(preference.title)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(.primary)
                    }
                    Text(preference.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.blue : Color.secondary.opacity(0.45))
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(isSelected ? Color.blue.opacity(0.50) : Color.primary.opacity(0.08))
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsGroup<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

            Divider()

            VStack(spacing: 0) {
                content
            }
        }
        .neutralGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous), strokeOpacity: 0.42, shadowOpacity: 0.055)
    }
}

private struct EditablePathRow: View {
    let title: String
    @Binding var value: String
    let icon: String
    let description: String
    let onChoose: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            SettingsIcon(icon: icon)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.callout.weight(.medium))
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                TextField(title, text: $value)
                    .textFieldStyle(.plain)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 10)
                    .frame(height: 34)
                    .neutralGlass(
                        in: RoundedRectangle(cornerRadius: 9, style: .continuous),
                        material: .thinMaterial,
                        strokeOpacity: 0.38,
                        shadowOpacity: 0.0
                    )
            }

            Button {
                onChoose()
            } label: {
                Image(systemName: "folder")
            }
            .buttonStyle(GlassIconButtonStyle(isSelected: false))
            .help("选择目录")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

private struct ModelStatusCard: View {
    let status: ModelAssetStatus

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(statusColor.opacity(colorScheme == .dark ? 0.16 : 0.10))
                Image(systemName: status.isInstalled ? "checkmark" : "arrow.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(statusColor)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(modelName)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text(status.isInstalled ? "可用" : "未下载")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(colorScheme == .dark ? 0.14 : 0.10), in: Capsule())
                }

                Text(status.asset.repository)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(status.directory.path)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
        .neutralGlass(
            in: RoundedRectangle(cornerRadius: 13, style: .continuous),
            material: .thinMaterial,
            strokeOpacity: 0.30,
            shadowOpacity: 0.018
        )
    }

    private var modelName: String {
        switch status.asset.directoryName {
        case "whisper-tiny":
            "Whisper Tiny"
        case "speaker-diarization-3.1":
            "说话人识别"
        case "segmentation-3.0":
            "分段模型"
        case "wespeaker-voxceleb-resnet34-LM":
            "声纹模型"
        default:
            status.asset.directoryName
        }
    }

    private var statusColor: Color {
        status.isInstalled ? .green : .secondary
    }
}

private struct SettingsPathRow: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SettingsIcon(icon: icon)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(value)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}

private struct DownloadStateBanner: View {
    let state: ModelDownloadState

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if state.isRunning {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: state.phase == .succeeded ? "checkmark.circle" : "exclamationmark.triangle")
                    .foregroundStyle(state.phase == .succeeded ? .green : .red)
            }

            Text(state.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(6)

            Spacer()
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SettingsIcon: View {
    let icon: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.15 : 0.08))
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: 34, height: 34)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.white.opacity(colorScheme == .dark ? 0.08 : 0.35))
        )
    }
}
