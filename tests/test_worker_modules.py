from types import SimpleNamespace


def test_apply_preset_defaults_uses_balanced_values():
    from packages.python_worker.config import apply_preset_defaults

    args = SimpleNamespace(
        preset='balanced',
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
    assert updated.section_seconds == 240
    assert updated.chunk_length == 30
    assert updated.batch_size == 4
    assert updated.beam_size == 5
    assert updated.vad is True


def test_clean_text_normalizes_terms_and_fillers():
    from packages.python_worker.text_cleanup import clean_text

    cleaned = clean_text('  嗯 我觉得 agin 这个这个 skills 挺重要的  ')

    assert cleaned == 'Agent这个Skills挺重要的'
