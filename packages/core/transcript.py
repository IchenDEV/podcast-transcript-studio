from __future__ import annotations

from dataclasses import dataclass, field
from typing import Iterable


@dataclass
class TranscriptSegment:
    start: str
    end: str
    speaker: str
    text: str


@dataclass
class TranscriptSection:
    title: str
    segments: list[TranscriptSegment] = field(default_factory=list)


@dataclass
class TranscriptDocument:
    sections: list[TranscriptSection]
    readable_text: str

    @classmethod
    def from_sections(cls, sections: list[TranscriptSection]) -> 'TranscriptDocument':
        return cls(sections=sections, readable_text=build_readable_transcript(sections))


def build_readable_transcript(sections: Iterable[TranscriptSection]) -> str:
    paragraphs: list[str] = []
    for section in sections:
        current_speaker: str | None = None
        current_texts: list[str] = []
        for segment in section.segments:
            if current_speaker is None:
                current_speaker = segment.speaker
            if segment.speaker != current_speaker:
                paragraphs.append(f'{current_speaker}：{" ".join(current_texts)}')
                current_speaker = segment.speaker
                current_texts = []
            current_texts.append(segment.text)
        if current_speaker and current_texts:
            paragraphs.append(f'{current_speaker}：{" ".join(current_texts)}')
    return '\n\n'.join(paragraphs)
