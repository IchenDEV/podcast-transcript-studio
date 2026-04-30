import XCTest
@testable import PodcastTranscriptStudioCore

final class ExportFormatTests: XCTestCase {
    func test_export_format_builds_filename_suffix() {
        XCTAssertEqual(ExportFormat.txt.outputFilename(base: "episode-1"), "episode-1.txt")
        XCTAssertEqual(ExportFormat.json.outputFilename(base: "episode-1"), "episode-1.json")
        XCTAssertEqual(ExportFormat.markdown.outputFilename(base: "episode-1"), "episode-1.md")
    }
}
