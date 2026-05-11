#!/usr/bin/env python3
"""
本地优先音频转写脚本：发言人标注 + 自动分句 + 自动分节 + 文本清洗

支持：
- 本地/离线运行（HF_HUB_OFFLINE / TRANSFORMERS_OFFLINE）
- ASR 引擎：transformers / faster-whisper，可 auto 回退
- pyannote 发言人分离
- 文本清洗：口语词、重复词、技术词归一、轻量错别字修正
- 输出文本（每句带时间戳+说话人）及 JSON
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import wave
from functools import lru_cache
from pathlib import Path
from typing import List, Optional, Tuple

try:
    from packages.python_worker.asr_engines import (
        ASRUtterance,
        DEFAULT_QWEN_ALIGNER_MODEL,
        DEFAULT_QWEN_ASR_MODEL,
        transcribe_with_provider,
    )
except ModuleNotFoundError:
    from asr_engines import ASRUtterance, DEFAULT_QWEN_ALIGNER_MODEL, DEFAULT_QWEN_ASR_MODEL, transcribe_with_provider

try:
    from packages.python_worker.text_refinement import (
        DEFAULT_TEXT_MODEL_REPOSITORY,
        QwenTranscriptRefiner,
        apply_refinement_to_utterances,
    )
except ImportError:
    from text_refinement import (
        DEFAULT_TEXT_MODEL_REPOSITORY,
        QwenTranscriptRefiner,
        apply_refinement_to_utterances,
    )


PRESET_DEFAULTS = {
    "production": {
        "engine": "auto",
        "asr_provider": "auto",
        "asr_model": "openai/whisper-large-v3",
        "asr_language": "zh",
        "section_seconds": 180,
        "chunk_length": 25,
        "batch_size": 4,
        "beam_size": 6,
        "vad": True,
    },
    "balanced": {
        "engine": "auto",
        "asr_provider": "whisper",
        "asr_model": "openai/whisper-base",
        "asr_language": "zh",
        "section_seconds": 240,
        "chunk_length": 30,
        "batch_size": 4,
        "beam_size": 5,
        "vad": True,
    },
    "lite": {
        "engine": "transformers",
        "asr_provider": "whisper",
        "asr_model": "openai/whisper-tiny",
        "asr_language": "zh",
        "section_seconds": 300,
        "chunk_length": 20,
        "batch_size": 2,
        "beam_size": 4,
        "vad": False,
    },
}

FILLER_PATTERNS = [
    r"(^|[，。！？、\s])嗯([，。！？、\s]|$)",
    r"(^|[，。！？、\s])啊([，。！？、\s]|$)",
    r"(^|[，。！？、\s])呃([，。！？、\s]|$)",
    r"(^|[，。！？、\s])额([，。！？、\s]|$)",
    r"(^|[，。！？、\s])就是([，。！？、\s]|$)",
    r"(^|[，。！？、\s])那个([，。！？、\s]|$)",
]

FALLBACK_T2S_PAIRS = {
    "開": "开",
    "體": "体",
    "驗": "验",
    "臺": "台",
    "灣": "湾",
    "節": "节",
    "語": "语",
    "說": "说",
    "話": "话",
    "廣": "广",
    "東": "东",
    "國": "国",
    "門": "门",
    "風": "风",
    "車": "车",
    "電": "电",
    "腦": "脑",
    "網": "网",
    "頁": "页",
    "標": "标",
    "題": "题",
    "內": "内",
    "現": "现",
    "場": "场",
    "長": "长",
    "應": "应",
    "該": "该",
    "來": "来",
    "對": "对",
    "個": "个",
    "們": "们",
    "為": "为",
    "與": "与",
    "這": "这",
    "時": "时",
    "間": "间",
    "後": "后",
    "會": "会",
    "還": "还",
    "過": "过",
    "點": "点",
    "線": "线",
    "園": "园",
    "數": "数",
    "據": "据",
    "產": "产",
    "業": "业",
    "發": "发",
    "變": "变",
    "區": "区",
    "機": "机",
    "構": "构",
    "買": "买",
    "賣": "卖",
    "價": "价",
    "錢": "钱",
    "錄": "录",
    "轉": "转",
    "檔": "档",
    "訊": "讯",
    "問": "问",
    "優": "优",
    "勢": "势",
    "劃": "划",
    "劉": "刘",
}

FALLBACK_TRADITIONAL_TO_SIMPLIFIED = str.maketrans(FALLBACK_T2S_PAIRS)
FALLBACK_SIMPLIFIED_TO_TRADITIONAL = str.maketrans({
    simplified: traditional
    for traditional, simplified in FALLBACK_T2S_PAIRS.items()
})


def fmt_time(seconds: float) -> str:
    total_ms = int(max(seconds, 0) * 1000)
    h, rem = divmod(total_ms, 3600000)
    m, rem = divmod(rem, 60000)
    s, ms = divmod(rem, 1000)
    return f"{h:02d}:{m:02d}:{s:02d}.{ms:03d}"


def run(cmd: List[str]) -> None:
    subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)


def ensure_wav16k_mono(src: Path, out: Path) -> Path:
    out.parent.mkdir(parents=True, exist_ok=True)
    if out.exists() and out.stat().st_size > 0:
        return out
    cmd = [
        "ffmpeg", "-y", "-i", str(src),
        "-ac", "1", "-ar", "16000", "-c:a", "pcm_s16le", str(out),
    ]
    run(cmd)
    return out


def temp_wav_path(audio: Path) -> Path:
    stat = audio.stat()
    identity = f"{audio.resolve()}:{stat.st_size}:{stat.st_mtime_ns}"
    digest = hashlib.sha1(identity.encode("utf-8")).hexdigest()[:12]
    stem = re.sub(r"[^A-Za-z0-9._-]+", "_", audio.stem).strip("._")[:80] or "audio"
    return Path("/tmp") / f"{stem}_{digest}_16k.wav"


def normalize_text(t: str) -> str:
    t = (t or "").strip()
    t = re.sub(r"\s+", " ", t)
    return t


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


def normalize_chinese_variant(text: str, variant: str = "simplified") -> str:
    if variant == "original":
        return text
    if variant == "traditional":
        converter = _opencc_converter("s2t")
        if converter is not None:
            return converter.convert(text)
        return text.translate(FALLBACK_SIMPLIFIED_TO_TRADITIONAL)

    converter = _opencc_converter("t2s")
    if converter is not None:
        return converter.convert(text)
    return text.translate(FALLBACK_TRADITIONAL_TO_SIMPLIFIED)


def clean_text(text: str, remove_fillers: bool = True, chinese_variant: str = "simplified") -> str:
    t = normalize_text(text)
    if not t:
        return t

    # 清掉明显重复，如“这个这个”“就是就是”
    t = re.sub(r"\b(\w+)(\s+\1\b)+", r"\1", t)
    t = re.sub(r"([\u4e00-\u9fffA-Za-z]{1,8})\1{1,}", r"\1", t)

    if remove_fillers:
        for patt in FILLER_PATTERNS:
            t = re.sub(patt, r"\1\2" if "\2" in patt else " ", t)
        t = re.sub(r"(^|[，。！？、\s])(然后|我觉得|你知道)([，。！？、\s]|$)", r"\1\3", t)

    t = re.sub(r"\s+", " ", t)
    t = re.sub(r"([，。！？；：]){2,}", r"\1", t)
    t = t.strip(" ，。！？；：")
    return normalize_chinese_variant(t, chinese_variant)


def _merge_consecutive(chunks: List[ASRUtterance], gap: float = 0.25, chinese_variant: str = "simplified") -> List[ASRUtterance]:
    if not chunks:
        return chunks
    chunks = sorted(chunks, key=lambda x: x.start)
    merged = [chunks[0]]
    for u in chunks[1:]:
        last = merged[-1]
        same_speaker = u.speaker == last.speaker
        close_gap = (u.start - last.end) <= gap
        if same_speaker and close_gap:
            cand = clean_text(f"{last.text} {u.text}", chinese_variant=chinese_variant)
            if len(cand) <= 400:
                last.text = cand
                last.end = max(last.end, u.end)
                if last.score is None:
                    last.score = u.score
                continue
        merged.append(u)
    return merged


def _dedup_chunks(chunks: List[ASRUtterance], chinese_variant: str = "simplified") -> List[ASRUtterance]:
    chunks = sorted(chunks, key=lambda x: x.start)
    out: List[ASRUtterance] = []
    seen = set()
    for c in chunks:
        c.text = clean_text(c.text, chinese_variant=chinese_variant)
        if not c.text:
            continue
        key = (round(c.start, 2), round(c.end, 2), c.text)
        if key in seen:
            continue
        if out:
            prev = out[-1]
            if c.start <= prev.end + 0.4 and (c.text in prev.text or prev.text in c.text):
                continue
        seen.add(key)
        out.append(c)
    return out


def _load_wav_for_pyannote(wav: Path) -> dict:
    import torch

    audio, sample_rate = _read_wav_float32(wav)
    return {
        "waveform": torch.from_numpy(audio).unsqueeze(0),
        "sample_rate": sample_rate,
    }


def _read_wav_float32(wav: Path) -> Tuple[np.ndarray, int]:
    import numpy as np

    with wave.open(str(wav), "rb") as reader:
        channels = reader.getnchannels()
        sample_width = reader.getsampwidth()
        sample_rate = reader.getframerate()
        frames = reader.readframes(reader.getnframes())

    if sample_width == 1:
        audio = np.frombuffer(frames, dtype=np.uint8).astype(np.float32)
        audio = (audio - 128.0) / 128.0
    elif sample_width == 2:
        audio = np.frombuffer(frames, dtype="<i2").astype(np.float32) / 32768.0
    elif sample_width == 4:
        audio = np.frombuffer(frames, dtype="<i4").astype(np.float32) / 2147483648.0
    else:
        raise ValueError(f"不支持的 WAV 位宽: {sample_width * 8}")

    if channels > 1:
        audio = audio.reshape(-1, channels).mean(axis=1)

    return audio.astype(np.float32, copy=False), sample_rate


def build_diarization_pipeline(token: Optional[str] = None, model: Optional[str] = None):
    try:
        import inspect
        import torch
        from pyannote.audio import Pipeline
        from pyannote.audio.core.task import Specifications, Problem, Resolution

        # 兼容 PyTorch 2.6+ weights_only=True 默认行为
        try:
            torch.serialization.add_safe_globals([
                torch.torch_version.TorchVersion,
                Specifications,
                Problem,
                Resolution,
            ])
        except Exception:
            pass

        auth = token or os.environ.get("HF_TOKEN")
        model_name = model or "pyannote/speaker-diarization-3.1"
        kwargs = {}
        params = inspect.signature(Pipeline.from_pretrained).parameters
        if auth:
            if "token" in params:
                kwargs["token"] = auth
            elif "use_auth_token" in params:
                kwargs["use_auth_token"] = auth
        pipe = Pipeline.from_pretrained(model_name, **kwargs)
        return pipe
    except Exception as e:
        print(f"[warn] 发言人分离未启用：{type(e).__name__}: {e}")
        return None


def infer_speakers(audio_wav: Path, diarization_pipe):
    if diarization_pipe is None:
        return []
    spans = []
    diar = diarization_pipe(_load_wav_for_pyannote(audio_wav))
    for seg, _, spk in diar.itertracks(yield_label=True):
        spans.append((float(seg.start), float(seg.end), str(spk)))
    return spans


def _infer_speaker(spans: List[Tuple[float, float, str]], start: float, end: float) -> str:
    if not spans:
        return "说话人1"
    best_overlap = -1.0
    best_spk = spans[0][2]
    for s, e, spk in spans:
        overlap = max(0.0, min(end, e) - max(start, s))
        if overlap > best_overlap:
            best_overlap = overlap
            best_spk = spk
    if best_overlap <= 0:
        mid = (start + end) / 2 if end > start else start
        nearest = float("inf")
        for s, e, spk in spans:
            d = min(abs(mid - s), abs(mid - e))
            if d < nearest:
                nearest = d
                best_spk = spk
    return best_spk


def apply_speakers(utterances: List[ASRUtterance], spans: List[Tuple[float, float, str]]) -> None:
    if not spans:
        return
    for u in utterances:
        u.speaker = _infer_speaker(spans, u.start, u.end)


def _normalize_speaker(raw: str, mp: dict) -> str:
    if raw and not _looks_diarization_speaker(raw):
        return raw
    if raw in mp:
        return mp[raw]
    if raw.startswith("说话人"):
        mp[raw] = raw
        return raw
    m = re.search(r"(\d+)$", raw)
    idx = int(m.group(1)) + 1 if m else len(mp) + 1
    label = f"说话人{idx}"
    mp[raw] = label
    return label


def _looks_diarization_speaker(raw: str) -> bool:
    if raw.startswith("说话人"):
        return True
    return re.fullmatch(r"(?:SPEAKER[_ -]?)?\d+", raw, flags=re.IGNORECASE) is not None


def normalize_utterance_speakers(utterances: List[ASRUtterance]) -> None:
    spk_map = {}
    for utterance in sorted(utterances, key=lambda x: x.start):
        utterance.speaker = _normalize_speaker(utterance.speaker, spk_map)


def split_sentences(text: str, max_len: int = 44) -> List[str]:
    txt = clean_text(text)
    if not txt:
        return []
    parts = re.split(r"(?<=[。！？!?；;，,：:])", txt)
    lines = []
    for p in parts:
        p = p.strip()
        if not p:
            continue
        pieces = re.split(r"(?<=[，,、；;])", p)
        cur = ""
        for seg in pieces:
            seg = seg.strip()
            if not seg:
                continue
            if len(cur) + len(seg) <= max_len:
                cur = (cur + seg).strip()
            else:
                if cur:
                    lines.append(cur)
                cur = seg
        if cur:
            lines.append(cur)
    final = []
    for ln in lines:
        if len(ln) <= max_len:
            final.append(ln)
        else:
            for i in range(0, len(ln), max_len):
                final.append(ln[i : i + max_len])
    return final


def export_text(utterances: List[ASRUtterance], section_seconds: int, out_file: Path, prefix: str = "分节") -> None:
    out_file.parent.mkdir(parents=True, exist_ok=True)
    if not utterances:
        out_file.write_text("", encoding="utf-8")
        return
    with out_file.open("w", encoding="utf-8") as f:
        f.write(f"【{prefix}1】（约 {section_seconds} 秒）\n\n")
        section_id = 1
        section_start = 0.0
        section_end = section_start + section_seconds
        spk_map = {}
        for utt in sorted(utterances, key=lambda x: x.start):
            while utt.start >= section_end:
                section_id += 1
                section_start = section_end
                section_end = section_start + section_seconds
                f.write("\n")
                f.write(f"【{prefix}{section_id}】（{fmt_time(section_start)} - {fmt_time(section_end)}）\n\n")
            speaker = _normalize_speaker(utt.speaker, spk_map)
            for sentence in split_sentences(utt.text):
                if not sentence:
                    continue
                if getattr(f, "_last_sentence", None) == (speaker, sentence):
                    continue
                f.write(f"[{fmt_time(utt.start)} - {fmt_time(utt.end)}] {speaker}: {sentence}\n")
                f._last_sentence = (speaker, sentence)
        f.write("\n")


def export_json(utterances: List[ASRUtterance], out_file: Path) -> None:
    payload = [
        {
            "start": round(u.start, 3),
            "end": round(u.end, 3),
            "speaker": u.speaker,
            "text": u.text,
            "score": u.score,
        }
        for u in sorted(utterances, key=lambda x: x.start)
    ]
    out_file.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def apply_preset_defaults(args):
    preset = PRESET_DEFAULTS[args.preset]
    if args.asr_provider is None:
        args.asr_provider = preset["asr_provider"]
    if args.asr_model is None:
        args.asr_model = preset["asr_model"]
    if args.section_seconds == 0:
        args.section_seconds = preset["section_seconds"]
    if args.chunk_length == 0:
        args.chunk_length = preset["chunk_length"]
    if args.batch_size == 0:
        args.batch_size = preset["batch_size"]
    if args.beam_size == 0:
        args.beam_size = preset["beam_size"]
    if args.language == "zh":
        args.language = preset.get("asr_language", "zh")
    if args.no_vad:
        args.vad = False
    else:
        args.vad = bool(args.vad or preset["vad"])
    return args


def parse_args(argv=None):
    ap = argparse.ArgumentParser(description="Audio ASR with speaker labels + sentence split + cleanup")
    ap.add_argument("--audio", required=True, help="输入音频")
    ap.add_argument("--output", required=True, help="文本输出路径")
    ap.add_argument("--preset", default="production", choices=sorted(PRESET_DEFAULTS.keys()), help="预置配置")
    ap.add_argument("--asr-model", default=None, help="ASR 模型名/本地路径")
    ap.add_argument("--asr-provider", default=None, choices=["auto", "whisper", "qwen3", "mimo"], help="ASR provider（默认按预置选择）")
    ap.add_argument("--language", default="zh", help="ASR 语言码")
    ap.add_argument("--section-seconds", type=int, default=0, help="每段秒数（0=预置值）")
    ap.add_argument("--chunk-length", type=int, default=0, help="Whisper chunk 长度（0=预置值）")
    ap.add_argument("--batch-size", type=int, default=0, help="transformers 批大小（0=预置值）")
    ap.add_argument("--asr-device", default="cpu", choices=["cpu", "cuda"], help="ASR 设备")
    ap.add_argument("--engine", default="auto", choices=["auto", "transformers", "faster-whisper"], help="ASR 引擎")
    ap.add_argument("--qwen-asr-model", default=DEFAULT_QWEN_ASR_MODEL, help="Qwen3-ASR 模型名或本地路径")
    ap.add_argument("--qwen-aligner-model", default=DEFAULT_QWEN_ALIGNER_MODEL, help="Qwen3 ForcedAligner 模型名或本地路径")
    ap.add_argument("--mimo-model-path", default=None, help="MiMo-V2.5-ASR 模型目录")
    ap.add_argument("--mimo-tokenizer-path", default=None, help="MiMo-Audio-Tokenizer 目录")
    ap.add_argument("--mimo-source-dir", default=None, help="MiMo-V2.5-ASR 官方源码目录")
    ap.add_argument("--beam-size", type=int, default=0, help="faster-whisper beam_size")
    ap.add_argument("--vad", action="store_true", help="faster-whisper 开启 VAD")
    ap.add_argument("--no-vad", action="store_true", help="显式关闭 VAD")
    ap.add_argument("--diarize", action="store_true", help="启用发言人分离")
    ap.add_argument("--diarization-model", default=None, help="pyannote 模型名或本地路径")
    ap.add_argument("--text-model", default=None, help=f"文本后处理模型名或本地路径（默认 {DEFAULT_TEXT_MODEL_REPOSITORY}）")
    ap.add_argument("--text-model-device", default="cpu", choices=["cpu", "cuda", "mps", "auto"], help="文本后处理模型设备")
    ap.add_argument("--skip-text-refinement", action="store_true", help="跳过模型文本修正和姓名识别")
    ap.add_argument("--hf-token", default=None, help="HF token")
    ap.add_argument("--offline", action="store_true", help="强制离线")
    ap.add_argument("--keep-fillers", action="store_true", help="保留口语词，不做清洗")
    ap.add_argument("--chinese-variant", default="simplified", choices=["simplified", "traditional", "original"], help="中文输出字形")
    ap.add_argument("--json", default=None, help="导出 JSON")
    return ap.parse_args(argv)


def main() -> None:
    args = parse_args()
    args = apply_preset_defaults(args)
    audio = Path(args.audio).expanduser().resolve()
    out_txt = Path(args.output).expanduser().resolve()
    if not audio.exists():
        raise FileNotFoundError(f"找不到音频文件: {audio}")

    if args.offline:
        os.environ["HF_HUB_OFFLINE"] = "1"
        os.environ["TRANSFORMERS_OFFLINE"] = "1"

    wav = ensure_wav16k_mono(audio, temp_wav_path(audio))

    asr_chunks, final_engine, final_model = transcribe_with_provider(
        provider=args.asr_provider,
        wav=wav,
        whisper_model=args.asr_model,
        lang=args.language,
        device=args.asr_device,
        chunk_s=args.chunk_length,
        batch_size=args.batch_size,
        whisper_engine=args.engine,
        beam=args.beam_size,
        vad=args.vad,
        qwen_asr_model=args.qwen_asr_model,
        qwen_aligner_model=args.qwen_aligner_model,
        mimo_model_path=args.mimo_model_path,
        mimo_tokenizer_path=args.mimo_tokenizer_path,
        mimo_source_dir=args.mimo_source_dir,
    )

    for chunk in asr_chunks:
        chunk.text = clean_text(
            chunk.text,
            remove_fillers=not args.keep_fillers,
            chinese_variant=args.chinese_variant,
        )
    asr_chunks = _dedup_chunks(
        _merge_consecutive(asr_chunks, chinese_variant=args.chinese_variant),
        chinese_variant=args.chinese_variant,
    )

    speaker_spans = []
    if args.diarize:
        diarization_pipe = build_diarization_pipeline(args.hf_token, args.diarization_model)
        try:
            speaker_spans = infer_speakers(wav, diarization_pipe) if diarization_pipe is not None else []
        except Exception as e:
            print(f"[warn] 发言人分离执行失败：{type(e).__name__}: {e}")
            speaker_spans = []
    apply_speakers(asr_chunks, speaker_spans)
    normalize_utterance_speakers(asr_chunks)

    if not args.skip_text_refinement:
        try:
            text_model = (
                args.text_model
                or os.environ.get("PODCAST_TEXT_MODEL")
                or os.environ.get("PODCAST_TEXT_MODEL_REPOSITORY")
                or DEFAULT_TEXT_MODEL_REPOSITORY
            )
            refinement = QwenTranscriptRefiner(model_ref=text_model, device=args.text_model_device).refine(asr_chunks)
            apply_refinement_to_utterances(asr_chunks, refinement)
        except Exception as e:
            print(f"[warn] 文本模型后处理未启用：{type(e).__name__}: {e}")

    export_text(asr_chunks, args.section_seconds, out_txt)
    if args.json:
        export_json(asr_chunks, Path(args.json).expanduser().resolve())

    if not asr_chunks:
        print("结果为空，建议检查音频质量、语言参数或模型下载")
        return

    print(f"预置：{args.preset}")
    print(f"ASR provider：{args.asr_provider}")
    print(f"ASR 后端：{final_engine}")
    print(f"ASR 模型：{final_model}")
    print(f"已输出：{out_txt}")
    if args.json:
        print(f"JSON：{Path(args.json).resolve()}")
    print(f"说话人标签：{sorted(set(u.speaker for u in asr_chunks))}")
    if args.diarize and not speaker_spans:
        print("未识别到发言人时间轴，已降级为“说话人1”。")


if __name__ == "__main__":
    main()
