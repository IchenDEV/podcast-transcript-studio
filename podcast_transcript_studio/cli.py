from __future__ import annotations

import argparse
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence
from urllib.parse import urlparse

from packages.podcast_fetcher.download import download_podcast_audio
from packages.podcast_fetcher.resolver import ResolvedPodcastAudio
from packages.transcriber.modes import UserMode, resolve_mode_settings


DEFAULT_WORK_DIR = Path('.pts-cli')
DEFAULT_OUTPUT_DIR = Path('transcripts')
DEFAULT_TEXT_MODEL = 'Qwen/Qwen3-0.6B'


class CLIError(RuntimeError):
    pass


@dataclass(frozen=True)
class TranscriptionPlan:
    source_path: Path
    output_text: Path
    output_json: Path | None
    command: list[str]
    resolved_podcast: ResolvedPodcastAudio | None = None


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        prog='podcast-transcript-studio',
        description='Transcribe a local media file or a public podcast URL.',
    )
    parser.add_argument('source', help='本地音频/视频文件，或公开播客链接')
    parser.add_argument('-o', '--output', help='文本输出路径')
    parser.add_argument('--output-dir', default=str(DEFAULT_OUTPUT_DIR), help='未指定 --output 时使用的目录')
    parser.add_argument('--work-dir', default=str(DEFAULT_WORK_DIR), help='链接音频和中间文件目录')
    parser.add_argument('--json', nargs='?', const=True, default=None, help='导出 JSON；可直接跟 JSON 路径')
    parser.add_argument(
        '--mode',
        default=UserMode.STANDARD.value,
        choices=[mode.value for mode in UserMode],
        help='转写模式',
    )
    parser.add_argument(
        '--asr-provider',
        default=None,
        choices=['auto', 'whisper', 'qwen3', 'mimo'],
        help='ASR provider；默认按模式选择',
    )
    parser.add_argument('--asr-model', default=None, help='Whisper 模型名或本地路径')
    parser.add_argument('--language', default=None, help='ASR 语言码')
    parser.add_argument('--asr-device', default=None, choices=['cpu', 'cuda'], help='ASR 设备')
    parser.add_argument('--engine', default=None, choices=['auto', 'transformers', 'faster-whisper'], help='Whisper 后端')
    parser.add_argument('--qwen-asr-model', default=None, help='Qwen3-ASR 模型名或本地路径')
    parser.add_argument('--qwen-aligner-model', default=None, help='Qwen3 ForcedAligner 模型名或本地路径')
    parser.add_argument('--mimo-model-path', default=None, help='MiMo-V2.5-ASR 模型目录')
    parser.add_argument('--mimo-tokenizer-path', default=None, help='MiMo-Audio-Tokenizer 目录')
    parser.add_argument('--mimo-source-dir', default=None, help='MiMo-V2.5-ASR 官方源码目录')
    parser.add_argument('--text-model', default=DEFAULT_TEXT_MODEL, help='文本后处理模型名或本地路径')
    parser.add_argument('--text-model-device', default=None, choices=['cpu', 'cuda', 'mps', 'auto'], help='文本后处理模型设备')
    parser.add_argument('--diarization-model', default=None, help='pyannote 模型名或本地路径')
    parser.add_argument('--chinese-variant', default=None, choices=['simplified', 'traditional', 'original'], help='中文输出字形')
    parser.add_argument('--hf-token', default=None, help='Hugging Face token')
    parser.add_argument('--python', default=sys.executable, help='运行 worker 的 Python')
    parser.add_argument('--keep-fillers', action='store_true', help='保留口语词')
    parser.add_argument('--skip-text-refinement', action='store_true', help='跳过模型文本后处理')
    parser.add_argument('--offline', action='store_true', help='强制离线模型加载')

    diarize_group = parser.add_mutually_exclusive_group()
    diarize_group.add_argument('--diarize', dest='diarize', action='store_true', default=None, help='启用发言人分离')
    diarize_group.add_argument('--no-diarize', dest='diarize', action='store_false', help='关闭发言人分离')

    return parser.parse_args(argv)


def create_plan(args: argparse.Namespace) -> TranscriptionPlan:
    source_path, resolved_podcast = _resolve_source(args.source, Path(args.work_dir).expanduser().resolve())
    output_text, output_json = _resolve_outputs(args, source_path, resolved_podcast)
    output_text.parent.mkdir(parents=True, exist_ok=True)
    if output_json is not None:
        output_json.parent.mkdir(parents=True, exist_ok=True)
    command = build_worker_command(args, source_path, output_text, output_json)
    return TranscriptionPlan(
        source_path=source_path,
        output_text=output_text,
        output_json=output_json,
        command=command,
        resolved_podcast=resolved_podcast,
    )


