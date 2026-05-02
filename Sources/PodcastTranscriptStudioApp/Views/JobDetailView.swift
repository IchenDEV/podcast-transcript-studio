import SwiftUI
import PodcastTranscriptStudioCore

struct JobDetailView: View {
    @ObservedObject var viewModel: AppViewModel
    let displayMode: TranscriptDisplayMode
    @Environment(\.colorScheme) private var colorScheme
    @State private var speakerDrafts: [String: String] = [:]

    var body: some View {
        Group {
            if let job = viewModel.selectedJob {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        jobHeader(job)

                        if !job.transcriptSections.isEmpty {
                            if displayMode == .detail {
                                speakerEditor(job: job)
                                ForEach(job.transcriptSections) { section in
                                    transcriptSection(section)
                                }
                            } else {
                                rawTranscript(job: job)
                            }
                        } else {
                            emptyTranscript(job: job)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.top, 34)
                    .padding(.bottom, 96)
                }
                .scrollContentBackground(.hidden)
            } else {
                emptySelection
            }
        }
    }

    private var emptySelection: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform.and.mic")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(.tertiary)
            Text("选择一个任务")
                .font(.title3.weight(.semibold))
            Text("左侧选择已有任务，或导入新的音频文件。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private func jobHeader(_ job: TranscriptionJob) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 14) {
                statusMark(job.status)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Text(job.filename)
                            .font(.system(size: 25, weight: .semibold))
                            .lineLimit(1)
                        statusPill(job.status)
                    }

                    Text(job.createdAt.formatted(date: .complete, time: .shortened))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 12) {
                metric(title: "分节", value: "\(job.transcriptSections.count)", icon: "square.stack")
                metric(title: "片段", value: "\(segmentCount(job))", icon: "text.alignleft")
                metric(title: "说话人", value: "\(speakerCount(job))", icon: "person.2")
            }

            Divider()

            if let errorMessage = job.errorMessage {
                messageRow(icon: "exclamationmark.triangle", title: "转写失败", value: errorMessage, color: .red)
            }

            if let logPath = job.logPath {
                messageRow(icon: "doc.text.magnifyingglass", title: "日志", value: logPath.path, color: .secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private func statusMark(_ status: JobStatus) -> some View {
        ZStack {
            Circle()
                .fill(statusColor(status).opacity(colorScheme == .dark ? 0.16 : 0.08))
            Circle()
                .strokeBorder(statusColor(status).opacity(0.55), lineWidth: 1.5)
            Image(systemName: statusIcon(status))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(statusColor(status))
        }
        .frame(width: 44, height: 44)
    }

    private func metric(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .frame(height: 56)
        .background(metricFill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(.separator.opacity(colorScheme == .dark ? 0.30 : 0.22))
        )
    }

    private func messageRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(colorScheme == .dark ? 0.14 : 0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func speakerEditor(job: TranscriptionJob) -> some View {
        let speakers = Array(Set(job.transcriptSections.flatMap { $0.segments.map(\.speaker) })).sorted()
        if !speakers.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Label("说话人", systemImage: "person.text.rectangle")
                        .font(.callout.weight(.semibold))
                    Spacer()
                    Text("\(speakers.count) 位")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider()

                ForEach(speakers, id: \.self) { speaker in
                    HStack(spacing: 12) {
                        speakerMark(speaker)

                        Text(speaker)
                            .font(.subheadline.weight(.medium))
                            .frame(width: 82, alignment: .leading)

                        TextField(
                            speaker,
                            text: Binding(
                                get: { speakerDrafts[speaker] ?? viewModel.displayName(for: speaker) },
                                set: {
                                    speakerDrafts[speaker] = $0
                                    viewModel.renameSpeaker($0, for: speaker)
                                }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                }
            }
            .systemGroupedPanel()
        }
    }

    private func transcriptSection(_ section: TranscriptSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(section.title, systemImage: "bookmark")
                    .font(.callout.weight(.semibold))
                Spacer()
                Text("\(section.segments.count) 段")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            Divider()

            HStack(spacing: 14) {
                Text("#")
                    .frame(width: 34)
                Text("说话人")
                    .frame(width: 190, alignment: .leading)
                Text("时间")
                    .frame(width: 250, alignment: .leading)
                Text("文本")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)

            Divider()

            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(section.segments) { segment in
                    transcriptSegment(segment)
                    if segment.id != section.segments.last?.id {
                        Divider().padding(.leading, 74)
                    }
                }
            }
        }
        .systemGroupedPanel()
    }

    private func transcriptSegment(_ segment: TranscriptSegment) -> some View {
        HStack(alignment: .top, spacing: 14) {
            speakerMark(segment.speaker)
                .padding(.top, 2)

            Text(viewModel.displayName(for: segment.speaker))
                .font(.subheadline.weight(.medium))
                .frame(width: 190, alignment: .leading)

            Text("\(segment.start) - \(segment.end)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 250, alignment: .leading)

            Text(segment.text)
                .font(.subheadline)
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private func rawTranscript(job: TranscriptionJob) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("原文", systemImage: "doc.plaintext")
                    .font(.callout.weight(.semibold))
                Spacer()
                Text("\(segmentCount(job)) 段")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            Divider()

            Text(rawTranscriptText(job))
                .font(.subheadline)
                .lineSpacing(4)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
        }
        .systemGroupedPanel()
    }

    private func emptyTranscript(job: TranscriptionJob) -> some View {
        VStack(spacing: 12) {
            Image(systemName: job.status == .running ? "waveform" : "doc.text.magnifyingglass")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.tertiary)

            Text(job.status == .running ? "正在生成稿件" : "暂无转写结果")
                .font(.headline)

            Text(job.status == .running ? "完成后会在这里显示时间轴和说话人。" : "任务完成后会显示可选择、可导出的文本。")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 72)
        .systemGroupedPanel()
    }

    private func speakerMark(_ speaker: String) -> some View {
        Text(speakerInitial(speaker))
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .frame(width: 30, height: 30)
    }

    private func statusPill(_ status: JobStatus) -> some View {
        Text(statusTitle(status))
            .font(.caption.weight(.semibold))
            .foregroundStyle(statusColor(status))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(statusColor(status).opacity(0.12), in: Capsule())
    }

    private func segmentCount(_ job: TranscriptionJob) -> Int {
        job.transcriptSections.reduce(0) { $0 + $1.segments.count }
    }

    private func speakerCount(_ job: TranscriptionJob) -> Int {
        Set(job.transcriptSections.flatMap { $0.segments.map(\.speaker) }).count
    }

    private func speakerInitial(_ speaker: String) -> String {
        String(speaker.suffix(1))
    }

    private func speakerColor(_ speaker: String) -> Color {
        let colors: [Color] = [.blue, .teal, .cyan, .indigo, .pink, .orange]
        let index = speaker.unicodeScalars.reduce(0) { $0 + Int($1.value) } % colors.count
        return colors[index]
    }

    private var metricFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.055) : Color.white.opacity(0.50)
    }

    private func rawTranscriptText(_ job: TranscriptionJob) -> String {
        job.transcriptSections
            .flatMap(\.segments)
            .map(\.text)
            .joined(separator: "\n\n")
    }

    private func statusTitle(_ status: JobStatus) -> String {
        switch status {
        case .queued: "等待中"
        case .running: "转写中"
        case .completed: "已完成"
        case .failed: "失败"
        }
    }

    private func statusIcon(_ status: JobStatus) -> String {
        switch status {
        case .queued: "clock"
        case .running: "waveform"
        case .completed: "checkmark"
        case .failed: "exclamationmark"
        }
    }

    private func statusColor(_ status: JobStatus) -> Color {
        switch status {
        case .queued: .orange
        case .running: .blue
        case .completed: .green
        case .failed: .red
        }
    }
}

private struct SystemGroupedPanel: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(panelFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(.separator.opacity(colorScheme == .dark ? 0.34 : 0.22))
            )
    }

    private var panelFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.055) : Color.white.opacity(0.52)
    }
}

private extension View {
    func systemGroupedPanel() -> some View {
        modifier(SystemGroupedPanel())
    }
}
