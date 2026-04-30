import XCTest
@testable import PodcastTranscriptStudioCore

final class AppConfigurationTests: XCTestCase {
    func test_app_configuration_builds_expected_directories() {
        let config = AppConfiguration.preview(baseDirectory: URL(fileURLWithPath: "/tmp/PodcastTranscriptStudio"))

        XCTAssertEqual(config.appName, "Podcast Transcript Studio")
        XCTAssertTrue(config.supportDirectory.path.contains("PodcastTranscriptStudio"))
        XCTAssertTrue(config.modelsDirectory.lastPathComponent == "Models")
        XCTAssertTrue(config.scriptsDirectory.lastPathComponent == "Scripts")
    }
}