def build_worker_command(
    args: argparse.Namespace,
    source_path: Path,
    output_text: Path,
    output_json: Path | None,
) -> list[str]:
    mode_settings = resolve_mode_settings(args.mode)
    diarize = args.diarize if args.diarize is not None else mode_settings.default_diarize
    asr_provider = args.asr_provider or mode_settings.default_asr_provider

    command = [
        args.python,
        str(worker_cli_path()),
        '--audio',
        str(source_path),
        '--output',
        str(output_text),
        '--preset',
        mode_settings.worker_preset,
        '--asr-provider',
        asr_provider,
    ]

    if output_json is not None:
        command.extend(['--json', str(output_json)])
    if diarize:
        command.append('--diarize')
    if args.keep_fillers:
        command.append('--keep-fillers')
    if args.skip_text_refinement:
        command.append('--skip-text-refinement')
    if args.offline:
        command.append('--offline')

    _append_optional(command, '--asr-model', args.asr_model)
    _append_optional(command, '--language', args.language)
    _append_optional(command, '--asr-device', args.asr_device)
    _append_optional(command, '--engine', args.engine)
    _append_optional(command, '--qwen-asr-model', args.qwen_asr_model)
    _append_optional(command, '--qwen-aligner-model', args.qwen_aligner_model)
    _append_optional(command, '--mimo-model-path', args.mimo_model_path)
    _append_optional(command, '--mimo-tokenizer-path', args.mimo_tokenizer_path)
    _append_optional(command, '--mimo-source-dir', args.mimo_source_dir)
    _append_optional(command, '--text-model', args.text_model)
    _append_optional(command, '--text-model-device', args.text_model_device)
    _append_optional(command, '--diarization-model', args.diarization_model)
    _append_optional(command, '--chinese-variant', args.chinese_variant)
    _append_optional(command, '--hf-token', args.hf_token)

    return command


def run(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        plan = create_plan(args)
    except CLIError as error:
        print(f'错误：{error}', file=sys.stderr)
        return 2

    if plan.resolved_podcast is not None:
        title = plan.resolved_podcast.title or plan.resolved_podcast.audio_url
        print(f'已准备播客音频：{title}')
    print(f'开始转写：{plan.source_path}')

    try:
        subprocess.run(plan.command, check=True)
    except subprocess.CalledProcessError as error:
        return int(error.returncode or 1)

    print(f'文本：{plan.output_text}')
    if plan.output_json is not None:
        print(f'JSON：{plan.output_json}')
    return 0


def main(argv: Sequence[str] | None = None) -> None:
    raise SystemExit(run(argv))


def worker_cli_path() -> Path:
    script = Path(__file__).resolve().parents[1] / 'packages' / 'python_worker' / 'cli.py'
    if not script.exists():
        raise CLIError(f'找不到 worker 入口：{script}')
    return script


def _resolve_source(source: str, work_dir: Path) -> tuple[Path, ResolvedPodcastAudio | None]:
    if _is_url(source):
        audio_path, resolved = download_podcast_audio(source, work_dir / 'audio')
        return audio_path.expanduser().resolve(), resolved

    source_path = Path(source).expanduser().resolve()
    if not source_path.exists():
        raise CLIError(f'找不到文件：{source_path}')
    if not source_path.is_file():
        raise CLIError(f'来源不是文件：{source_path}')
    return source_path, None


def _resolve_outputs(
    args: argparse.Namespace,
    source_path: Path,
    resolved_podcast: ResolvedPodcastAudio | None,
) -> tuple[Path, Path | None]:
    output_text = (
        Path(args.output).expanduser().resolve()
        if args.output
        else Path(args.output_dir).expanduser().resolve() / f'{_default_output_stem(source_path, resolved_podcast)}.txt'
    )

    if args.json is None:
        output_json = None
    elif args.json is True:
        output_json = output_text.with_suffix('.json')
    else:
        output_json = Path(args.json).expanduser().resolve()

    return output_text, output_json


def _default_output_stem(source_path: Path, resolved_podcast: ResolvedPodcastAudio | None) -> str:
    if resolved_podcast and resolved_podcast.title:
        return _safe_stem(resolved_podcast.title)
    return _safe_stem(source_path.stem)


def _safe_stem(value: str) -> str:
    cleaned = re.sub(r'[\\/:*?"<>|]+', '-', value).strip(' .-')
    cleaned = re.sub(r'\s+', ' ', cleaned)
    return (cleaned or 'transcript')[:90]


def _is_url(value: str) -> bool:
    parsed = urlparse(value)
    return parsed.scheme in {'http', 'https'} and bool(parsed.netloc)


def _append_optional(command: list[str], flag: str, value: str | None) -> None:
    if value:
        command.extend([flag, value])
