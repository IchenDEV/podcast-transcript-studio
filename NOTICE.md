# Notices

Podcast Transcript Studio source code is released under the MIT License. Third-party packages, models, and downloaded assets keep their own licenses and terms.

This repository does not commit model weights. Model files are downloaded by the user or copied into a local app bundle during packaging.

## Model Assets

License metadata was checked from upstream model cards on 2026-05-04.

| Component | Used for | License / access note |
| --- | --- | --- |
| [`openai/whisper-tiny`](https://huggingface.co/openai/whisper-tiny) | Default ASR model | Apache-2.0 on Hugging Face |
| [`pyannote/speaker-diarization-3.1`](https://huggingface.co/pyannote/speaker-diarization-3.1) | Speaker diarization pipeline | MIT on Hugging Face; gated access |
| [`pyannote/segmentation-3.0`](https://huggingface.co/pyannote/segmentation-3.0) | Diarization segmentation model | MIT on Hugging Face; gated access |
| [`pyannote/wespeaker-voxceleb-resnet34-LM`](https://huggingface.co/pyannote/wespeaker-voxceleb-resnet34-LM) | Speaker embedding model used by pyannote | CC-BY-4.0 on Hugging Face |
| [`Qwen/Qwen3-0.6B`](https://huggingface.co/Qwen/Qwen3-0.6B) | Optional transcript text refinement | Apache-2.0 on Hugging Face |

Before packaging or redistributing a build with bundled models, review the current model cards and accept any required Hugging Face access terms.

## Python Dependencies

Main runtime packages include:

| Component | License note |
| --- | --- |
| FastAPI | MIT |
| Uvicorn | BSD-3-Clause |
| Jinja2 | BSD-style / Pallets license |
| SQLAlchemy | MIT |
| python-multipart | Apache-2.0 |

Worker packages include:

| Component | License note |
| --- | --- |
| transformers | Apache-2.0 |
| faster-whisper | MIT |
| huggingface_hub | Apache-2.0 |
| pyannote.audio | Check package metadata and pyannote project terms |
| torch | BSD-3-Clause |
| torchaudio | Check package metadata and PyTorch project terms |

The lock files in this repository pin package versions for repeatable local installs. They do not replace the upstream licenses.
