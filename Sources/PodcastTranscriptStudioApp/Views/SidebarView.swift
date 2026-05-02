import SwiftUI
import PodcastTranscriptStudioCore

enum SidebarColumnWidth {
    static let minimum: CGFloat = 280
    static let ideal: CGFloat = 292
    static let maximum: CGFloat = 340
}

struct SidebarView: View {
    @ObservedObject var viewModel: AppViewModel
    @Binding var selectedPanel: DetailPanel
    @Binding var diarize: Bool
    @Binding var cleanFillers: Bool
    let onImportAudio: () -> Void
    let onImportPodcast: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            sidebarHeader
            actionList
                .padding(.horizontal, 14)
                .padding(.bottom, 16)

            jobList
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            settingsFooter
                .padding(.horizontal, 12)
                .padding(.bottom, 14)
        }
        .frame(
            minWidth: SidebarColumnWidth.minimum,
            idealWidth: SidebarColumnWidth.ideal,
            maxWidth: SidebarColumnWidth.maximum
        )
        .background(.bar)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(.separator.opacity(colorScheme == .dark ? 0.28 : 0.36))
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
        .padding(.horizontal, 18)
        .padding(.top, 22)
        .padding(.bottom, 18)
    }

    private var actionList: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("操作")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.bottom, 4)

            Button {
                selectedPanel = .result
                onImportAudio()
            } label: {
                SidebarActionRow(title: "导入音频", icon: "doc.badge.plus")
            }
            .buttonStyle(.plain)

            Button {
                selectedPanel = .result
                onImportPodcast()
            } label: {
                SidebarActionRow(title: "播客链接", icon: "link.badge.plus")
            }
            .buttonStyle(.plain)

            Button {
                diarize.toggle()
            } label: {
                SidebarActionRow(title: "说话人工具", icon: "person.2", isOn: diarize)
            }
            .buttonStyle(.plain)

            Button {
                cleanFillers.toggle()
            } label: {
                SidebarActionRow(title: "清理文本", icon: "wand.and.sparkles", isOn: cleanFillers)
            }
            .buttonStyle(.plain)
        }
    }

    private var jobList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                if viewModel.jobStore.jobs.isEmpty {
                    emptyState
                } else {
                    Text("任务列表")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.top, 2)
                        .padding(.bottom, 4)

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
            .padding(.horizontal, 14)
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

private struct SidebarActionRow: View {
    let title: String
    let icon: String
    var isOn: Bool? = nil

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(iconColor)
                .frame(width: 22)
            Text(title)
                .font(.callout)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 8)
        .frame(height: 36)
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityLabel(accessibilityTitle)
    }

    private var iconColor: Color {
        if isOn == true {
            return .blue
        }
        return .secondary
    }

    private var accessibilityTitle: String {
        if let isOn {
            return "\(title)，\(isOn ? "已开启" : "已关闭")"
        }
        return title
    }
}

private struct JobRow: View {
    let job: TranscriptionJob
    let isSelected: Bool
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            ZStack {
                Circle()
                    .fill(statusColor.opacity(colorScheme == .dark ? 0.18 : 0.10))
                Image(systemName: statusIcon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(statusColor)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: 30, height: 30)
            .overlay(
                Circle()
                    .strokeBorder(statusColor.opacity(colorScheme == .dark ? 0.28 : 0.32))
            )

            VStack(alignment: .leading, spacing: 5) {
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
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .background(selectionBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var selectionBackground: Color {
        if isSelected {
            return Color.primary.opacity(colorScheme == .dark ? 0.14 : 0.08)
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
