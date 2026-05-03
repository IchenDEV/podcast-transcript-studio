import Foundation

@MainActor
public final class JobStore {
    private(set) public var jobs: [TranscriptionJob] = []

    public init() {}

    public func replaceAll(with jobs: [TranscriptionJob]) {
        self.jobs = jobs.sorted { $0.createdAt > $1.createdAt }
    }

    public func upsert(_ job: TranscriptionJob) {
        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[index] = job
        } else {
            jobs.append(job)
        }
        jobs.sort { $0.createdAt > $1.createdAt }
    }

    public func updateStatus(for id: UUID, status: JobStatus) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].status = status
    }

    public func updateProgress(for id: UUID, progress: Double?, message: String?) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].progress = progress
        jobs[index].progressMessage = message
    }

    public func updateFilename(for id: UUID, filename: String) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].filename = filename
    }

    public func updateSpeakerName(for id: UUID, speaker: String, displayName: String) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].speakerDisplayNames[speaker] = displayName
    }

    public func job(id: UUID) -> TranscriptionJob? {
        jobs.first(where: { $0.id == id })
    }
}
