import SwiftUI
import PodcastTranscriptStudioCore

struct JobDetailView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var speakerDrafts: [String: String] = [:]

    var body: some View {
        Group {
            if let job = viewModel.selectedJob {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(job.filename).font(.title2).bold()
                            Text("状态：\(job.status.rawValue)").foregroundStyle(.secondary)
                            if let errorMessage = job.errorMessage {
                                Text("错误：\(errorMessage)")
                                    .foregroundStyle(.red)
                            }
                            if let logPath = job.logPath {
                                Text("日志：\(logPath.path)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }

                        if !job.transcriptSections.isEmpty {
                            speakerEditor(job: job)
                            ForEach(job.transcriptSections) { section in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(section.title).font(.headline)
                                    ForEach(section.segments) { segment in
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("[\(segment.start) - \(segment.end)] \(viewModel.displayName(for: segment.speaker))")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(segment.text)
                                                .textSelection(.enabled)
                                        }
                                        .padding(.vertical, 6)
                                    }
                                }
                            }
                        } else {
                            Text("暂无转写结果")
                        }
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView("选择一个任务", systemImage: "waveform.and.mic")
            }
        }
    }

    @ViewBuilder
    private func speakerEditor(job: TranscriptionJob) -> some View {
        let speakers = Array(Set(job.transcriptSections.flatMap { $0.segments.map(\.speaker) })).sorted()
        if !speakers.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("说话人映射").font(.headline)
                ForEach(speakers, id: \.self) { speaker in
                    HStack {
                        Text(speaker).frame(width: 80, alignment: .leading)
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
                }
            }
        }
    }
}
