import XCTest
@testable import PodcastTranscriptStudioCore

final class AppBundlePlanTests: XCTestCase {
    func test_plan_builds_expected_bundle_layout() {
        let root = URL(fileURLWithPath: "/tmp/dist")
        let plan = AppBundlePlan(appName: "Podcast Transcript Studio", outputRoot: root)

        XCTAssertEqual(plan.appBundleURL.path, "/tmp/dist/Podcast Transcript Studio.app")
        XCTAssertEqual(plan.contentsURL.path, "/tmp/dist/Podcast Transcript Studio.app/Contents")
        XCTAssertEqual(plan.macosExecutableURL.path, "/tmp/dist/Podcast Transcript Studio.app/Contents/MacOS/PodcastTranscriptStudioApp")
        XCTAssertEqual(plan.resourcesURL.path, "/tmp/dist/Podcast Transcript Studio.app/Contents/Resources")
        XCTAssertEqual(plan.infoPlistURL.path, "/tmp/dist/Podcast Transcript Studio.app/Contents/Info.plist")
    }
}
