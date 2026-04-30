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
}

private struct FakeAppViewModelWorkerRunner: WorkerRunning {
    let handler: @Sendable (WorkerCommand) throws -> Void

    func run(command: WorkerCommand) async throws {
        try handler(command)
    }
}
