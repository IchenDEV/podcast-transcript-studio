from types import SimpleNamespace


def test_apply_preset_defaults_uses_balanced_values():
    from packages.python_worker.config import apply_preset_defaults

    args = SimpleNamespace(
        preset='balanced',
        asr_provider=None,
        asr_model=None,
        section_seconds=0,
        chunk_length=0,
        batch_size=0,
        beam_size=0,
        language='zh',
        vad=False,
        no_vad=False,
    )

    updated = apply_preset_defaults(args)

    assert updated.asr_model == 'openai/whisper-base'
    assert updated.asr_provider == 'whisper'
    assert updated.section_seconds == 240
    assert updated.chunk_length == 30
    assert updated.batch_size == 4
    assert updated.beam_size == 5
    assert updated.vad is True


def test_clean_text_removes_fillers_without_static_term_replacements():
    from packages.python_worker.text_cleanup import clean_text

    cleaned = clean_text('  嗯 我觉得 agin 这个这个 skills 挺重要的  ')

    assert cleaned == 'agin这个skills挺重要的'


def test_parse_refinement_response_reads_model_json():
    from packages.python_worker.text_refinement import parse_refinement_response

    raw = '''
    ```json
    {
      "speaker_display_names": {"说话人1": "张三"},
      "segments": [
        {"index": 0, "text": "大家好，我是张三，Agent 这个 Skills 挺重要的。"}
      ]
    }
    ```
    '''

    result = parse_refinement_response(raw)

    assert result.speaker_display_names == {'说话人1': '张三'}
    assert result.corrected_texts == {0: '大家好，我是张三，Agent 这个 Skills 挺重要的。'}


def test_apply_refinement_to_utterances_uses_model_names_and_texts():
    from packages.python_worker.models import ASRUtterance
    from packages.python_worker.text_refinement import TranscriptRefinement, apply_refinement_to_utterances

    utterances = [
        ASRUtterance(start=0.0, end=2.0, speaker='说话人1', text='大家好，我是张三，agin 这个 skills 挺重要的。')
    ]
    refinement = TranscriptRefinement(
        speaker_display_names={'说话人1': '张三'},
        corrected_texts={0: '大家好，我是张三，Agent 这个 Skills 挺重要的。'},
    )

    apply_refinement_to_utterances(utterances, refinement)

    assert utterances[0].speaker == '张三'
    assert utterances[0].text == '大家好，我是张三，Agent 这个 Skills 挺重要的。'


def test_qwen_refiner_sends_segments_to_generation_backend():
    from packages.python_worker.models import ASRUtterance
    from packages.python_worker.text_refinement import QwenTranscriptRefiner

    class FakeBackend:
        def __init__(self):
            self.prompt = ''

        def generate(self, prompt: str) -> str:
            self.prompt = prompt
            return '{"speaker_display_names":{"说话人1":"张三"},"segments":[{"index":0,"text":"大家好，我是张三，Agent 这个 Skills 挺重要的。"}]}'

    backend = FakeBackend()
    refiner = QwenTranscriptRefiner(model_ref='Qwen/Qwen3-0.6B', backend=backend)

    result = refiner.refine([
        ASRUtterance(start=0.0, end=2.0, speaker='说话人1', text='大家好，我是张三，agin 这个 skills 挺重要的。')
    ])

    assert '输入片段' in backend.prompt
    assert '说话人1' in backend.prompt
    assert result.speaker_display_names == {'说话人1': '张三'}
    assert result.corrected_texts[0] == '大家好，我是张三，Agent 这个 Skills 挺重要的。'


def test_qwen_refiner_rejects_large_sentence_rewrites():
    from packages.python_worker.models import ASRUtterance
    from packages.python_worker.text_refinement import QwenTranscriptRefiner

    class FakeBackend:
        def generate(self, prompt: str) -> str:
            if '姓名识别' in prompt:
                return '{"speaker_display_names":{"说话人1":"张三"}}'
            return '{"speaker_display_names":{},"segments":[{"index":0,"text":"大家好，我是张三，这技能很重要。"}]}'

    refiner = QwenTranscriptRefiner(model_ref='Qwen/Qwen3-0.6B', backend=FakeBackend())
    result = refiner.refine([
        ASRUtterance(start=0.0, end=2.0, speaker='说话人1', text='大家好，我是张三，agin 这个 skills 挺重要的。')
    ])

    assert result.speaker_display_names == {'说话人1': '张三'}
    assert result.corrected_texts == {}


def test_clean_text_defaults_to_simplified_chinese():
    from packages.python_worker.text_cleanup import clean_text

    cleaned = clean_text('開始體驗臺灣節目')

    assert cleaned == '开始体验台湾节目'


def test_clean_text_can_keep_traditional_chinese():
    from packages.python_worker.text_cleanup import clean_text

    cleaned = clean_text('開始體驗臺灣節目', chinese_variant='traditional')

    assert cleaned == '開始體驗臺灣節目'
