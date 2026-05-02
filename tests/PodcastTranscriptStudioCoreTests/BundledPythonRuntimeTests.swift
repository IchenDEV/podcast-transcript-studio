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

    func test_worker_command_uses_development_worker_venv_when_bundle_runtime_is_missing() throws {
        let projectRoot = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: projectRoot, withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: projectRoot.appendingPathComponent("Package.swift").path, contents: Data())

        let workerPython = projectRoot.appendingPathComponent(".worker-venv/bin/python")
        try FileManager.default.createDirectory(at: workerPython.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: workerPython.path, contents: Data())

        let resourceRoot = projectRoot
            .appendingPathComponent(".build/arm64-apple-macosx/release/PodcastTranscriptStudio_PodcastTranscriptStudioCore.bundle/Resources", isDirectory: true)
        let config = AppConfiguration(
            baseDirectory: projectRoot,
            bundledResourcesDirectory: resourceRoot
        )

        let command = try WorkerCommandBuilder(configuration: config).makeCommand(
            job: TranscriptionJob(filename: "demo.m4a"),
            sourceURL: URL(fileURLWithPath: "/tmp/demo.m4a"),
            diarize: true,
            cleanFillers: true
        )

        XCTAssertEqual(command.executable, workerPython.path)
        XCTAssertNil(command.environment["PYTHONHOME"])
        XCTAssertNil(command.environment["PYTHONPATH"])
        XCTAssertEqual(command.environment["PYTHONNOUSERSITE"], "1")
    }
}
