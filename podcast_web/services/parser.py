from __future__ import annotations

from packages.core.transcript import TranscriptDocument, TranscriptSection, TranscriptSegment
import re


SECTION_RE = re.compile(r"^【(?P<title>分节\d+)】")
SEGMENT_RE = re.compile(
    r"^\[(?P<start>[^\]]+?) - (?P<end>[^\]]+?)\]\s+(?P<speaker>[^:]+):\s+(?P<text>.+)$"
)



def parse_transcript_text(text: str) -> TranscriptDocument:
    sections: list[TranscriptSection] = []
    current: TranscriptSection | None = None

    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue

        section_match = SECTION_RE.match(line)
        if section_match:
            current = TranscriptSection(title=section_match.group("title"))
            sections.append(current)
            continue

        segment_match = SEGMENT_RE.match(line)
        if segment_match:
            if current is None:
                current = TranscriptSection(title="未分节")
                sections.append(current)
            current.segments.append(
                TranscriptSegment(
                    start=segment_match.group("start"),
                    end=segment_match.group("end"),
                    speaker=segment_match.group("speaker"),
                    text=segment_match.group("text"),
                )
            )

    return TranscriptDocument.from_sections(sections)
