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

## Quick Start

The web entrypoint is the recommended first path.

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-dev.lock
```

```bash
python -m uvicorn podcast_web.app:app --reload
```

Open:

- <http://127.0.0.1:8000>

Upload a file or paste a public podcast URL, choose a mode, and create a job. After the job completes, the result page shows the transcript and download links.

URL import only handles publicly accessible audio pages, RSS feeds, and direct audio links. For login-only or paid content, download the audio file first.

## Model Files

The default ASR model is `openai/whisper-tiny`. Speaker diarization depends on pyannote models, and some of those models require Hugging Face authentication and model access approval.

Local model resource directory:

```text
~/Library/Application Support/PodcastTranscriptStudio/Models/
```

The macOS settings view can change the model directory and download the required models. For speaker diarization, accept the required pyannote model licenses on Hugging Face first, then paste a token in the settings view.

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
