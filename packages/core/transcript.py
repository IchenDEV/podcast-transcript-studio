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
    speaker_display_names: dict[str, str] = field(default_factory=dict)

    @classmethod
    def from_sections(cls, sections: list[TranscriptSection]) -> 'TranscriptDocument':
        return cls(
            sections=sections,
            readable_text=build_readable_transcript(sections),
        )

    def display_name(self, speaker: str) -> str:
        return self.speaker_display_names.get(speaker, speaker)


def build_readable_transcript(
    sections: Iterable[TranscriptSection],
    speaker_display_names: dict[str, str] | None = None,
) -> str:
    paragraphs: list[str] = []
    speaker_display_names = speaker_display_names or {}
    for section in sections:
        current_speaker: str | None = None
        current_texts: list[str] = []
        for segment in section.segments:
            if current_speaker is None:
                current_speaker = segment.speaker
            if segment.speaker != current_speaker:
                display_name = speaker_display_names.get(current_speaker, current_speaker)
                paragraphs.append(f'{display_name}：{" ".join(current_texts)}')
                current_speaker = segment.speaker
                current_texts = []
            current_texts.append(segment.text)
        if current_speaker and current_texts:
            display_name = speaker_display_names.get(current_speaker, current_speaker)
            paragraphs.append(f'{display_name}：{" ".join(current_texts)}')
    return '\n\n'.join(paragraphs)
