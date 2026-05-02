from packages.podcast_fetcher import resolve_podcast_audio


def test_resolve_xiaoyuzhou_og_audio():
    pages = {
        'https://www.xiaoyuzhoufm.com/episode/abc': b'''
            <html>
              <head>
                <meta property="og:title" content="Demo Episode" />
                <meta property="og:audio" content="https://media.example.com/demo.mp3" />
              </head>
            </html>
        ''',
    }

    resolved = resolve_podcast_audio('https://www.xiaoyuzhoufm.com/episode/abc', read_url=pages.__getitem__)

    assert resolved.platform == 'xiaoyuzhou'
    assert resolved.title == 'Demo Episode'
    assert resolved.audio_url == 'https://media.example.com/demo.mp3'


def test_resolve_apple_podcast_from_lookup_feed():
    pages = {
        'https://podcasts.apple.com/us/podcast/show/id1441474794?i=1000475383420': b'''
            <html><head><meta property="og:title" content="The Parker Quiz - with Matt Parker" /></head></html>
        ''',
        'https://itunes.apple.com/lookup?id=1441474794&entity=podcast': b'''
            {"resultCount":1,"results":[{"feedUrl":"https://feeds.example.com/show.xml"}]}
        ''',
        'https://feeds.example.com/show.xml': b'''
            <rss><channel>
              <item>
                <title>The Parker Quiz - with Matt Parker</title>
                <enclosure url="https://audio.example.com/parker.m4a" type="audio/mp4" />
              </item>
            </channel></rss>
        ''',
    }

    resolved = resolve_podcast_audio(
        'https://podcasts.apple.com/us/podcast/show/id1441474794?i=1000475383420',
        read_url=pages.__getitem__,
    )

    assert resolved.platform == 'apple_podcasts'
    assert resolved.feed_url == 'https://feeds.example.com/show.xml'
    assert resolved.audio_url == 'https://audio.example.com/parker.m4a'


def test_resolve_apple_podcast_when_page_contains_audio_url():
    source_url = (
        'https://podcasts.apple.com/cn/podcast/%E5%A3%B0%E5%8A%A8%E6%97%A9%E5%92%96%E5%95%A1/'
        'id1573189055?i=1000764203947'
    )
    pages = {
        source_url: b'''
            <html>
              <head><meta property="og:title" content="Episode title" /></head>
              <body><script>window.audio = "https:\\/\\/jt.ximalaya.com\\/audio\\/episode.m4a?channel=rss"</script></body>
            </html>
        ''',
    }

    resolved = resolve_podcast_audio(source_url, read_url=pages.__getitem__)

    assert resolved.platform == 'apple_podcasts'
    assert resolved.title == 'Episode title'
    assert resolved.audio_url == 'https://jt.ximalaya.com/audio/episode.m4a?channel=rss'


def test_resolve_ximalaya_from_public_play_api():
    pages = {
        'https://www.ximalaya.com/sound/123456': b'<html><title>Demo</title></html>',
        'https://www.ximalaya.com/revision/play/v1/audio?id=123456&ptype=1': b'''
            {"data":{"src":"https://audio.example.com/ximalaya.mp3","trackName":"Demo"}}
        ''',
    }

    resolved = resolve_podcast_audio('https://www.ximalaya.com/sound/123456', read_url=pages.__getitem__)

    assert resolved.platform == 'ximalaya'
    assert resolved.audio_url == 'https://audio.example.com/ximalaya.mp3'


def test_resolve_ximalaya_album_from_public_rss():
    pages = {
        'https://www.ximalaya.com/album/74118613.xml': b'''
            <rss><channel>
              <item>
                <title>Episode 1</title>
                <enclosure url="https://audio.example.com/episode-1.m4a" type="audio/mp4" />
              </item>
            </channel></rss>
        ''',
    }

    resolved = resolve_podcast_audio('https://www.ximalaya.com/album/74118613', read_url=pages.__getitem__)

    assert resolved.platform == 'ximalaya'
    assert resolved.feed_url == 'https://www.ximalaya.com/album/74118613.xml'
    assert resolved.audio_url == 'https://audio.example.com/episode-1.m4a'
