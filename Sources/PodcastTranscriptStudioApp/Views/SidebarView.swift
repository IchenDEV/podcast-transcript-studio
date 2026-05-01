import SwiftUI
import PodcastTranscriptStudioCore

struct SidebarView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var selectedPanel: DetailPanel
    @Binding var diarize: Bool
    @Binding var cleanFillers: Bool
    let onImportAudio: () -> Void
    let onImportPodcast: () -> Void
    let onExport: (ExportFormat) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader
            actionPanel
                .padding(.horizontal, 12)
                .padding(.bottom, 12)

            jobList
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            settingsFooter
                .padding(.horizontal, 12)
                .padding(.bottom, 14)
        }
        .background(.thinMaterial)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(.separator.opacity(colorScheme == .dark ? 0.30 : 0.45))
                .frame(width: 1)
        }
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("任务", systemImage: "waveform")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(viewModel.jobStore.jobs.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }

            Text("本地音视频和播客链接")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    private var actionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(spacing: 8) {
                Button {
                    selectedPanel = .result
                    onImportAudio()
                } label: {
                    Label("导入音频", systemImage: "plus")
                }
                .buttonStyle(GlassToolbarButtonStyle(prominent: true))

                Button {
                    selectedPanel = .result
                    onImportPodcast()
                } label: {
                    Label("播客链接", systemImage: "link.badge.plus")
                }
                .buttonStyle(GlassToolbarButtonStyle(prominent: false))
            }

            HStack(spacing: 8) {
                Text("选项")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Toggle(isOn: $diarize) {
                    Image(systemName: "person.2.wave.2")
                }
                .toggleStyle(GlassIconToggleStyle())
                .help("多说话人")
                .accessibilityLabel("多说话人")

                Toggle(isOn: $cleanFillers) {
                    Image(systemName: "wand.and.stars")
                }
                .toggleStyle(GlassIconToggleStyle())
                .help("清理语气词")
                .accessibilityLabel("清理语气词")

                exportMenu
            }
        }
        .padding(10)
        .neutralGlass(
            in: RoundedRectangle(cornerRadius: 18, style: .continuous),
            material: .thinMaterial,
            strokeOpacity: 0.38,
            shadowOpacity: 0.06
        )
    }

    private var exportMenu: some View {
        Menu {
            Button("导出 TXT") {
                onExport(.txt)
            }
            Button("导出 JSON") {
                onExport(.json)
            }
            Button("导出 SRT") {
                onExport(.srt)
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .menuStyle(.button)
        .buttonStyle(GlassIconButtonStyle(isSelected: false))
        .help("导出结果")
        .disabled(viewModel.selectedJob == nil || viewModel.isRunningJob)
    }

    private var jobList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if viewModel.jobStore.jobs.isEmpty {
                    emptyState
                } else {
                    Text("稿件")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.top, 2)

                    ForEach(viewModel.jobStore.jobs) { job in
                        Button {
                            viewModel.select(jobID: job.id)
                            selectedPanel = .result
                        } label: {
                            JobRow(job: job, isSelected: selectedPanel == .result && viewModel.selectedJobID == job.id)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text("还没有任务")
                .font(.callout.weight(.medium))
            Text("用上方按钮添加音频或播客链接")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 180)
        .padding(.horizontal, 8)
        .padding(.vertical, 24)
    }

    private var settingsFooter: some View {
        VStack(spacing: 8) {
            Divider()

            Button {
                selectedPanel = .settings
            } label: {
                SidebarPageRow(
                    title: "设置",
                    icon: "gearshape",
                    isSelected: selectedPanel == .settings
                )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct JobRow: View {
    let job: TranscriptionJob
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(statusColor.opacity(colorScheme == .dark ? 0.22 : 0.14))
                Image(systemName: statusIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: 34, height: 34)
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(.white.opacity(colorScheme == .dark ? 0.08 : 0.35))
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(job.filename)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    StatusBadge(status: job.status)
                    Text(job.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .background(selectionBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var selectionBackground: Color {
        if isSelected {
            return Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.10)
        }
        return Color.clear
    }

    private var statusColor: Color {
        switch job.status {
        case .queued: .orange
        case .running: .blue
        case .completed: .green
        case .failed: .red
        }
    }

    private var statusIcon: String {
        switch job.status {
        case .queued: "clock"
        case .running: "waveform"
        case .completed: "checkmark"
        case .failed: "exclamationmark"
        }
    }
}

private struct SidebarPageRow: View {
    let title: String
    let icon: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 20)

            Text(title)
                .font(.callout.weight(isSelected ? .semibold : .medium))

            Spacer(minLength: 0)
        }
        .foregroundStyle(isSelected ? Color.primary : Color.secondary)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct StatusBadge: View {
    let status: JobStatus

    var body: some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var title: String {
        switch status {
        case .queued: "等待中"
        case .running: "转写中"
        case .completed: "已完成"
        case .failed: "失败"
        }
    }

    private var color: Color {
        switch status {
        case .queued: .orange
        case .running: .blue
        case .completed: .green
        case .failed: .red
        }
    }
}
