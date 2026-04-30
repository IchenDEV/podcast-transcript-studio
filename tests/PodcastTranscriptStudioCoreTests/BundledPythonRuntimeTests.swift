import XCTest
@testable import PodcastTranscriptStudioCore

final class BundledPythonRuntimeTests: XCTestCase {
    func test_worker_command_prefers_bundled_python_runtime() throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let config = AppConfiguration.preview(baseDirectory: base)
        let python = config.pythonExecutableURL
        try FileManager.default.createDirectory(at: python.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: python.path, contents: Data())

        let command = try WorkerCommandBuilder(configuration: config).makeCommand(
            job: TranscriptionJob(filename: "demo.m4a"),
            sourceURL: URL(fileURLWithPath: "/tmp/demo.m4a"),
            diarize: true,
            cleanFillers: true
        )

        XCTAssertEqual(command.executable, python.path)
        XCTAssertEqual(command.environment["PYTHONHOME"], config.pythonHomeURL.path)
        XCTAssertEqual(command.environment["PYTHONPATH"], config.pythonSitePackagesURL.path)
        XCTAssertEqual(command.environment["PYTHONNOUSERSITE"], "1")
    }
}
