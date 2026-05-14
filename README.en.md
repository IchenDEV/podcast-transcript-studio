# Podcast Transcript Studio

[中文](README.md)

Podcast Transcript Studio is a local-first transcription tool for podcasts, interviews, meetings, and media files. The project includes a FastAPI web entrypoint, a SwiftUI macOS entrypoint, a Python worker, and shared transcript data structures.

## Current Status

The project is a working development version with the following capabilities:

- Upload local audio or video files
- Import audio from public podcast URLs, including Apple Podcasts, Xiaoyuzhou, Ximalaya public RSS/album pages, and direct audio links
- Create transcription jobs and view job status
- Generate readable transcripts and verbatim transcripts
- Export `TXT`, `JSON`, `SRT`, and `MD`
- Choose quick, standard, or high-quality modes
- Share the Python worker design across the web and macOS entrypoints

## Install the CLI

The simplest path is an isolated `pipx` install:

```bash
python3 -m pip install --user pipx
python3 -m pipx ensurepath
pipx install "podcast-transcript-studio[worker] @ git+https://github.com/IchenDEV/podcast-transcript-studio.git"
```

If you already use `uv`:

```bash
uv tool install "podcast-transcript-studio[worker] @ git+https://github.com/IchenDEV/podcast-transcript-studio.git"
```

On macOS, install `ffmpeg` first:

```bash
brew install ffmpeg
```

Check the command after installation:

```bash
podcast-transcript-studio --help
```

Install from source:

```bash
git clone https://github.com/IchenDEV/podcast-transcript-studio.git
cd podcast-transcript-studio
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -e ".[worker,web,dev]"
```

Repository development can still use `requirements*.lock` when you need the exact dependency versions currently verified in this repo.

## Web Entrypoint

The web entrypoint is the recommended first path.

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -e ".[web,worker]"
```

```bash
python -m uvicorn podcast_web.app:app --reload
```

Open:

- <http://127.0.0.1:8000>

Upload a file or paste a public podcast URL, choose a mode, and create a job. After the job completes, the result page shows the transcript and download links.

URL import only handles publicly accessible audio pages, RSS feeds, and direct audio links. For login-only or paid content, download the audio file first.

## Command-Line Transcription

Local file:

```bash
podcast-transcript-studio ./demo.m4a --mode quick --output transcripts/demo.txt --json
```

Public podcast URL:

```bash
podcast-transcript-studio "https://podcasts.apple.com/..." --mode standard --output-dir transcripts --json
```

Common options:

- `--mode quick|standard|high_quality`
- `--diarize` / `--no-diarize`
- `--asr-provider auto|whisper|qwen3|mimo`
- `--skip-text-refinement`
- `--keep-fillers`

When `--output` is omitted, text files are written to `transcripts/`. Public podcast URLs are downloaded to `.pts-cli/audio/` before the local worker runs.

Inside a source checkout, you can also run the module directly:

```bash
python -m podcast_transcript_studio ./demo.m4a --output transcripts/demo.txt
```

## Model Files

The default ASR model is `openai/whisper-tiny`. High quality mode tries local Qwen3-ASR first and falls back to Whisper when the local runtime or model files are unavailable. MiMo-V2.5-ASR is available as an optional local ASR provider through worker flags.

Speaker diarization depends on pyannote models, and some of those models require Hugging Face authentication and model access approval.

Local model resource directory:

```text
~/Library/Application Support/PodcastTranscriptStudio/Models/
```

The macOS settings view can change the model directory and download the required models. For speaker diarization, accept the required pyannote model licenses on Hugging Face first, then paste a token in the settings view.

Qwen3-ASR and MiMo-V2.5-ASR need heavier optional dependencies. After a `pipx` install, add the local high-quality ASR dependency with:

```bash
pipx inject podcast-transcript-studio "qwen-asr>=0.1"
```

Inside a source environment:

```bash
python -m pip install -e ".[local-asr]"
```

To download Qwen3-ASR and MiMo-V2.5-ASR weights:

```bash
python Sources/PodcastTranscriptStudioCore/Resources/Scripts/download_models.py \
  --models-dir "$HOME/Library/Application Support/PodcastTranscriptStudio/Models" \
  --include-local-asr
```

To ship models inside the DMG, log in to Hugging Face, accept the required model licenses, and run `./scripts/package_models.sh`. That script copies model snapshots to:

```text
Sources/PodcastTranscriptStudioCore/Resources/Models/
```

## Project Layout

```text
podcast_web/                  FastAPI web entrypoint
packages/core/                Transcript data structures and readable transcript logic
packages/podcast_fetcher/     Public podcast URL resolution and audio download
packages/transcriber/         User modes and worker preset mapping
packages/python_worker/       Python worker entrypoint and transcription script
Sources/PodcastTranscriptStudioCore/  Swift core module
Sources/PodcastTranscriptStudioApp/   SwiftUI macOS entrypoint
tests/                        Python and Swift tests
scripts/                      Packaging and model resource scripts
docs/developer/               Developer architecture docs
```

## Development Commands

Python tests:

```bash
source .venv/bin/activate
python -m pytest tests -v
```

Swift tests:

```bash
swift test
```

If `xcode-select` points to Command Line Tools and the test build reports `no such module 'XCTest'`, run with the full Xcode path:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test
```

macOS entrypoint:

```bash
swift run PodcastTranscriptStudioApp
```

Model resource script:

```bash
./scripts/package_models.sh
```

Run the same model downloader used by the settings view:

```bash
python Sources/PodcastTranscriptStudioCore/Resources/Scripts/download_models.py \
  --models-dir "$HOME/Library/Application Support/PodcastTranscriptStudio/Models"
```

Install worker inference dependencies only when needed:

```bash
python -m pip install -r requirements-worker.lock
```

`requirements*.txt` keeps flexible version ranges for dependency upgrades. `requirements*.lock` pins the currently verified versions for daily development, tests, and packaging. Python 3.10 to 3.12 is recommended for worker inference dependencies.

## License

The project source code is released under the MIT License. See `LICENSE`.

Models and third-party dependencies keep their own licenses and access terms. The default ASR model is `openai/whisper-tiny`; speaker diarization uses pyannote models; text refinement can use `Qwen/Qwen3-0.6B`. Before packaging or redistributing builds with bundled models, review `NOTICE.md` and the upstream model cards.

## Documentation

- Developer architecture: `docs/developer/architecture.md`
- macOS notes: `docs/developer/macos-app.md`

## Use Cases

- Podcast and interview transcription
- Meeting transcript preparation
- Local privacy-first media transcription
- Continued development of a macOS local transcription product
