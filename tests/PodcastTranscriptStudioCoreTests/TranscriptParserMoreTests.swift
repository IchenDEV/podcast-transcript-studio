import XCTest
@testable import PodcastTranscriptStudioCore

final class TranscriptParserMoreTests: XCTestCase {
    func test_parser_creates_default_section_when_header_missing() throws {
        let input = "[00:00:00.000 - 00:00:01.000] 说话人1: 无分节内容"

        let sections = try TranscriptParser().parse(input)

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].title, "未分节")
    }

    func test_parser_keeps_model_refined_speaker_name() throws {
        let input = "[00:00:00.000 - 00:00:01.000] 张三: 大家好，我是张三"

        let sections = try TranscriptParser().parse(input)

        XCTAssertEqual(sections[0].segments[0].speaker, "张三")
    }
}
