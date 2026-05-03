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
        XCTAssertTrue(command.arguments.contains("--chinese-variant"))
        XCTAssertTrue(command.arguments.contains("simplified"))
        XCTAssertTrue(command.environment["PODCAST_MODELS_DIR"]?.hasSuffix("Models") == true)
        XCTAssertTrue(command.environment["PODCAST_BUNDLED_MODELS_DIR"]?.hasSuffix("Models") == true)
        XCTAssertTrue(command.outputTextURL.path.contains(job.id.uuidString))
        XCTAssertEqual(command.environment["PODCAST_TEXT_MODEL_REPOSITORY"], "Qwen/Qwen3-0.6B")
    }

    func test_command_builder_passes_selected_chinese_variant() throws {
        let config = AppConfiguration(
            baseDirectory: URL(fileURLWithPath: "/tmp/PodcastTranscriptStudio"),
            bundledResourcesDirectory: URL(fileURLWithPath: "/tmp/PodcastTranscriptStudio/BundledResources"),
            overrides: AppConfigurationOverrides(chineseTextVariant: .traditional)
        )

        let command = try WorkerCommandBuilder(configuration: config).makeCommand(
            job: TranscriptionJob(filename: "demo.m4a"),
            sourceURL: URL(fileURLWithPath: "/tmp/input/demo.m4a"),
            diarize: true,
            cleanFillers: true
        )

        let argumentIndex = try XCTUnwrap(command.arguments.firstIndex(of: "--chinese-variant"))
        XCTAssertEqual(command.arguments[argumentIndex + 1], "traditional")
    }

    func test_command_builder_uses_local_models_when_available() throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let config = AppConfiguration.preview(baseDirectory: base)
        let whisper = config.modelsDirectory.appendingPathComponent("whisper-tiny", isDirectory: true)
        let diarization = config.modelsDirectory.appendingPathComponent("speaker-diarization-3.1", isDirectory: true)
        let textModel = config.modelsDirectory.appendingPathComponent("Qwen3-0.6B", isDirectory: true)
        try FileManager.default.createDirectory(at: whisper, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: diarization, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: textModel, withIntermediateDirectories: true)

        let command = try WorkerCommandBuilder(configuration: config).makeCommand(
            job: TranscriptionJob(filename: "demo.m4a"),
            sourceURL: URL(fileURLWithPath: "/tmp/input/demo.m4a"),
            diarize: true,
            cleanFillers: true
        )

        XCTAssertTrue(command.arguments.contains("--asr-model"))
        XCTAssertTrue(command.arguments.contains(whisper.path))
        XCTAssertTrue(command.arguments.contains("--diarization-model"))
        XCTAssertTrue(command.arguments.contains(diarization.path))
        XCTAssertTrue(command.arguments.contains("--text-model"))
        XCTAssertTrue(command.arguments.contains(textModel.path))
    }
}
