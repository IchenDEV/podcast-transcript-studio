# AGENTS.md

## Project Map

- `podcast_web/`: FastAPI web entrypoint, templates, static assets, repository, and transcription service glue.
- `packages/core/`: shared transcript data structures and readable transcript helpers.
- `packages/transcriber/`: user-facing transcription modes such as `quick`, `standard`, and `high_quality`.
- `packages/python_worker/`: Python worker CLI, preset config, cleanup logic, and transcription script.
- `Sources/PodcastTranscriptStudioCore/`: Swift core models, persistence, worker process handling, parsing, export, and packaging logic.
- `Sources/PodcastTranscriptStudioApp/`: SwiftUI macOS app shell.
- `tests/`: Python tests plus Swift package tests under `tests/PodcastTranscriptStudioCoreTests/`.
- `scripts/`: macOS app, DMG, and model packaging scripts.
- `docs/developer/`: developer architecture notes and macOS packaging notes.

## Commands

- Python env: `python3 -m venv .venv && source .venv/bin/activate && python -m pip install -r requirements-dev.txt`
- Web app: `source .venv/bin/activate && python -m uvicorn podcast_web.app:app --reload`
- Python tests: `source .venv/bin/activate && python -m pytest tests -v`
- Swift app: `swift run PodcastTranscriptStudioApp`
- Swift tests: `swift test`
- Swift tests with full Xcode: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test`
- macOS app build: `./scripts/build_macos_app.sh`
- DMG build: `./scripts/build_macos_dmg.sh`
- Model resources: `./scripts/package_models.sh`

## Change Guidelines

- Prefer shared transcript logic in `packages/core/` before adding duplicate parsing or result models in web or macOS code.
- Keep user mode behavior in `packages/transcriber/modes.py`; UI layers should call it directly.
- Keep worker execution behavior in `packages/python_worker/`; resource scripts under `Sources/.../Resources/Scripts/` are packaged copies.
- When changing transcript behavior, run Python tests and the relevant Swift parser/export tests.
- When changing `podcast_web/`, include route or repository tests when behavior changes.
- When changing macOS worker invocation, check `WorkerCommandBuilder`, `ProcessWorkerRunner`, and app configuration tests.

## Writing Rules

- Use direct, concrete Chinese.
- Avoid abstract project-management wording.
- Avoid reverse-contrast sentence patterns; state the reason or fix directly.
- User-facing docs should describe what the product does before implementation details.
