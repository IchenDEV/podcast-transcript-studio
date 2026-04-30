import Foundation

@MainActor
public final class AppViewModel: ObservableObject {
    @Published public private(set) var selectedJobID: UUID?
    @Published public private(set) var isRunningJob = false
    public let jobStore: JobStore
    public let configuration: AppConfiguration
    private let exporter: TranscriptExporter
    private let coordinator: TranscriptionCoordinator
    private let repository: JobStoreRepository

    public init(
        jobStore: JobStore = JobStore(),
        configuration: AppConfiguration = .preview(baseDirectory: URL(fileURLWithPath: NSHomeDirectory())),
        coordinator: TranscriptionCoordinator? = nil,
        repository: JobStoreRepository? = nil
    ) {
        self.jobStore = jobStore
        self.configuration = configuration
        self.exporter = TranscriptExporter(configuration: configuration)
        self.repository = repository ?? JobStoreRepository(configuration: configuration)
        self.coordinator = coordinator ?? TranscriptionCoordinator(configuration: configuration, jobStore: jobStore)
    }

    public var selectedJob: TranscriptionJob? {
        guard let selectedJobID else { return nil }
        return jobStore.job(id: selectedJobID)
    }

    public func select(jobID: UUID?) {
        selectedJobID = jobID
    }

    public func renameSpeaker(_ displayName: String, for speaker: String) {
        guard let selectedJobID else { return }
        jobStore.updateSpeakerName(for: selectedJobID, speaker: speaker, displayName: displayName)
        try? persistJobs()
    }

    public func displayName(for speaker: String) -> String {
        selectedJob?.speakerDisplayNames[speaker] ?? speaker
    }

    public func exportSelectedJob(as format: ExportFormat) throws -> URL {
        guard let job = selectedJob else {
            throw AppViewModelError.noSelectedJob
        }
        let basename = URL(fileURLWithPath: job.filename).deletingPathExtension().lastPathComponent
        return try exporter.export(job: job, format: format, baseFilename: basename)
    }

    public func startTranscription(sourceURL: URL, diarize: Bool = true, cleanFillers: Bool = true) async throws {
        isRunningJob = true
        defer { isRunningJob = false }
        do {
            let job = try await coordinator.startTranscription(sourceURL: sourceURL, diarize: diarize, cleanFillers: cleanFillers)
            selectedJobID = job.id
            try persistJobs()
        } catch {
            try? persistJobs()
            throw error
        }
    }

    public func bootstrap() throws {
        let jobs = try repository.loadJobs()
        guard !jobs.isEmpty else { return }
        jobStore.replaceAll(with: jobs)
        selectedJobID = jobs.first?.id
    }

    public func loadDemoIfNeeded() {
        guard jobStore.jobs.isEmpty else { return }
        let segments = [
            TranscriptSegment(start: "00:00:00.000", end: "00:00:05.000", speaker: "说话人1", text: "欢迎来到 Podcast Transcript Studio。"),
            TranscriptSegment(start: "00:00:05.000", end: "00:00:09.000", speaker: "说话人2", text: "这里展示离线播客逐字稿结果。"),
        ]
        let job = TranscriptionJob(filename: "demo.m4a", status: .completed, transcriptSections: [TranscriptSection(title: "分节1", segments: segments)])
        jobStore.upsert(job)
        selectedJobID = job.id
        try? persistJobs()
    }

    private func persistJobs() throws {
        try repository.save(jobs: jobStore.jobs)
    }
}

public enum AppViewModelError: Error {
    case noSelectedJob
}
