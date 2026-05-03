from __future__ import annotations

import re
from functools import lru_cache

FILLER_PATTERNS = [
    r'(^|[，。！？、\s])嗯([，。！？、\s]|$)',
    r'(^|[，。！？、\s])啊([，。！？、\s]|$)',
    r'(^|[，。！？、\s])呃([，。！？、\s]|$)',
    r'(^|[，。！？、\s])额([，。！？、\s]|$)',
    r'(^|[，。！？、\s])就是([，。！？、\s]|$)',
    r'(^|[，。！？、\s])那个([，。！？、\s]|$)',
]

FALLBACK_T2S_PAIRS = {
    '開': '开',
    '體': '体',
    '驗': '验',
    '臺': '台',
    '灣': '湾',
    '節': '节',
    '語': '语',
    '說': '说',
    '話': '话',
    '廣': '广',
    '東': '东',
    '國': '国',
    '門': '门',
    '風': '风',
    '車': '车',
    '電': '电',
    '腦': '脑',
    '網': '网',
    '頁': '页',
    '標': '标',
    '題': '题',
    '內': '内',
    '容': '容',
    '現': '现',
    '場': '场',
    '長': '长',
    '應': '应',
    '該': '该',
    '來': '来',
    '對': '对',
    '個': '个',
    '們': '们',
    '為': '为',
    '與': '与',
    '這': '这',
    '那': '那',
    '時': '时',
    '間': '间',
    '後': '后',
    '前': '前',
    '會': '会',
    '還': '还',
    '過': '过',
    '點': '点',
    '線': '线',
    '園': '园',
    '數': '数',
    '據': '据',
    '產': '产',
    '業': '业',
    '發': '发',
    '變': '变',
    '區': '区',
    '機': '机',
    '構': '构',
    '買': '买',
    '賣': '卖',
    '價': '价',
    '錢': '钱',
    '錄': '录',
    '轉': '转',
    '檔': '档',
    '訊': '讯',
    '問': '问',
    '題': '题',
    '優': '优',
    '勢': '势',
    '劃': '划',
    '劉': '刘',
}

FALLBACK_TRADITIONAL_TO_SIMPLIFIED = str.maketrans(FALLBACK_T2S_PAIRS)

FALLBACK_SIMPLIFIED_TO_TRADITIONAL = str.maketrans({
    simplified: traditional
    for traditional, simplified in FALLBACK_T2S_PAIRS.items()
})


def normalize_text(text: str) -> str:
    text = (text or '').strip()
    return re.sub(r'\s+', ' ', text)


@lru_cache(maxsize=4)
def _opencc_converter(config: str):
    try:
        from opencc import OpenCC
    except Exception:
        return None
    try:
        return OpenCC(config)
    except Exception:
        return None


def normalize_chinese_variant(text: str, variant: str = 'simplified') -> str:
    if variant == 'original':
        return text
    if variant == 'traditional':
        converter = _opencc_converter('s2t')
        if converter is not None:
            return converter.convert(text)
        return text.translate(FALLBACK_SIMPLIFIED_TO_TRADITIONAL)

    converter = _opencc_converter('t2s')
    if converter is not None:
        return converter.convert(text)
    return text.translate(FALLBACK_TRADITIONAL_TO_SIMPLIFIED)


def clean_text(text: str, remove_fillers: bool = True, chinese_variant: str = 'simplified') -> str:
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
    cleaned = cleaned.strip(' ，。！？；：')
    return normalize_chinese_variant(cleaned, chinese_variant)
