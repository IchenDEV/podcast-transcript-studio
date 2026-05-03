#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODELS_OUT="${ROOT_DIR}/Sources/PodcastTranscriptStudioCore/Resources/Models"
SCRIPTS_OUT="${ROOT_DIR}/Sources/PodcastTranscriptStudioCore/Resources/Scripts"
HF_CACHE="${HOME}/.cache/huggingface/hub"
WORKER_SRC="${ROOT_DIR}/packages/python_worker"

mkdir -p "$MODELS_OUT" "$SCRIPTS_OUT"

copy_repo() {
  local repo_path="$1"
  local target_name="$2"
  shift 2
  if [ -d "$repo_path" ]; then
    for required in "$@"; do
      if [ ! -e "$repo_path/$required" ]; then
        echo "incomplete: $target_name missing $required" >&2
        return 1
      fi
    done
    rm -rf "$MODELS_OUT/$target_name"
    cp -RL "$repo_path" "$MODELS_OUT/$target_name"
    echo "copied: $target_name"
  else
    echo "missing: $repo_path" >&2
  fi
}

copy_latest_snapshot() {
  local repo_slug="$1"
  shift
  local repo_dir="${HF_CACHE}/models--${repo_slug//\//--}/snapshots"
  local latest
  latest="$(ls -1 "$repo_dir" 2>/dev/null | tail -n 1 || true)"
  if [ -n "$latest" ]; then
    copy_repo "$repo_dir/$latest" "$(basename "${repo_slug}")" "$@"
  else
    echo "missing snapshots for $repo_slug" >&2
  fi
}

missing=0

copy_latest_snapshot "openai/whisper-tiny" "config.json" "pytorch_model.bin" || missing=1
copy_latest_snapshot "pyannote/speaker-diarization-3.1" "config.yaml" || missing=1
copy_latest_snapshot "pyannote/segmentation-3.0" "config.yaml" "pytorch_model.bin" || missing=1
copy_latest_snapshot "pyannote/wespeaker-voxceleb-resnet34-LM" "config.yaml" "pytorch_model.bin" || missing=1
copy_latest_snapshot "Qwen/Qwen3-0.6B" "config.json" "model.safetensors" "tokenizer.json" || missing=1

patch_diarization_config() {
  python3 - "$MODELS_OUT" <<'PY'
import json
import sys
from pathlib import Path

models_dir = Path(sys.argv[1]).resolve()
config_path = models_dir / "speaker-diarization-3.1" / "config.yaml"
if not config_path.exists():
    raise SystemExit(0)

text = config_path.read_text(encoding="utf-8")
text = text.replace(
    "embedding: pyannote/wespeaker-voxceleb-resnet34-LM",
    f"embedding: {json.dumps(str(models_dir / 'wespeaker-voxceleb-resnet34-LM'))}",
)
text = text.replace(
    "segmentation: pyannote/segmentation-3.0",
    f"segmentation: {json.dumps(str(models_dir / 'segmentation-3.0'))}",
)
config_path.write_text(text, encoding="utf-8")
PY
}

cp "$WORKER_SRC/cli.py" "$SCRIPTS_OUT/cli.py"
cp "$WORKER_SRC/text_refinement.py" "$SCRIPTS_OUT/text_refinement.py"
cp "$WORKER_SRC/transcribe_with_speaker_segmentation.py" "$SCRIPTS_OUT/transcribe_with_speaker_segmentation.py"
echo "copied worker scripts"

if [ "$missing" -ne 0 ]; then
  echo "some model snapshots are missing or incomplete" >&2
  exit 1
fi

patch_diarization_config
echo "patched local model references"
