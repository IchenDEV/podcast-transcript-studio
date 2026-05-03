import XCTest
@testable import PodcastTranscriptStudioCore

final class AppConfigurationTests: XCTestCase {
    func test_app_configuration_builds_expected_directories() {
        let config = AppConfiguration.preview(baseDirectory: URL(fileURLWithPath: "/tmp/PodcastTranscriptStudio"))

        XCTAssertEqual(config.appName, "Podcast Transcript Studio")
        XCTAssertTrue(config.supportDirectory.path.contains("PodcastTranscriptStudio"))
        XCTAssertTrue(config.modelsDirectory.lastPathComponent == "Models")
        XCTAssertTrue(config.modelsDirectory.path.contains("Application Support"))
        XCTAssertTrue(config.bundledModelsDirectory.path.contains("BundledResources"))
        XCTAssertTrue(config.scriptsDirectory.lastPathComponent == "Scripts")
        XCTAssertEqual(config.chineseTextVariant, .simplified)
    }

    func test_app_configuration_uses_directory_overrides() {
        let config = AppConfiguration(
            baseDirectory: URL(fileURLWithPath: "/tmp/PodcastTranscriptStudio"),
            bundledResourcesDirectory: URL(fileURLWithPath: "/tmp/PodcastTranscriptStudio/BundledResources"),
            overrides: AppConfigurationOverrides(
                jobsDirectoryPath: "/tmp/custom/jobs",
                exportsDirectoryPath: "/tmp/custom/exports",
                logsDirectoryPath: "/tmp/custom/logs",
                modelsDirectoryPath: "/tmp/custom/models",
                chineseTextVariant: .traditional
            )
        )

        XCTAssertEqual(config.jobsDirectory.path, "/tmp/custom/jobs")
        XCTAssertEqual(config.exportsDirectory.path, "/tmp/custom/exports")
        XCTAssertEqual(config.logsDirectory.path, "/tmp/custom/logs")
        XCTAssertEqual(config.modelsDirectory.path, "/tmp/custom/models")
        XCTAssertEqual(config.chineseTextVariant, .traditional)
    }

    func test_resolved_python_runtime_finds_development_worker_python_from_bundled_resources() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PodcastTranscriptStudio-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let bundledResourcesDirectory = root
            .appendingPathComponent("dist/Podcast Transcript Studio.app/Contents/Resources/Core.bundle/Resources", isDirectory: true)
        let workerBinDirectory = root.appendingPathComponent(".worker-venv/bin", isDirectory: true)
        try FileManager.default.createDirectory(at: bundledResourcesDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: workerBinDirectory, withIntermediateDirectories: true)
        try Data().write(to: root.appendingPathComponent("Package.swift"))
        let workerPython = workerBinDirectory.appendingPathComponent("python")
        try Data().write(to: workerPython)

        let config = AppConfiguration(
            baseDirectory: root.appendingPathComponent("dist", isDirectory: true),
            bundledResourcesDirectory: bundledResourcesDirectory
        )

        let runtime = config.resolvedPythonRuntime()

        XCTAssertEqual(runtime?.executableURL.standardizedFileURL.path, workerPython.standardizedFileURL.path)
        XCTAssertNil(runtime?.pythonHomeURL)
        XCTAssertNil(runtime?.pythonPathURL)
    }

    func test_resolved_python_runtime_returns_nil_without_packaged_or_development_python() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("PodcastTranscriptStudio-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let bundledResourcesDirectory = root
            .appendingPathComponent("dist/Podcast Transcript Studio.app/Contents/Resources/Core.bundle/Resources", isDirectory: true)
        try FileManager.default.createDirectory(at: bundledResourcesDirectory, withIntermediateDirectories: true)

        let config = AppConfiguration(
            baseDirectory: root.appendingPathComponent("dist", isDirectory: true),
            bundledResourcesDirectory: bundledResourcesDirectory
        )

        XCTAssertNil(config.resolvedPythonRuntime())
    }
}
