import XCTest
@testable import PodcastTranscriptStudioCore

@MainActor
final class AppViewModelExportTests: XCTestCase {
    func test_export_selected_job_returns_output_file() throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let config = AppConfiguration.preview(baseDirectory: base)
        let store = JobStore()
        let job = TranscriptionJob(
            filename: "episode.m4a",
            status: .completed,
            transcriptSections: [
                TranscriptSection(title: "分节1", segments: [
                    TranscriptSegment(start: "00:00:00.000", end: "00:00:01.000", speaker: "说话人1", text: "你好")
                ])
            ]
        )
        store.upsert(job)
        let viewModel = AppViewModel(jobStore: store, configuration: config)
        viewModel.select(jobID: job.id)

        let url = try viewModel.exportSelectedJob(as: .markdown)
        let content = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(url.lastPathComponent.hasSuffix(".md"))
        XCTAssertTrue(content.contains("## 分节1"))
    }
}
