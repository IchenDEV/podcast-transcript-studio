from __future__ import annotations

import argparse
import json
import os
import shutil
import sys
from pathlib import Path


REQUIRED_MODELS = [
    ("openai/whisper-tiny", "whisper-tiny", ["config.json", "pytorch_model.bin"]),
    ("pyannote/speaker-diarization-3.1", "speaker-diarization-3.1", ["config.yaml"]),
    ("pyannote/segmentation-3.0", "segmentation-3.0", ["config.yaml", "pytorch_model.bin"]),
    ("pyannote/wespeaker-voxceleb-resnet34-LM", "wespeaker-voxceleb-resnet34-LM", ["config.yaml", "pytorch_model.bin"]),
    ("Qwen/Qwen3-0.6B", "Qwen3-0.6B", ["config.json", "model.safetensors", "tokenizer.json"]),
]

LOCAL_ASR_MODELS = [
    ("Qwen/Qwen3-ASR-1.7B", "Qwen3-ASR-1.7B", ["config.json"]),
    ("Qwen/Qwen3-ForcedAligner-0.6B", "Qwen3-ForcedAligner-0.6B", ["config.json"]),
    ("XiaomiMiMo/MiMo-V2.5-ASR", "MiMo-V2.5-ASR", ["config.json"]),
    ("XiaomiMiMo/MiMo-Audio-Tokenizer", "MiMo-Audio-Tokenizer", ["config.json"]),
]


def require_huggingface_hub():
    try:
        from huggingface_hub import snapshot_download
    except ImportError as exc:
        raise SystemExit(
            "缺少 huggingface_hub。请先把 worker 依赖更新到最新 requirements-worker.txt，"
            "或在当前 Python 环境执行：python3 -m pip install huggingface_hub"
        ) from exc
    return snapshot_download


def copy_snapshot(snapshot_path: Path, target_path: Path) -> None:
    temporary_path = target_path.with_name(f".{target_path.name}.tmp")
    if temporary_path.exists():
        shutil.rmtree(temporary_path)
    if target_path.exists():
        shutil.rmtree(target_path)

    shutil.copytree(snapshot_path, temporary_path, symlinks=False)
    temporary_path.rename(target_path)


def verify_model(target_path: Path, required_files: list[str]) -> None:
    missing = [name for name in required_files if not (target_path / name).exists()]
    if missing:
        raise RuntimeError(f"{target_path.name} 缺少文件：{', '.join(missing)}")


def patch_diarization_config(models_dir: Path) -> None:
    config_path = models_dir / "speaker-diarization-3.1" / "config.yaml"
    if not config_path.exists():
        return

    text = config_path.read_text(encoding="utf-8")
    replacements = {
        "embedding: pyannote/wespeaker-voxceleb-resnet34-LM": f"embedding: {json.dumps(str(models_dir / 'wespeaker-voxceleb-resnet34-LM'))}",
        "segmentation: pyannote/segmentation-3.0": f"segmentation: {json.dumps(str(models_dir / 'segmentation-3.0'))}",
    }
    for old, new in replacements.items():
        text = text.replace(old, new)
    config_path.write_text(text, encoding="utf-8")


def download_models(models_dir: Path, token: str | None, include_local_asr: bool = False) -> None:
    snapshot_download = require_huggingface_hub()
    models_dir.mkdir(parents=True, exist_ok=True)

    model_specs = REQUIRED_MODELS + (LOCAL_ASR_MODELS if include_local_asr else [])
    for repo_id, directory_name, required_files in model_specs:
        print(f"下载 {repo_id}", flush=True)
        snapshot_path = Path(snapshot_download(repo_id=repo_id, token=token))
        target_path = models_dir / directory_name
        copy_snapshot(snapshot_path, target_path)
        verify_model(target_path, required_files)
        print(f"完成 {directory_name}", flush=True)

    patch_diarization_config(models_dir)
    print(f"模型目录：{models_dir}", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description="Download models for Podcast Transcript Studio.")
    parser.add_argument("--models-dir", required=True, help="模型输出目录")
    parser.add_argument("--include-local-asr", action="store_true", help="同时下载 Qwen3-ASR 和 MiMo-V2.5-ASR 模型")
    args = parser.parse_args()

    token = os.environ.get("HF_TOKEN") or None
    try:
        download_models(Path(args.models_dir).expanduser().resolve(), token, include_local_asr=args.include_local_asr)
    except Exception as exc:
        print(f"模型下载失败：{exc}", file=sys.stderr)
        raise SystemExit(1) from exc


if __name__ == "__main__":
    main()
