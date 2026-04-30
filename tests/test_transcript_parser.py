def test_parse_transcript_sections_and_segments():
    from podcast_web.services.parser import parse_transcript_text

    sample = (
        '【分节1】（约 180 秒）\n\n'
        '[00:00:00.000 - 00:00:03.000] 说话人1: 第一段内容\n'
        '[00:00:03.000 - 00:00:06.000] 说话人2: 第二段内容\n'
    )

    document = parse_transcript_text(sample)

    assert len(document.sections) >= 1
    assert document.sections[0].title.startswith('分节1')
    assert document.sections[0].segments[0].speaker.startswith('说话人')
    assert document.sections[0].segments[0].text
    assert document.readable_text
