from __future__ import annotations

import re

FILLER_PATTERNS = [
    r'(^|[，。！？、\s])嗯([，。！？、\s]|$)',
    r'(^|[，。！？、\s])啊([，。！？、\s]|$)',
    r'(^|[，。！？、\s])呃([，。！？、\s]|$)',
    r'(^|[，。！？、\s])额([，。！？、\s]|$)',
    r'(^|[，。！？、\s])就是([，。！？、\s]|$)',
    r'(^|[，。！？、\s])那个([，。！？、\s]|$)',
]


def normalize_text(text: str) -> str:
    text = (text or '').strip()
    return re.sub(r'\s+', ' ', text)


def clean_text(text: str, remove_fillers: bool = True) -> str:
    cleaned = normalize_text(text)
    if not cleaned:
        return cleaned

    cleaned = re.sub(r'\b(\w+)(\s+\1\b)+', r'\1', cleaned)
    cleaned = re.sub(r'([\u4e00-\u9fff]{1,8})\1{1,}', r'\1', cleaned)

    if remove_fillers:
        for pattern in FILLER_PATTERNS:
            cleaned = re.sub(pattern, r'\1\2', cleaned)
        cleaned = re.sub(r'(^|[，。！？、\s])(然后|我觉得|你知道)([，。！？、\s]|$)', r'\1\3', cleaned)

    cleaned = re.sub(r'\s+', ' ', cleaned)
    cleaned = re.sub(r'(?<=[\u4e00-\u9fff])\s+(?=[\u4e00-\u9fff])', '', cleaned)
    cleaned = re.sub(r'(?<=[A-Za-z0-9])\s+(?=[\u4e00-\u9fff])', '', cleaned)
    cleaned = re.sub(r'(?<=[\u4e00-\u9fff])\s+(?=[A-Za-z0-9])', '', cleaned)
    cleaned = re.sub(r'([，。！？；：]){2,}', r'\1', cleaned)
    return cleaned.strip(' ，。！？；：')
