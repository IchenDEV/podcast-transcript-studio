import XCTest
@testable import PodcastTranscriptStudioCore

final class WorkerCommandBuilderMoreTests: XCTestCase {
    func test_command_builder_can_disable_cleaning() throws {
        let config = AppConfiguration.preview(baseDirectory: URL(fileURLWithPath: "/tmp/PodcastTranscriptStudio"))
        let job = TranscriptionJob(filename: "demo.m4a")
        let source = URL(fileURLWithPath: "/tmp/input/demo.m4a")

        let command = try WorkerCommandBuilder(configuration: config).makeCommand(job: job, sourceURL: source, diarize: false, cleanFillers: false)

        XCTAssertTrue(command.arguments.contains("--keep-fillers"))
        XCTAssertFalse(command.arguments.contains("--diarize"))
        XCTAssertTrue(command.arguments.contains("balanced"))
    }
}
