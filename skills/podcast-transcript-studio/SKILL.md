---
name: podcast-transcript-studio
description: Use Podcast Transcript Studio from Codex to transcribe local audio/video files or public podcast URLs through the `podcast-transcript-studio` CLI. Use when the user asks to transcribe podcasts, interviews, meetings, media files, Apple Podcasts/Xiaoyuzhou/Ximalaya links, or when they want a local-first transcript with TXT/JSON output, diarization, or quick/standard/high-quality modes.
---

# Podcast Transcript Studio

Use the local-first `podcast-transcript-studio` CLI to turn audio, video, or public podcast links into text.

## Workflow

1. Identify the input.
   - Local file: verify the path exists before running transcription.
   - Public URL: pass the URL directly; the CLI downloads the audio first.
   - Login-only or paid content: ask the user for a local file.
2. Check the CLI and `ffmpeg`.
   - Run `python <skill>/scripts/ensure_cli.py --json`.
   - If the CLI is missing and the user wants this tool used now, run the same script with `--install`.
   - If `ffmpeg` is missing on macOS, install it with `brew install ffmpeg` or tell the user it is required.
3. Choose mode and flags.
   - Use `--mode standard` by default.
   - Use `--mode quick` for fast rough drafts.
   - Use `--mode high_quality` for better text or multiple speakers.
   - Add `--diarize` when speaker labels matter; add `--no-diarize` when speed matters.
   - Add `--json` when another agent or script will parse the result.
   - Add `--skip-text-refinement` when the text model is unavailable or speed matters more than cleanup.
4. Run the command.
   - Prefer explicit output paths so the user can find files later.
   - Use an absolute output path when working outside the current directory.
5. Verify.
   - Confirm the TXT path exists and is non-empty.
   - If JSON was requested, confirm the JSON file exists.
   - Report file paths and any important warnings from the command.

## Commands

Local file:

```bash
podcast-transcript-studio /path/to/audio.m4a \
  --mode standard \
  --output /path/to/transcripts/audio.txt \
  --json
```

Public podcast URL:

```bash
podcast-transcript-studio "https://podcasts.apple.com/..." \
  --mode standard \
  --output-dir /path/to/transcripts \
  --json
```

High-quality run with speaker labels:

```bash
podcast-transcript-studio /path/to/interview.mp3 \
  --mode high_quality \
  --diarize \
  --output /path/to/transcripts/interview.txt \
  --json /path/to/transcripts/interview.json
```

## Install Helpers

Use `scripts/ensure_cli.py` for repeatable setup checks.

```bash
python scripts/ensure_cli.py --json
python scripts/ensure_cli.py --install
```

The installer uses the GitHub repository by default. Override with `PTS_PACKAGE_SPEC` when a local checkout or fork should be used.

Default GitHub package spec:

```text
podcast-transcript-studio[worker] @ git+https://github.com/IchenDEV/podcast-transcript-studio.git
```

Local checkout override example:

```bash
PTS_PACKAGE_SPEC="podcast-transcript-studio[worker] @ file:///absolute/path/to/podcast-transcript-studio" \
  python scripts/ensure_cli.py --install
```

For optional local Qwen ASR after a `pipx` install:

```bash
pipx inject podcast-transcript-studio "qwen-asr>=0.1"
```

## Operational Notes

- The CLI is local-first, but public URL input still downloads audio from the source site.
- Diarization can require Hugging Face model access and a token.
- Qwen3-ASR and MiMo local ASR are optional heavy dependencies; use Whisper defaults unless the user specifically needs those providers.
- Do not claim a transcript is complete until the command exits successfully and the output file exists.
