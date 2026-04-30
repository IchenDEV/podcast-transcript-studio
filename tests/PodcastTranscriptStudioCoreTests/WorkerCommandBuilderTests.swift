import XCTest
@testable import PodcastTranscriptStudioCore

final class WorkerCommandBuilderTests: XCTestCase {
    func test_command_builder_includes_bundled_resources_and_diarization() throws {
        let config = AppConfiguration.preview(baseDirectory: URL(fileURLWithPath: "/tmp/PodcastTranscriptStudio"))
        let job = TranscriptionJob(filename: "demo.m4a")
        let source = URL(fileURLWithPath: "/tmp/input/demo.m4a")

        let builder = WorkerCommandBuilder(configuration: config)
        let command = try builder.makeCommand(job: job, sourceURL: source, diarize: true, cleanFillers: true)

        XCTAssertEqual(command.executable, "/usr/bin/python3")
        XCTAssertTrue(command.arguments.first?.hasSuffix("Scripts/cli.py") == true)
        XCTAssertTrue(command.arguments.contains("--diarize"))
        XCTAssertTrue(command.arguments.contains(source.path))
        XCTAssertTrue(command.arguments.contains("--preset"))
        XCTAssertTrue(command.arguments.contains("balanced"))
        XCTAssertTrue(command.environment["PODCAST_MODELS_DIR"]?.hasSuffix("Models") == true)
        XCTAssertTrue(command.outputTextURL.path.contains(job.id.uuidString))
    }
}
