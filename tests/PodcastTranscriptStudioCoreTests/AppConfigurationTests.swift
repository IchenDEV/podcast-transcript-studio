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
    }

    func test_app_configuration_uses_directory_overrides() {
        let config = AppConfiguration(
            baseDirectory: URL(fileURLWithPath: "/tmp/PodcastTranscriptStudio"),
            bundledResourcesDirectory: URL(fileURLWithPath: "/tmp/PodcastTranscriptStudio/BundledResources"),
            overrides: AppConfigurationOverrides(
                jobsDirectoryPath: "/tmp/custom/jobs",
                exportsDirectoryPath: "/tmp/custom/exports",
                logsDirectoryPath: "/tmp/custom/logs",
                modelsDirectoryPath: "/tmp/custom/models"
            )
        )

        XCTAssertEqual(config.jobsDirectory.path, "/tmp/custom/jobs")
        XCTAssertEqual(config.exportsDirectory.path, "/tmp/custom/exports")
        XCTAssertEqual(config.logsDirectory.path, "/tmp/custom/logs")
        XCTAssertEqual(config.modelsDirectory.path, "/tmp/custom/models")
    }
}
