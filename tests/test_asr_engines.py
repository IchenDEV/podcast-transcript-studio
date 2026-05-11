from types import ModuleType, SimpleNamespace


def test_qwen3_adapter_parses_timestamped_result(monkeypatch, tmp_path):
    from packages.python_worker import asr_engines

    audio = tmp_path / 'demo.wav'
    audio.write_bytes(b'fake')

    torch = ModuleType('torch')
    torch.bfloat16 = 'bf16'
    torch.float32 = 'fp32'
    torch.cuda = SimpleNamespace(is_available=lambda: True)

    class FakeQwen3ASRModel:
        @classmethod
        def from_pretrained(cls, model_name, **kwargs):
            assert model_name == 'Qwen/Qwen3-ASR-1.7B'
            assert kwargs['forced_aligner'] == 'Qwen/Qwen3-ForcedAligner-0.6B'
            assert kwargs['device_map'] == 'cuda:0'
            return cls()

        def transcribe(self, **kwargs):
            assert kwargs['audio'] == str(audio)
            assert kwargs['language'] == 'Chinese'
            assert kwargs['return_time_stamps'] is True
            return [
                SimpleNamespace(
                    language='Chinese',
                    text='你好世界',
                    time_stamps=[
                        SimpleNamespace(text='你好', start_time=0.2, end_time=0.8),
                        SimpleNamespace(text='世界', start_time=0.9, end_time=1.4),
                    ],
                )
            ]

    qwen_asr = ModuleType('qwen_asr')
    qwen_asr.Qwen3ASRModel = FakeQwen3ASRModel
    monkeypatch.setitem(__import__('sys').modules, 'torch', torch)
    monkeypatch.setitem(__import__('sys').modules, 'qwen_asr', qwen_asr)

    chunks = asr_engines.transcribe_qwen3(
        wav=audio,
        lang='zh',
        device='cpu',
        batch_size=2,
        qwen_asr_model='Qwen/Qwen3-ASR-1.7B',
        qwen_aligner_model='Qwen/Qwen3-ForcedAligner-0.6B',
        require_cuda=True,
    )

    assert [(c.start, c.end, c.text) for c in chunks] == [(0.2, 0.8, '你好'), (0.9, 1.4, '世界')]


def test_mimo_adapter_loads_official_source(monkeypatch, tmp_path):
    from packages.python_worker import asr_engines

    for name in [
        'src',
        'src.mimo_audio',
        'src.mimo_audio.mimo_audio',
    ]:
        monkeypatch.delitem(__import__('sys').modules, name, raising=False)

    source = tmp_path / 'mimo-source'
    module_dir = source / 'src' / 'mimo_audio'
    module_dir.mkdir(parents=True)
    (module_dir / 'mimo_audio.py').write_text(
        'class MimoAudio:\n'
        '    def __init__(self, model_path, tokenizer_path):\n'
        '        self.model_path = model_path\n'
        '        self.tokenizer_path = tokenizer_path\n'
        '    def asr_sft(self, audio_path, audio_tag=""):\n'
        '        return f"{self.model_path}|{self.tokenizer_path}|{audio_tag}|{audio_path}"\n',
        encoding='utf-8',
    )
    model = tmp_path / 'MiMo-V2.5-ASR'
    tokenizer = tmp_path / 'MiMo-Audio-Tokenizer'
    model.mkdir()
    tokenizer.mkdir()
    audio = tmp_path / 'demo.wav'
    audio.write_bytes(b'fake')

    chunks = asr_engines.transcribe_mimo(
        wav=audio,
        lang='en',
        model_path=str(model),
        tokenizer_path=str(tokenizer),
        source_dir=str(source),
    )

    assert len(chunks) == 1
    assert str(model) in chunks[0].text
    assert str(tokenizer) in chunks[0].text
    assert '<english>' in chunks[0].text


def test_auto_provider_falls_back_to_whisper(monkeypatch, tmp_path):
    from packages.python_worker import asr_engines

    audio = tmp_path / 'demo.wav'
    audio.write_bytes(b'fake')

    def fake_qwen3(**kwargs):
        raise asr_engines.ASRProviderUnavailable('no qwen')

    def fake_whisper(**kwargs):
        return [asr_engines.ASRUtterance(0.0, 1.0, 'fallback')], 'transformers'

    monkeypatch.setattr(asr_engines, 'transcribe_qwen3', fake_qwen3)
    monkeypatch.setattr(asr_engines, 'transcribe_whisper', fake_whisper)

    chunks, backend, model = asr_engines.transcribe_with_provider(
        provider='auto',
        wav=audio,
        whisper_model='openai/whisper-base',
        lang='zh',
        device='cpu',
        chunk_s=30,
        batch_size=1,
        whisper_engine='transformers',
        beam=5,
        vad=False,
        qwen_asr_model='Qwen/Qwen3-ASR-1.7B',
        qwen_aligner_model='Qwen/Qwen3-ForcedAligner-0.6B',
        mimo_model_path=None,
        mimo_tokenizer_path=None,
        mimo_source_dir=None,
    )

    assert chunks[0].text == 'fallback'
    assert backend == 'whisper/transformers'
    assert model == 'openai/whisper-base'
