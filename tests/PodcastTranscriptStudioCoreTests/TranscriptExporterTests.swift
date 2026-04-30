import XCTest
@testable import PodcastTranscriptStudioCore

final class TranscriptExporterTests: XCTestCase {
    func test_exporter_writes_txt_with_display_names() throws {
        let config = AppConfiguration.preview(baseDirectory: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString))
        let exporter = TranscriptExporter(configuration: config)
        let segment = TranscriptSegment(start: "00:00:00.000", end: "00:00:03.000", speaker: "说话人1", text: "第一句")
        let section = TranscriptSection(title: "分节1", segments: [segment])
        let job = TranscriptionJob(filename: "episode.m4a", status: .completed, transcriptSections: [section], speakerDisplayNames: ["说话人1": "老王"])

        let url = try exporter.export(job: job, format: .txt, baseFilename: "episode")
        let content = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertTrue(content.contains("【分节1】"))
        XCTAssertTrue(content.contains("老王: 第一句"))
    }

    func test_exporter_writes_srt_numbering() throws {
        let config = AppConfiguration.preview(baseDirectory: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString))
        let exporter = TranscriptExporter(configuration: config)
        let segments = [
            TranscriptSegment(start: "00:00:00.000", end: "00:00:03.000", speaker: "说话人1", text: "第一句"),
            TranscriptSegment(start: "00:00:03.000", end: "00:00:05.500", speaker: "说话人2", text: "第二句"),
        ]
        let job = TranscriptionJob(filename: "episode.m4a", status: .completed, transcriptSections: [TranscriptSection(title: "分节1", segments: segments)])

        let url = try exporter.export(job: job, format: .srt, baseFilename: "episode")
        let content = try String(contentsOf: url, encoding: .utf8)

        XCTAssertTrue(content.contains("1\n00:00:00,000 --> 00:00:03,000"))
        XCTAssertTrue(content.contains("2\n00:00:03,000 --> 00:00:05,500"))
        XCTAssertTrue(content.contains("说话人2: 第二句"))
    }
}
