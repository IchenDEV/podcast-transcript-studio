import XCTest
@testable import PodcastTranscriptStudioCore

final class ProcessWorkerRunnerTests: XCTestCase {
    func test_runner_executes_command_successfully() async throws {
        let temp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let outputText = temp.appendingPathComponent("job/transcript.txt")
        let outputJSON = temp.appendingPathComponent("job/transcript.json")
        let command = WorkerCommand(
            executable: "/usr/bin/env",
            arguments: [
                "bash", "-lc",
                "echo ok > \"\(outputText.path)\"; echo '{}' > \"\(outputJSON.path)\""
            ],
            environment: [:],
            outputTextURL: outputText,
            outputJSONURL: outputJSON
        )

        try await ProcessWorkerRunner().run(command: command)

        XCTAssertEqual(try String(contentsOf: outputText, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines), "ok")
    }

    func test_runner_throws_on_non_zero_exit() async {
        let temp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let command = WorkerCommand(
            executable: "/usr/bin/env",
            arguments: ["bash", "-lc", "echo boom 1>&2; exit 7"],
            environment: [:],
            outputTextURL: temp.appendingPathComponent("job/transcript.txt"),
            outputJSONURL: temp.appendingPathComponent("job/transcript.json")
        )

        do {
            try await ProcessWorkerRunner().run(command: command)
            XCTFail("expected failure")
        } catch let error as ProcessWorkerRunnerError {
            switch error {
            case let .nonZeroExit(code, stderr):
                XCTAssertEqual(code, 7)
                XCTAssertTrue(stderr.contains("boom"))
            }
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }
}
