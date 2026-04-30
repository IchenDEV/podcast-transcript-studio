import XCTest
@testable import PodcastTranscriptStudioCore

@MainActor
final class AppViewModelMoreTests: XCTestCase {
    func test_load_demo_if_needed_seeds_one_completed_job() {
        let store = JobStore()
        let viewModel = AppViewModel(jobStore: store)

        viewModel.loadDemoIfNeeded()
        viewModel.loadDemoIfNeeded()

        XCTAssertEqual(store.jobs.count, 1)
        XCTAssertEqual(viewModel.selectedJob?.status, .completed)
        XCTAssertEqual(viewModel.selectedJob?.transcriptSections.first?.segments.count, 2)
    }

    func test_display_name_falls_back_to_original_speaker() {
        let store = JobStore()
        let job = TranscriptionJob(filename: "demo.m4a")
        store.upsert(job)
        let viewModel = AppViewModel(jobStore: store)
        viewModel.select(jobID: job.id)

        XCTAssertEqual(viewModel.displayName(for: "说话人9"), "说话人9")
    }
}
