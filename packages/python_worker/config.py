from __future__ import annotations

PRESET_DEFAULTS = {
    'production': {
        'engine': 'auto',
        'asr_model': 'openai/whisper-large-v3',
        'asr_language': 'zh',
        'section_seconds': 180,
        'chunk_length': 25,
        'batch_size': 4,
        'beam_size': 6,
        'vad': True,
    },
    'balanced': {
        'engine': 'auto',
        'asr_model': 'openai/whisper-base',
        'asr_language': 'zh',
        'section_seconds': 240,
        'chunk_length': 30,
        'batch_size': 4,
        'beam_size': 5,
        'vad': True,
    },
    'lite': {
        'engine': 'transformers',
        'asr_model': 'openai/whisper-tiny',
        'asr_language': 'zh',
        'section_seconds': 300,
        'chunk_length': 20,
        'batch_size': 2,
        'beam_size': 4,
        'vad': False,
    },
}


def apply_preset_defaults(args):
    preset = PRESET_DEFAULTS[args.preset]
    if args.asr_model is None:
        args.asr_model = preset['asr_model']
    if args.section_seconds == 0:
        args.section_seconds = preset['section_seconds']
    if args.chunk_length == 0:
        args.chunk_length = preset['chunk_length']
    if args.batch_size == 0:
        args.batch_size = preset['batch_size']
    if args.beam_size == 0:
        args.beam_size = preset['beam_size']
    if args.language == 'zh':
        args.language = preset.get('asr_language', 'zh')
    if args.no_vad:
        args.vad = False
    else:
        args.vad = bool(args.vad or preset['vad'])
    return args
