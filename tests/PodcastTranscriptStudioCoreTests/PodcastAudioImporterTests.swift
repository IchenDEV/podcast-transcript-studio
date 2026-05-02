import XCTest
@testable import PodcastTranscriptStudioCore

final class PodcastAudioImporterTests: XCTestCase {
    func test_resolves_xiaoyuzhou_og_audio() async throws {
        let pages = [
            "https://www.xiaoyuzhoufm.com/episode/demo": Data("""
            <html>
              <head>
                <meta property="og:title" content="Demo Episode" />
                <meta property="og:audio" content="https://media.example.com/demo.mp3" />
              </head>
            </html>
            """.utf8)
        ]
        let importer = makeImporter(pages: pages)

        let resolved = try await importer.resolveAudioURL(from: URL(string: "https://www.xiaoyuzhoufm.com/episode/demo")!)

        XCTAssertEqual(resolved.platform, "xiaoyuzhou")
        XCTAssertEqual(resolved.title, "Demo Episode")
        XCTAssertEqual(resolved.audioURL.absoluteString, "https://media.example.com/demo.mp3")
    }

    func test_resolves_apple_podcast_from_lookup_feed() async throws {
        let pages = [
            "https://podcasts.apple.com/us/podcast/show/id1441474794?i=1000475383420": Data("""
            <html>
              <head><meta property="og:title" content="The Parker Quiz - with Matt Parker" /></head>
            </html>
            """.utf8),
            "https://itunes.apple.com/lookup?id=1441474794&entity=podcast": Data("""
            {"resultCount":1,"results":[{"feedUrl":"https://feeds.example.com/show.xml"}]}
            """.utf8),
            "https://feeds.example.com/show.xml": Data("""
            <rss><channel>
              <item>
                <title>The Parker Quiz - with Matt Parker</title>
                <enclosure url="https://audio.example.com/parker.m4a" type="audio/mp4" />
              </item>
            </channel></rss>
            """.utf8),
        ]
        let importer = makeImporter(pages: pages)

        let resolved = try await importer.resolveAudioURL(
            from: URL(string: "https://podcasts.apple.com/us/podcast/show/id1441474794?i=1000475383420")!
        )

        XCTAssertEqual(resolved.platform, "apple_podcasts")
        XCTAssertEqual(resolved.feedURL?.absoluteString, "https://feeds.example.com/show.xml")
        XCTAssertEqual(resolved.audioURL.absoluteString, "https://audio.example.com/parker.m4a")
    }

    func test_resolves_apple_podcast_when_page_contains_audio_url() async throws {
        let sourceURL = "https://podcasts.apple.com/cn/podcast/%E5%A3%B0%E5%8A%A8%E6%97%A9%E5%92%96%E5%95%A1/id1573189055?i=1000764203947"
        let pages = [
            sourceURL: Data("""
            <html>
              <head>
                <meta property="og:title" content="大厂纷纷立项对标大疆 Pocket" />
              </head>
              <body>
                <script>window.audio = "https:\\/\\/jt.ximalaya.com\\/audio\\/episode.m4a?channel=rss"</script>
              </body>
            </html>
            """.utf8)
        ]
        let importer = makeImporter(pages: pages)

        let resolved = try await importer.resolveAudioURL(from: URL(string: sourceURL)!)

        XCTAssertEqual(resolved.platform, "apple_podcasts")
        XCTAssertEqual(resolved.title, "大厂纷纷立项对标大疆 Pocket")
        XCTAssertEqual(resolved.audioURL.absoluteString, "https://jt.ximalaya.com/audio/episode.m4a?channel=rss")
    }

    func test_resolves_ximalaya_from_public_play_api() async throws {
        let pages = [
            "https://www.ximalaya.com/sound/123456": Data("<html><title>Demo</title></html>".utf8),
            "https://www.ximalaya.com/revision/play/v1/audio?id=123456&ptype=1": Data("""
            {"data":{"src":"https://audio.example.com/ximalaya.mp3","trackName":"Demo"}}
            """.utf8),
        ]
        let importer = makeImporter(pages: pages)

        let resolved = try await importer.resolveAudioURL(from: URL(string: "https://www.ximalaya.com/sound/123456")!)

        XCTAssertEqual(resolved.platform, "ximalaya")
        XCTAssertEqual(resolved.audioURL.absoluteString, "https://audio.example.com/ximalaya.mp3")
    }

    func test_resolves_ximalaya_album_from_public_rss() async throws {
        let pages = [
            "https://www.ximalaya.com/revision/play/v1/audio?id=74118613&ptype=1": Data("{}".utf8),
            "https://www.ximalaya.com/album/74118613.xml": Data("""
            <rss><channel>
              <item>
                <title>Episode 1</title>
                <enclosure url="https://audio.example.com/episode-1.m4a" type="audio/mp4" />
              </item>
            </channel></rss>
            """.utf8),
        ]
        let importer = makeImporter(pages: pages)

        let resolved = try await importer.resolveAudioURL(from: URL(string: "https://www.ximalaya.com/album/74118613")!)

        XCTAssertEqual(resolved.platform, "ximalaya")
        XCTAssertEqual(resolved.feedURL?.absoluteString, "https://www.ximalaya.com/album/74118613.xml")
        XCTAssertEqual(resolved.audioURL.absoluteString, "https://audio.example.com/episode-1.m4a")
    }

    private func makeImporter(pages: [String: Data]) -> PodcastAudioImporter {
        PodcastAudioImporter(configuration: .preview(baseDirectory: URL(fileURLWithPath: NSTemporaryDirectory()))) { url in
            guard let data = pages[url.absoluteString] else {
                throw URLError(.badURL)
            }
            return data
        }
    }
}
