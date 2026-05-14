#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from dataclasses import asdict, dataclass
from typing import Sequence


GITHUB_PACKAGE_SPEC = (
    "podcast-transcript-studio[worker] @ "
    "git+https://github.com/IchenDEV/podcast-transcript-studio.git"
)


def package_spec() -> str:
    override = os.environ.get("PTS_PACKAGE_SPEC")
    if override:
        return override
    return GITHUB_PACKAGE_SPEC


@dataclass
class CheckResult:
    cli_path: str | None
    ffmpeg_path: str | None
    install_attempted: bool
    install_command: list[str] | None
    ok: bool


def run_command(command: Sequence[str]) -> int:
    completed = subprocess.run(command)
    return int(completed.returncode)


def quiet_run(command: Sequence[str]) -> bool:
    completed = subprocess.run(
        command,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    return completed.returncode == 0


def command_path(name: str) -> str | None:
    return shutil.which(name)


def install_command(manager: str) -> list[str]:
    spec = package_spec()
    if manager == "uv":
        return ["uv", "tool", "install", spec]
    if manager == "pipx":
        pipx = command_path("pipx")
        if pipx:
            return [pipx, "install", spec]
        return [sys.executable, "-m", "pipx", "install", spec]

    if command_path("uv"):
        return ["uv", "tool", "install", spec]
    pipx = command_path("pipx")
    if pipx:
        return [pipx, "install", spec]
    return [sys.executable, "-m", "pipx", "install", spec]


def maybe_prepare_pipx(command: list[str]) -> None:
    if command[:3] != [sys.executable, "-m", "pipx"]:
        return
    if quiet_run([sys.executable, "-m", "pipx", "--version"]):
        return
    subprocess.run([sys.executable, "-m", "pip", "install", "--user", "pipx"], check=True)
    subprocess.run([sys.executable, "-m", "pipx", "ensurepath"], check=False)


def check(install: bool, manager: str) -> CheckResult:
    cli = command_path("podcast-transcript-studio")
    attempted = False
    command = None

    if install and not cli:
        command = install_command(manager)
        maybe_prepare_pipx(command)
        run_command(command)
        attempted = True
        cli = command_path("podcast-transcript-studio")

    ffmpeg = command_path("ffmpeg")
    ok = bool(cli and ffmpeg)
    return CheckResult(
        cli_path=cli,
        ffmpeg_path=ffmpeg,
        install_attempted=attempted,
        install_command=command,
        ok=ok,
    )


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Check or install Podcast Transcript Studio CLI.")
    parser.add_argument("--install", action="store_true", help="Install the CLI if it is missing.")
    parser.add_argument("--manager", choices=["auto", "uv", "pipx"], default="auto")
    parser.add_argument("--json", action="store_true", help="Print machine-readable status.")
    args = parser.parse_args(argv)

    result = check(install=args.install, manager=args.manager)
    if args.json:
        print(json.dumps(asdict(result), ensure_ascii=False, indent=2))
    else:
        print(f"CLI: {result.cli_path or 'missing'}")
        print(f"ffmpeg: {result.ffmpeg_path or 'missing'}")
        if result.install_command:
            print("Install command: " + " ".join(result.install_command))
        print("OK" if result.ok else "Missing requirements")
    return 0 if result.ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
