from __future__ import annotations

from dataclasses import dataclass
from enum import Enum


class UserMode(str, Enum):
    QUICK = 'quick'
    STANDARD = 'standard'
    HIGH_QUALITY = 'high_quality'


@dataclass(frozen=True)
class TranscriptionModeSettings:
    key: UserMode
    label: str
    worker_preset: str
    default_asr_provider: str
    default_diarize: bool
    description: str


MODE_SETTINGS = {
    UserMode.QUICK: TranscriptionModeSettings(
        key=UserMode.QUICK,
        label='快速',
        worker_preset='lite',
        default_asr_provider='whisper',
        default_diarize=False,
        description='优先更快出结果，适合先看大意。',
    ),
    UserMode.STANDARD: TranscriptionModeSettings(
        key=UserMode.STANDARD,
        label='标准',
        worker_preset='balanced',
        default_asr_provider='whisper',
        default_diarize=False,
        description='默认模式，速度和质量取中间档。',
    ),
    UserMode.HIGH_QUALITY: TranscriptionModeSettings(
        key=UserMode.HIGH_QUALITY,
        label='高质量',
        worker_preset='production',
        default_asr_provider='auto',
        default_diarize=True,
        description='优先质量，允许更慢。',
    ),
}


def resolve_mode_settings(mode: UserMode | str | None) -> TranscriptionModeSettings:
    if mode is None:
        return MODE_SETTINGS[UserMode.STANDARD]
    if isinstance(mode, str):
        mode = UserMode(mode)
    return MODE_SETTINGS[mode]
