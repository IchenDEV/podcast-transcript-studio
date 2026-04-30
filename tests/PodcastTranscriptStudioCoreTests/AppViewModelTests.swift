import XCTest
@testable import PodcastTranscriptStudioCore

@MainActor
final class AppViewModelTests: XCTestCase {
    func test_select_job_and_update_speaker_name() {
        let store = JobStore()
        let segment = TranscriptSegment(start: "00:00:00.000", end: "00:00:01.000", speaker: "说话人1", text: "你好")
        let section = TranscriptSection(title: "分节1", segments: [segment])
        let job = TranscriptionJob(filename: "demo.m4a", status: .completed, transcriptSections: [section])
        store.upsert(job)

        let viewModel = AppViewModel(jobStore: store)
        viewModel.select(jobID: job.id)
        viewModel.renameSpeaker("张鹏", for: "说话人1")

        XCTAssertEqual(viewModel.selectedJob?.id, job.id)
        XCTAssertEqual(viewModel.displayName(for: "说话人1"), "张鹏")
        XCTAssertEqual(store.job(id: job.id)?.speakerDisplayNames["说话人1"], "张鹏")
    }
}
