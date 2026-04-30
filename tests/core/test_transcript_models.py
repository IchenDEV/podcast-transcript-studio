from packages.core.transcript import TranscriptDocument, TranscriptSection, TranscriptSegment, build_readable_transcript


def test_build_readable_transcript_groups_segments_by_speaker():
    sections = [
        TranscriptSection(
            title='分节1',
            segments=[
                TranscriptSegment(start='00:00:00.000', end='00:00:01.000', speaker='说话人1', text='你好'),
                TranscriptSegment(start='00:00:01.000', end='00:00:02.000', speaker='说话人1', text='今天聊产品'),
                TranscriptSegment(start='00:00:03.000', end='00:00:04.000', speaker='说话人2', text='好的'),
            ],
        )
    ]

    readable = build_readable_transcript(sections)

    assert '说话人1：你好 今天聊产品' in readable
    assert '说话人2：好的' in readable


def test_transcript_document_from_sections_keeps_readable_text():
    sections = [
        TranscriptSection(
            title='分节1',
            segments=[
                TranscriptSegment(start='00:00:00.000', end='00:00:01.000', speaker='说话人1', text='测试内容'),
            ],
        )
    ]

    document = TranscriptDocument.from_sections(sections)

    assert document.sections[0].title == '分节1'
    assert document.readable_text == '说话人1：测试内容'
