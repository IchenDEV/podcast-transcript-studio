import Foundation

public struct TranscriptExporter {
    public let configuration: AppConfiguration

    public init(configuration: AppConfiguration) {
        self.configuration = configuration
    }

    @discardableResult
    public func export(job: TranscriptionJob, format: ExportFormat, baseFilename: String) throws -> URL {
        try FileManager.default.createDirectory(at: configuration.exportsDirectory, withIntermediateDirectories: true, attributes: nil)
        let url = configuration.exportsDirectory.appendingPathComponent(format.outputFilename(base: baseFilename))
        let content = render(job: job, format: format)
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    public func render(job: TranscriptionJob, format: ExportFormat) -> String {
        switch format {
        case .txt:
            return renderPlainText(job: job)
        case .json:
            return renderJSON(job: job)
        case .markdown:
            return renderMarkdown(job: job)
        case .srt:
            return renderSRT(job: job)
        }
    }

    private func renderPlainText(job: TranscriptionJob) -> String {
        job.transcriptSections.map { section in
            let body = section.segments.map { segment in
                "[\(segment.start) - \(segment.end)] \(displayName(for: segment.speaker, job: job)): \(segment.text)"
            }.joined(separator: "\n")
            return "【\(section.title)】\n\n\(body)"
        }.joined(separator: "\n\n")
    }

    private func renderMarkdown(job: TranscriptionJob) -> String {
        job.transcriptSections.map { section in
            let body = section.segments.map { segment in
                "- `\(segment.start) - \(segment.end)` **\(displayName(for: segment.speaker, job: job))**: \(segment.text)"
            }.joined(separator: "\n")
            return "## \(section.title)\n\n\(body)"
        }.joined(separator: "\n\n")
    }

    private func renderJSON(job: TranscriptionJob) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let payload = ExportPayload(job: job)
        let data = (try? encoder.encode(payload)) ?? Data("{}".utf8)
        return String(decoding: data, as: UTF8.self)
    }

    private func renderSRT(job: TranscriptionJob) -> String {
        let segments = job.transcriptSections.flatMap(\.segments)
        return segments.enumerated().map { index, segment in
            "\(index + 1)\n\(srtTime(segment.start)) --> \(srtTime(segment.end))\n\(displayName(for: segment.speaker, job: job)): \(segment.text)"
        }.joined(separator: "\n\n")
    }

    private func displayName(for speaker: String, job: TranscriptionJob) -> String {
        job.speakerDisplayNames[speaker] ?? speaker
    }

    private func srtTime(_ value: String) -> String {
        value.replacingOccurrences(of: ".", with: ",")
    }
}

private struct ExportPayload: Codable {
    struct SectionPayload: Codable {
        let title: String
        let segments: [TranscriptSegment]
    }

    let id: UUID
    let filename: String
    let status: JobStatus
    let speakerDisplayNames: [String: String]
    let sections: [SectionPayload]

    init(job: TranscriptionJob) {
        self.id = job.id
        self.filename = job.filename
        self.status = job.status
        self.speakerDisplayNames = job.speakerDisplayNames
        self.sections = job.transcriptSections.map { SectionPayload(title: $0.title, segments: $0.segments) }
    }
}
