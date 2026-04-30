import XCTest
@testable import PodcastTranscriptStudioCore

final class TranscriptParserTests: XCTestCase {
    func test_parser_builds_sections_and_segments() throws {
        let input = """
        【分节1】（约 180 秒）

        [00:00:00.000 - 00:00:03.000] 说话人1: 第一行
        [00:00:03.000 - 00:00:05.000] 说话人2: 第二行
        """

        let sections = try TranscriptParser().parse(input)

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].title, "分节1")
        XCTAssertEqual(sections[0].segments.count, 2)
        XCTAssertEqual(sections[0].segments[1].speaker, "说话人2")
        XCTAssertEqual(sections[0].segments[1].text, "第二行")
    }
}
