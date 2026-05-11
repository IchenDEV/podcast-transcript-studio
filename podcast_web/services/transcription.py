from __future__ import annotations

from pathlib import Path
from typing import Tuple, List
import shutil
import subprocess
import threading

from packages.transcriber.modes import resolve_mode_settings
from podcast_web.repository import JobRepository


DEFAULT_TEXT_MODEL = 'Qwen/Qwen3-0.6B'


def build_transcription_command(settings, job_id: int, source_path: Path, filename: str, diarize: bool, clean_fillers: bool, mode: str = 'standard') -> Tuple[List[str], Path, Path]:
    job_dir = settings.jobs_dir / str(job_id)
    job_dir.mkdir(parents=True, exist_ok=True)
    output_txt = job_dir / "transcript.txt"
    output_json = job_dir / "transcript.json"
    script = settings.base_dir / "packages" / "python_worker" / "cli.py"

    mode_settings = resolve_mode_settings(mode)

    cmd = [
        "python3",
        str(script),
        "--audio",
        str(source_path),
        "--output",
        str(output_txt),
        "--json",
        str(output_json),
        "--preset",
        mode_settings.worker_preset,
        "--text-model",
        DEFAULT_TEXT_MODEL,
        "--asr-provider",
        mode_settings.default_asr_provider,
    ]
    if diarize:
        cmd.append("--diarize")
    if not clean_fillers:
        cmd.append("--keep-fillers")
    return cmd, output_txt, output_json


def save_upload(settings, upload_file, filename: str) -> Path:
    settings.uploads_dir.mkdir(parents=True, exist_ok=True)
    destination = settings.uploads_dir / filename
    with destination.open("wb") as f:
        shutil.copyfileobj(upload_file.file, f)
    return destination


def start_job(repository: JobRepository, settings, job_id: int, source_path: Path, filename: str, diarize: bool, clean_fillers: bool, mode: str = 'standard') -> None:
    def runner():
        cmd, output_txt, _ = build_transcription_command(settings, job_id, source_path, filename, diarize, clean_fillers, mode=mode)
        repository.update_job(job_id, status="running")
        completed = subprocess.run(cmd, capture_output=True, text=True)
        if completed.returncode == 0:
            repository.update_job(job_id, status="completed", output_path=str(output_txt))
        else:
            repository.update_job(job_id, status="failed", error_message=completed.stderr or completed.stdout)

    threading.Thread(target=runner, daemon=True).start()
