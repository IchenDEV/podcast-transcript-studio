from __future__ import annotations

from pathlib import Path
import re
from urllib.parse import urlparse
from urllib.request import Request, urlopen

from .resolver import PodcastAudioError, ResolvedPodcastAudio, USER_AGENT, resolve_podcast_audio


def download_podcast_audio(source_url: str, destination_dir: Path) -> tuple[Path, ResolvedPodcastAudio]:
    resolved = resolve_podcast_audio(source_url)
    destination_dir.mkdir(parents=True, exist_ok=True)
    filename = _build_filename(resolved)
    destination = _unique_path(destination_dir / filename)

    request = Request(resolved.audio_url, headers={'User-Agent': USER_AGENT, 'Accept': '*/*'})
    try:
        with urlopen(request, timeout=120) as response, destination.open('wb') as output:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                output.write(chunk)
    except Exception as error:
        if destination.exists():
            destination.unlink()
        raise PodcastAudioError(f'音频下载失败：{error}') from error

    return destination, resolved


def _build_filename(resolved: ResolvedPodcastAudio) -> str:
    parsed = urlparse(resolved.audio_url)
    extension = Path(parsed.path).suffix.lower()
    if extension not in {'.mp3', '.m4a', '.mp4', '.m4b', '.wav', '.aac', '.flac', '.ogg', '.opus'}:
        extension = '.mp3'
    stem = resolved.title or Path(parsed.path).stem or 'podcast-audio'
    stem = _safe_filename(stem)
    return f'{stem}{extension}'


def _safe_filename(value: str) -> str:
    cleaned = re.sub(r'[\\/:*?"<>|]+', '-', value).strip(' .-')
    cleaned = re.sub(r'\s+', ' ', cleaned)
    return (cleaned or 'podcast-audio')[:90]


def _unique_path(path: Path) -> Path:
    if not path.exists():
        return path
    for index in range(1, 1000):
        candidate = path.with_name(f'{path.stem}-{index}{path.suffix}')
        if not candidate.exists():
            return candidate
    raise RuntimeError(f'无法创建文件：{path}')
