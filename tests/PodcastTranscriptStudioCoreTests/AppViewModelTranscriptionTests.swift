import XCTest
@testable import PodcastTranscriptStudioCore

@MainActor
final class AppViewModelTranscriptionTests: XCTestCase {
    func test_start_transcription_selects_completed_job() async throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let configuration = AppConfiguration.preview(baseDirectory: base)
        let store = JobStore()
        let runner = FakeAppViewModelWorkerRunner { command in
            try FileManager.default.createDirectory(at: command.outputTextURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "【分节1】\n\n[00:00:00.000 - 00:00:02.000] 说话人1: Hello\n".write(to: command.outputTextURL, atomically: true, encoding: .utf8)
            try "{}".write(to: command.outputJSONURL, atomically: true, encoding: .utf8)
        }
        let coordinator = TranscriptionCoordinator(configuration: configuration, jobStore: store, runner: runner)
        let viewModel = AppViewModel(jobStore: store, configuration: configuration, coordinator: coordinator)

        try await viewModel.startTranscription(sourceURL: URL(fileURLWithPath: "/tmp/demo.m4a"))

        XCTAssertEqual(viewModel.selectedJob?.status, .completed)
        XCTAssertEqual(viewModel.selectedJob?.filename, "demo.m4a")
        XCTAssertEqual(viewModel.selectedJob?.transcriptSections.first?.segments.first?.text, "Hello")
    }

    func test_start_podcast_transcription_shows_running_job_before_import_finishes() async throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let configuration = AppConfiguration.preview(baseDirectory: base)
        let store = JobStore()
        let runner = FakeAppViewModelWorkerRunner { command in
            try FileManager.default.createDirectory(at: command.outputTextURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "【分节1】\n\n[00:00:00.000 - 00:00:02.000] 说话人1: Link result\n".write(to: command.outputTextURL, atomically: true, encoding: .utf8)
            try "{}".write(to: command.outputJSONURL, atomically: true, encoding: .utf8)
        }
        let coordinator = TranscriptionCoordinator(configuration: configuration, jobStore: store, runner: runner)
        let importer = PausingPodcastImporter()
        let viewModel = AppViewModel(
            jobStore: store,
            configuration: configuration,
            coordinator: coordinator,
            podcastImporter: importer
        )
        let importStarted = expectation(description: "import started")
        importer.onStarted = {
            importStarted.fulfill()
        }

        let task = Task {
            try await viewModel.startTranscription(podcastURL: URL(string: "https://podcast.example.com/episode")!)
        }

        await fulfillment(of: [importStarted], timeout: 1.0)
        XCTAssertEqual(store.jobs.count, 1)
        XCTAssertEqual(store.jobs[0].status, .running)
        XCTAssertEqual(store.jobs[0].filename, "podcast.example.com")
        XCTAssertEqual(store.jobs[0].progressMessage, "下载音频")
        XCTAssertEqual(viewModel.selectedJobID, store.jobs[0].id)

        importer.finish(with: URL(fileURLWithPath: "/tmp/link-audio.m4a"))
        try await task.value

        XCTAssertEqual(store.jobs.count, 1)
        XCTAssertEqual(viewModel.selectedJob?.filename, "link-audio.m4a")
        XCTAssertEqual(viewModel.selectedJob?.status, .completed)
    }
}

private struct FakeAppViewModelWorkerRunner: WorkerRunning {
    let handler: @Sendable (WorkerCommand) throws -> Void

    func run(command: WorkerCommand) async throws {
        try handler(command)
    }
}

private final class PausingPodcastImporter: PodcastAudioImporting, @unchecked Sendable {
    var onStarted: (() -> Void)?
    private var continuation: CheckedContinuation<URL, Error>?

    func importAudio(from pageURL: URL) async throws -> URL {
        onStarted?()
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func finish(with url: URL) {
        continuation?.resume(returning: url)
        continuation = nil
    }
}
