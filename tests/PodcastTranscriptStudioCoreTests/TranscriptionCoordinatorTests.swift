import XCTest
@testable import PodcastTranscriptStudioCore

@MainActor
final class TranscriptionCoordinatorTests: XCTestCase {
    func test_start_transcription_marks_job_completed_and_parses_output() async throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let configuration = AppConfiguration.preview(baseDirectory: base)
        let store = JobStore()
        let runner = FakeWorkerRunner { command in
            try FileManager.default.createDirectory(at: command.outputTextURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try "【分节1】\n\n[00:00:00.000 - 00:00:02.000] 说话人1: 测试内容\n".write(to: command.outputTextURL, atomically: true, encoding: .utf8)
            try "{}".write(to: command.outputJSONURL, atomically: true, encoding: .utf8)
        }
        let coordinator = TranscriptionCoordinator(configuration: configuration, jobStore: store, runner: runner)
        let source = URL(fileURLWithPath: "/tmp/demo.m4a")

        let job = try await coordinator.startTranscription(sourceURL: source)

        XCTAssertEqual(job.status, .completed)
        XCTAssertEqual(store.jobs.count, 1)
        XCTAssertEqual(store.jobs[0].status, .completed)
        XCTAssertEqual(store.jobs[0].transcriptSections.first?.segments.first?.text, "测试内容")
        XCTAssertEqual(store.jobs[0].transcriptPath?.lastPathComponent, "transcript.txt")
    }

    func test_start_transcription_marks_job_failed_when_runner_errors() async throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let configuration = AppConfiguration.preview(baseDirectory: base)
        let store = JobStore()
        let runner = FakeWorkerRunner { _ in
            throw FakeWorkerError.boom
        }
        let coordinator = TranscriptionCoordinator(configuration: configuration, jobStore: store, runner: runner)

        do {
            _ = try await coordinator.startTranscription(sourceURL: URL(fileURLWithPath: "/tmp/demo.m4a"))
            XCTFail("expected failure")
        } catch {
            XCTAssertEqual(store.jobs.count, 1)
            XCTAssertEqual(store.jobs[0].status, .failed)
            XCTAssertEqual(store.jobs[0].errorMessage, "boom")
            XCTAssertNotNil(store.jobs[0].logPath)
            if let logPath = store.jobs[0].logPath {
                let log = try String(contentsOf: logPath, encoding: .utf8)
                XCTAssertTrue(log.contains("boom"))
            }
        }
    }
}

private enum FakeWorkerError: Error, LocalizedError {
    case boom

    var errorDescription: String? {
        switch self {
        case .boom: return "boom"
        }
    }
}

private struct FakeWorkerRunner: WorkerRunning {
    let handler: @Sendable (WorkerCommand) throws -> Void

    func run(command: WorkerCommand) async throws {
        try handler(command)
    }
}
