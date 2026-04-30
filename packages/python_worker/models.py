from __future__ import annotations

from dataclasses import dataclass
from typing import Optional


@dataclass
class ASRUtterance:
    start: float
    end: float
    text: str
    speaker: str = '说话人1'
    score: Optional[float] = None


def fmt_time(seconds: float) -> str:
    total_ms = int(max(seconds, 0) * 1000)
    hours, remainder = divmod(total_ms, 3600000)
    minutes, remainder = divmod(remainder, 60000)
    secs, millis = divmod(remainder, 1000)
    return f'{hours:02d}:{minutes:02d}:{secs:02d}.{millis:03d}'
