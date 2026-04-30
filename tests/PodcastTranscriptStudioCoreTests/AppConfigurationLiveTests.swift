import XCTest
@testable import PodcastTranscriptStudioCore

final class AppConfigurationLiveTests: XCTestCase {
    func test_live_configuration_uses_bundle_resources() {
        let config = AppConfiguration.live(baseDirectory: URL(fileURLWithPath: "/tmp/PodcastTranscriptStudio"), bundle: .module)

        XCTAssertEqual(config.bundledResourcesDirectory.path, Bundle.module.resourceURL?.path)
        XCTAssertEqual(config.modelsDirectory.path, Bundle.module.resourceURL?.appendingPathComponent("Models").path)
        XCTAssertEqual(config.scriptsDirectory.path, Bundle.module.resourceURL?.appendingPathComponent("Scripts").path)
        XCTAssertEqual(config.pythonHomeURL.path, Bundle.module.resourceURL?.appendingPathComponent("Runtime/python-home").path)
    }
}
