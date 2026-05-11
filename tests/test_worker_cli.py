import importlib


def test_worker_cli_module_exists():
    module = importlib.import_module('packages.python_worker.cli')
    assert hasattr(module, 'main')


def test_worker_cli_resolves_existing_script():
    module = importlib.import_module('packages.python_worker.cli')
    script = module.worker_script_path()

    assert script.name == 'transcribe_with_speaker_segmentation.py'
    assert script.exists()


def test_worker_script_accepts_new_asr_provider_flags():
    module = importlib.import_module('packages.python_worker.transcribe_with_speaker_segmentation')

    args = module.parse_args([
        '--audio',
        'demo.wav',
        '--output',
        'transcript.txt',
        '--asr-provider',
        'mimo',
        '--qwen-asr-model',
        'Qwen/Qwen3-ASR-0.6B',
        '--qwen-aligner-model',
        'Qwen/Qwen3-ForcedAligner-0.6B',
        '--mimo-model-path',
        '/models/MiMo-V2.5-ASR',
        '--mimo-tokenizer-path',
        '/models/MiMo-Audio-Tokenizer',
        '--mimo-source-dir',
        '/src/MiMo-V2.5-ASR',
    ])

    assert args.asr_provider == 'mimo'
    assert args.qwen_asr_model == 'Qwen/Qwen3-ASR-0.6B'
    assert args.mimo_source_dir == '/src/MiMo-V2.5-ASR'
