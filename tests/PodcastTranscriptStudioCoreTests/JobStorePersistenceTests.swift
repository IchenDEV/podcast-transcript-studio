import XCTest
@testable import PodcastTranscriptStudioCore

final class JobStorePersistenceTests: XCTestCase {
    func test_repository_saves_and_loads_jobs() throws {
        let base = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let configuration = AppConfiguration.preview(baseDirectory: base)
        let repository = JobStoreRepository(configuration: configuration)
        let jobs = [
            TranscriptionJob(
                filename: "episode.m4a",
                status: .completed,
                transcriptSections: [
                    TranscriptSection(title: "分节1", segments: [
                        TranscriptSegment(start: "00:00:00.000", end: "00:00:01.000", speaker: "说话人1", text: "你好")
                    ])
                ],
                speakerDisplayNames: ["说话人1": "主持人"]
            )
        ]

        try repository.save(jobs: jobs)
        let loaded = try repository.loadJobs()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded[0].filename, "episode.m4a")
        XCTAssertEqual(loaded[0].speakerDisplayNames["说话人1"], "主持人")
    }
}
