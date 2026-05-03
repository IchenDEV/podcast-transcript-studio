import Foundation

public enum JobStatus: String, Codable, Sendable, Equatable {
    case queued
    case running
    case completed
    case failed
}

public struct TranscriptSegment: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var start: String
    public var end: String
    public var speaker: String
    public var text: String

    public init(id: UUID = UUID(), start: String, end: String, speaker: String, text: String) {
        self.id = id
        self.start = start
        self.end = end
        self.speaker = speaker
        self.text = text
    }
}

public struct TranscriptSection: Codable, Equatable, Sendable, Identifiable {
    public let id: UUID
    public var title: String
    public var segments: [TranscriptSegment]

    public init(id: UUID = UUID(), title: String, segments: [TranscriptSegment] = []) {
        self.id = id
        self.title = title
        self.segments = segments
    }
}

public struct TranscriptionJob: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var filename: String
    public var status: JobStatus
    public var createdAt: Date
    public var transcriptPath: URL?
    public var logPath: URL?
    public var errorMessage: String?
    public var progress: Double?
    public var progressMessage: String?
    public var transcriptSections: [TranscriptSection]
    public var speakerDisplayNames: [String: String]

    public init(
        id: UUID = UUID(),
        filename: String,
        status: JobStatus = .queued,
        createdAt: Date = .now,
        transcriptPath: URL? = nil,
        logPath: URL? = nil,
        errorMessage: String? = nil,
        progress: Double? = nil,
        progressMessage: String? = nil,
        transcriptSections: [TranscriptSection] = [],
        speakerDisplayNames: [String: String] = [:]
    ) {
        self.id = id
        self.filename = filename
        self.status = status
        self.createdAt = createdAt
        self.transcriptPath = transcriptPath
        self.logPath = logPath
        self.errorMessage = errorMessage
        self.progress = progress
        self.progressMessage = progressMessage
        self.transcriptSections = transcriptSections
        self.speakerDisplayNames = speakerDisplayNames
    }
}
