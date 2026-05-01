import SwiftUI
import PodcastTranscriptStudioCore

struct JobDetailView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var speakerDrafts: [String: String] = [:]

    var body: some View {
        Group {
            if let job = viewModel.selectedJob {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        jobHeader(job)

                        if !job.transcriptSections.isEmpty {
                            speakerEditor(job: job)
                            ForEach(job.transcriptSections) { section in
                                transcriptSection(section)
                            }
                        } else {
                            emptyTranscript(job: job)
                        }
                    }
                    .frame(maxWidth: 980, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
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
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(statusColor(job.status).opacity(0.14))
                    Image(systemName: statusIcon(job.status))
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(statusColor(job.status))
                }
                .frame(width: 56, height: 56)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Text(job.filename)
                            .font(.system(size: 28, weight: .semibold))
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

            if let errorMessage = job.errorMessage {
                messageRow(icon: "exclamationmark.triangle", title: "转写失败", value: errorMessage, color: .red)
            }

            if let logPath = job.logPath {
                messageRow(icon: "doc.text.magnifyingglass", title: "日志", value: logPath.path, color: .secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(20)
        .neutralGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), strokeOpacity: 0.48, shadowOpacity: 0.09)
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
        .padding(12)
        .neutralGlass(in: RoundedRectangle(cornerRadius: 13, style: .continuous), material: .thinMaterial, strokeOpacity: 0.34, shadowOpacity: 0.02)
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
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("说话人名称", systemImage: "person.text.rectangle")
                        .font(.headline)
                    Spacer()
                    Text("\(speakers.count) 位")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ForEach(speakers, id: \.self) { speaker in
                    HStack(spacing: 12) {
                        speakerMark(speaker)

                        Text(speaker)
                            .font(.callout.weight(.medium))
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
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .neutralGlass(in: RoundedRectangle(cornerRadius: 9, style: .continuous), material: .thinMaterial, strokeOpacity: 0.40, shadowOpacity: 0.0)
                    }
                }
            }
            .padding(18)
            .neutralGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous), strokeOpacity: 0.42, shadowOpacity: 0.055)
        }
    }

    private func transcriptSection(_ section: TranscriptSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label(section.title, systemImage: "bookmark")
                    .font(.headline)
                Spacer()
                Text("\(section.segments.count) 段")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)

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
        .neutralGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous), strokeOpacity: 0.42, shadowOpacity: 0.055)
    }

    private func transcriptSegment(_ segment: TranscriptSegment) -> some View {
        HStack(alignment: .top, spacing: 14) {
            speakerMark(segment.speaker)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(viewModel.displayName(for: segment.speaker))
                        .font(.callout.weight(.semibold))

                    Text("\(segment.start) - \(segment.end)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Text(segment.text)
                    .font(.system(size: 15))
                    .lineSpacing(4)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
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
        .neutralGlass(in: RoundedRectangle(cornerRadius: 16, style: .continuous), strokeOpacity: 0.40, shadowOpacity: 0.055)
    }

    private func speakerMark(_ speaker: String) -> some View {
        Circle()
            .fill(speakerColor(speaker).gradient)
            .frame(width: 34, height: 34)
            .overlay {
                Text(speakerInitial(speaker))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
            }
            .shadow(color: speakerColor(speaker).opacity(0.22), radius: 8, y: 3)
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
