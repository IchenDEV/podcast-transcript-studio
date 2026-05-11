import Foundation

@MainActor
public final class AppViewModel: ObservableObject {
    @Published public private(set) var selectedJobID: UUID?
    @Published public private(set) var isRunningJob = false
    @Published public private(set) var configuration: AppConfiguration
    @Published public private(set) var modelDownloadState = ModelDownloadState()
    public let jobStore: JobStore
    private var exporter: TranscriptExporter
    private var coordinator: TranscriptionCoordinator
    private var repository: JobStoreRepository
    private var podcastImporter: PodcastAudioImporting

    public init(
        jobStore: JobStore = JobStore(),
        configuration: AppConfiguration = .preview(baseDirectory: URL(fileURLWithPath: NSHomeDirectory())),
        coordinator: TranscriptionCoordinator? = nil,
        repository: JobStoreRepository? = nil,
        podcastImporter: PodcastAudioImporting? = nil
    ) {
        self.jobStore = jobStore
        self.configuration = configuration
        self.exporter = TranscriptExporter(configuration: configuration)
        self.repository = repository ?? JobStoreRepository(configuration: configuration)
        self.coordinator = coordinator ?? TranscriptionCoordinator(configuration: configuration, jobStore: jobStore)
        self.podcastImporter = podcastImporter ?? PodcastAudioImporter(configuration: configuration)
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

    public var modelAssetStatuses: [ModelAssetStatus] {
        ModelDownloadManager(configuration: configuration).statuses()
    }

    public func exportSelectedJob(as format: ExportFormat) throws -> URL {
        guard let job = selectedJob else {
            throw AppViewModelError.noSelectedJob
        }
        let basename = URL(fileURLWithPath: job.filename).deletingPathExtension().lastPathComponent
        return try exporter.export(job: job, format: format, baseFilename: basename)
    }

    public func startTranscription(
        sourceURL: URL,
        diarize: Bool = true,
        cleanFillers: Bool = true,
        mode: TranscriptionMode = .standard
    ) async throws {
        isRunningJob = true
        defer { isRunningJob = false }
        let job = TranscriptionJob(
            filename: sourceURL.lastPathComponent,
            status: .running,
            progress: 0.05,
            progressMessage: "等待转写"
        )
        jobStore.upsert(job)
        selectedJobID = job.id
        objectWillChange.send()
        try? persistJobs()

        do {
            updateJobProgress(job.id, progress: nil, message: "本地转写中")
            _ = try await coordinator.startTranscription(
                sourceURL: sourceURL,
                jobID: job.id,
                diarize: diarize,
                cleanFillers: cleanFillers,
                mode: mode
            )
            objectWillChange.send()
            try persistJobs()
        } catch {
            objectWillChange.send()
            try? persistJobs()
            throw error
        }
    }

    public func startTranscription(
        podcastURL: URL,
        diarize: Bool = true,
        cleanFillers: Bool = true,
        mode: TranscriptionMode = .standard
    ) async throws {
        isRunningJob = true
        defer { isRunningJob = false }
        let job = TranscriptionJob(
            filename: podcastDisplayName(for: podcastURL),
            status: .running,
            progress: 0.08,
            progressMessage: "解析链接"
        )
        jobStore.upsert(job)
        selectedJobID = job.id
        objectWillChange.send()
        try? persistJobs()

        do {
            updateJobProgress(job.id, progress: 0.18, message: "下载音频")
            let sourceURL = try await podcastImporter.importAudio(from: podcastURL)
            jobStore.updateFilename(for: job.id, filename: sourceURL.lastPathComponent)
            updateJobProgress(job.id, progress: nil, message: "本地转写中")
            _ = try await coordinator.startTranscription(
                sourceURL: sourceURL,
                jobID: job.id,
                diarize: diarize,
                cleanFillers: cleanFillers,
                mode: mode
            )
            objectWillChange.send()
            try persistJobs()
        } catch {
            markJobFailed(job.id, message: error.localizedDescription)
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

    public func updateConfiguration(overrides: AppConfigurationOverrides) throws {
        try AppConfigurationStore.save(overrides)
        let updated = AppConfiguration.live(baseDirectory: configuration.baseDirectory, bundle: .module)
        try applyConfiguration(updated)
    }

    public func resetConfiguration() throws {
        AppConfigurationStore.reset()
        let updated = AppConfiguration.live(baseDirectory: configuration.baseDirectory, bundle: .module)
        try applyConfiguration(updated)
    }

    public func downloadModels(huggingFaceToken: String?) async {
        guard !modelDownloadState.isRunning else { return }
        modelDownloadState = ModelDownloadState(phase: .running, message: "正在下载模型")
        do {
            let output = try await ModelDownloadManager(configuration: configuration).downloadAll(huggingFaceToken: huggingFaceToken)
            modelDownloadState = ModelDownloadState(phase: .succeeded, message: output)
        } catch {
            modelDownloadState = ModelDownloadState(phase: .failed, message: error.localizedDescription)
        }
    }

    private func persistJobs() throws {
        try repository.save(jobs: jobStore.jobs)
    }

    private func applyConfiguration(_ configuration: AppConfiguration) throws {
        self.configuration = configuration
        self.exporter = TranscriptExporter(configuration: configuration)
        self.repository = JobStoreRepository(configuration: configuration)
        self.coordinator = TranscriptionCoordinator(configuration: configuration, jobStore: jobStore)
        self.podcastImporter = PodcastAudioImporter(configuration: configuration)
        try FileManager.default.createDirectory(at: configuration.jobsDirectory, withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.createDirectory(at: configuration.exportsDirectory, withIntermediateDirectories: true, attributes: nil)
        try FileManager.default.createDirectory(at: configuration.logsDirectory, withIntermediateDirectories: true, attributes: nil)
    }

    private func updateJobProgress(_ jobID: UUID, progress: Double?, message: String?) {
        jobStore.updateProgress(for: jobID, progress: progress, message: message)
        objectWillChange.send()
        try? persistJobs()
    }

    private func markJobFailed(_ jobID: UUID, message: String) {
        guard var failed = jobStore.job(id: jobID) else { return }
        failed.status = .failed
        failed.errorMessage = message
        failed.progress = nil
        failed.progressMessage = nil
        jobStore.upsert(failed)
        objectWillChange.send()
    }

    private func podcastDisplayName(for url: URL) -> String {
        if let host = url.host, !host.isEmpty {
            return host
        }
        let pathName = url.lastPathComponent
        return pathName.isEmpty ? "播客链接" : pathName
    }
}

public enum AppViewModelError: Error {
    case noSelectedJob
}
