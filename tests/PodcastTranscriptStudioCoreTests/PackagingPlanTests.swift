import XCTest
@testable import PodcastTranscriptStudioCore

final class PackagingPlanTests: XCTestCase {
    func test_packaging_plan_lists_required_model_repositories() {
        let plan = PackagingPlan.default

        XCTAssertTrue(plan.requiredModelRepositories.contains("pyannote/speaker-diarization-3.1"))
        XCTAssertTrue(plan.requiredModelRepositories.contains("pyannote/segmentation-3.0"))
        XCTAssertTrue(plan.requiredModelRepositories.contains("pyannote/wespeaker-voxceleb-resnet34-LM"))
        XCTAssertEqual(plan.defaultASRModel, "openai/whisper-tiny")
    }
}
