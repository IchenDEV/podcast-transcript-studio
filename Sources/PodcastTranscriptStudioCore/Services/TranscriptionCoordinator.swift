import Foundation

@MainActor
public final class TranscriptionCoordinator {
    public let configuration: AppConfiguration
    public let jobStore: JobStore
    public let runner: WorkerRunning
    public let parser: TranscriptParser
    public let commandBuilder: WorkerCommandBuilder

    public init(
        configuration: AppConfiguration,
        jobStore: JobStore,
        runner: WorkerRunning = ProcessWorkerRunner(),
        parser: TranscriptParser = TranscriptParser()
    ) {
        self.configuration = configuration
        self.jobStore = jobStore
        self.runner = runner
        self.parser = parser
        self.commandBuilder = WorkerCommandBuilder(configuration: configuration)
    }

    @discardableResult
    public func startTranscription(
        sourceURL: URL,
        jobID: UUID? = nil,
        diarize: Bool = true,
        cleanFillers: Bool = true
    ) async throws -> TranscriptionJob {
        var job = jobID.flatMap { jobStore.job(id: $0) }
            ?? TranscriptionJob(id: jobID ?? UUID(), filename: sourceURL.lastPathComponent, status: .queued)
        job.filename = sourceURL.lastPathComponent
        job.status = .queued
        job.progress = 0.05
        job.progressMessage = "等待转写"
        jobStore.upsert(job)
        jobStore.updateStatus(for: job.id, status: .running)
        jobStore.updateProgress(for: job.id, progress: nil, message: "本地转写中")

        let command = try commandBuilder.makeCommand(job: job, sourceURL: sourceURL, diarize: diarize, cleanFillers: cleanFillers)

        do {
            try await runner.run(command: command)
            let transcriptText = try String(contentsOf: command.outputTextURL, encoding: .utf8)
            let sections = try parser.parse(transcriptText)
            var completed = jobStore.job(id: job.id) ?? job
            completed.status = .completed
            completed.transcriptPath = command.outputTextURL
            completed.logPath = nil
            completed.errorMessage = nil
            completed.progress = nil
            completed.progressMessage = nil
            completed.transcriptSections = sections
            jobStore.upsert(completed)
            return completed
        } catch {
            let logPath = try? writeFailureLog(jobID: job.id, message: error.localizedDescription)
            var failed = jobStore.job(id: job.id) ?? job
            failed.status = .failed
            failed.errorMessage = error.localizedDescription
            failed.logPath = logPath
            failed.progress = nil
            failed.progressMessage = nil
            jobStore.upsert(failed)
            throw error
        }
    }

    private func writeFailureLog(jobID: UUID, message: String) throws -> URL {
        try FileManager.default.createDirectory(at: configuration.logsDirectory, withIntermediateDirectories: true, attributes: nil)
        let logPath = configuration.logsDirectory.appendingPathComponent("\(jobID.uuidString).log")
        let payload = "[\(ISO8601DateFormatter().string(from: Date()))] \(message)\n"
        try payload.write(to: logPath, atomically: true, encoding: .utf8)
        return logPath
    }
}
