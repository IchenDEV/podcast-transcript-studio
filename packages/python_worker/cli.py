from __future__ import annotations

import runpy
from pathlib import Path


def worker_script_path() -> Path:
    return Path(__file__).resolve().with_name('transcribe_with_speaker_segmentation.py')


def main() -> None:
    script = worker_script_path()
    if not script.exists():
        raise FileNotFoundError(f'Worker script not found: {script}')
    runpy.run_path(str(script), run_name='__main__')


if __name__ == '__main__':
    main()
