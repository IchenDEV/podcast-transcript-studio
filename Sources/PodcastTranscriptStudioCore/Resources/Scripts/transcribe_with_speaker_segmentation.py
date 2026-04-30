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
import json
import os
import re
import subprocess
from dataclasses import dataclass
from pathlib import Path
from typing import List, Optional, Tuple

from transformers import pipeline


PRESET_DEFAULTS = {
    "production": {
        "engine": "auto",
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
        "asr_model": "openai/whisper-tiny",
        "asr_language": "zh",
        "section_seconds": 300,
        "chunk_length": 20,
        "batch_size": 2,
        "beam_size": 4,
        "vad": False,
    },
}

TECH_TERM_REPLACEMENTS = {
    r"\bAgin\b": "Agent",
    r"\bAGEN\b": "Agent",
    r"\bAgen\b": "Agent",
    r"\bagent\b": "Agent",
    r"\bskills\b": "Skills",
    r"\bskill\b": "Skill",
    r"\bAPI[s]?\b": "API",
    r"\bcontext\b": "Context",
    r"\bCloud Code\b": "Cloud Code",
    r"\bNATV\b": "Native",
}

CHINESE_REPLACEMENTS = {
    "极客公園": "极客公园",
    "開始联系": "开始连接",
    "Linksstart": "LinkStart",
    "一樣": "AI",
    "挨振": "Agent",
    "挨阵": "Agent",
    "A盛": "Agent",
    "A陣": "Agent",
    "偷肯": "Token",
    "猫都": "模型",
    "副能": "赋能",
    "元身": "原生",
    "语论": "舆论",
    "突弊": "toB",
    "科公园": "极客公园",
}

FILLER_PATTERNS = [
    r"(^|[，。！？、\s])嗯([，。！？、\s]|$)",
    r"(^|[，。！？、\s])啊([，。！？、\s]|$)",
    r"(^|[，。！？、\s])呃([，。！？、\s]|$)",
    r"(^|[，。！？、\s])额([，。！？、\s]|$)",
    r"(^|[，。！？、\s])就是([，。！？、\s]|$)",
    r"(^|[，。！？、\s])那个([，。！？、\s]|$)",
]


@dataclass
class ASRUtterance:
    start: float
    end: float
    text: str
    speaker: str = "说话人1"
    score: Optional[float] = None


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


def normalize_text(t: str) -> str:
    t = (t or "").strip()
    t = re.sub(r"\s+", " ", t)
    return t


def clean_text(text: str, remove_fillers: bool = True) -> str:
    t = normalize_text(text)
    if not t:
        return t

    for patt, repl in TECH_TERM_REPLACEMENTS.items():
        t = re.sub(patt, repl, t, flags=re.IGNORECASE)
    for src, dst in CHINESE_REPLACEMENTS.items():
        t = t.replace(src, dst)

    # 清掉明显重复，如“这个这个”“就是就是”
    t = re.sub(r"\b(\w+)(\s+\1\b)+", r"\1", t)
    t = re.sub(r"([\u4e00-\u9fffA-Za-z]{1,8})\1{1,}", r"\1", t)

    if remove_fillers:
        for patt in FILLER_PATTERNS:
            t = re.sub(patt, r"\1\2" if "\2" in patt else " ", t)
        t = re.sub(r"(^|[，。！？、\s])(然后|我觉得|你知道)([，。！？、\s]|$)", r"\1\3", t)

    t = re.sub(r"\s+", " ", t)
    t = re.sub(r"([，。！？；：]){2,}", r"\1", t)
    return t.strip(" ，。！？；：")


def _coerce_timestamps(item) -> Tuple[float, float]:
    start = item.get("start")
    end = item.get("end")
    if start is None or end is None:
        ts = item.get("timestamp")
        if isinstance(ts, (list, tuple)) and len(ts) >= 2:
            start, end = ts[0], ts[1]
    if start is None:
        start = 0.0
    if end is None:
        end = start
    return float(start), float(end)


def _merge_consecutive(chunks: List[ASRUtterance], gap: float = 0.25) -> List[ASRUtterance]:
    if not chunks:
        return chunks
    chunks = sorted(chunks, key=lambda x: x.start)
    merged = [chunks[0]]
    for u in chunks[1:]:
        last = merged[-1]
        same_speaker = u.speaker == last.speaker
        close_gap = (u.start - last.end) <= gap
        if same_speaker and close_gap:
            cand = clean_text(f"{last.text} {u.text}")
            if len(cand) <= 400:
                last.text = cand
                last.end = max(last.end, u.end)
                if last.score is None:
                    last.score = u.score
                continue
        merged.append(u)
    return merged


def _dedup_chunks(chunks: List[ASRUtterance]) -> List[ASRUtterance]:
    chunks = sorted(chunks, key=lambda x: x.start)
    out: List[ASRUtterance] = []
    seen = set()
    for c in chunks:
        c.text = clean_text(c.text)
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


def extract_chunks(asr_result) -> List[ASRUtterance]:
    chunks: List[ASRUtterance] = []
    if isinstance(asr_result, dict):
        raw_chunks = asr_result.get("chunks")
        if isinstance(raw_chunks, list) and raw_chunks:
            for item in raw_chunks:
                if not isinstance(item, dict):
                    continue
                txt = clean_text(item.get("text") or "")
                if not txt:
                    continue
                start, end = _coerce_timestamps(item)
                if end <= start:
                    end = start + 0.5
                chunks.append(ASRUtterance(start=start, end=end, text=txt))
            if chunks:
                return _dedup_chunks(_merge_consecutive(chunks))

        txt = clean_text(asr_result.get("text") or "")
        if txt:
            chunks.append(ASRUtterance(0.0, 0.5, text=txt))
            return chunks

    if isinstance(asr_result, list):
        for item in asr_result:
            if not isinstance(item, dict):
                continue
            txt = clean_text(item.get("text") or "")
            if not txt:
                continue
            start, end = _coerce_timestamps(item)
            if end <= start:
                end = start + 0.5
            chunks.append(ASRUtterance(start=start, end=end, text=txt))

    prev_end = 0.0
    for idx, u in enumerate(chunks):
        if u.end <= u.start:
            u.end = u.start + 0.5
        if u.start <= 0 and idx > 0:
            u.start = prev_end
            if u.end <= u.start:
                u.end = u.start + 0.5
        prev_end = max(prev_end, u.end)

    return _dedup_chunks(_merge_consecutive(chunks))


def extract_chunks_faster_whisper(result) -> List[ASRUtterance]:
    if result is None:
        return []
    segments = result[0] if isinstance(result, tuple) and len(result) >= 1 else result
    chunks: List[ASRUtterance] = []
    for seg in segments:
        if isinstance(seg, dict):
            txt = clean_text(seg.get("text", ""))
            start = float(seg.get("start", 0.0))
            end = float(seg.get("end", start + 0.5))
            score = seg.get("avg_logprob")
        else:
            txt = clean_text(getattr(seg, "text", ""))
            start = float(getattr(seg, "start", 0.0))
            end = float(getattr(seg, "end", start + 0.5))
            score = getattr(seg, "avg_logprob", None)
        if not txt:
            continue
        if end <= start:
            end = start + 0.5
        chunks.append(ASRUtterance(start=start, end=end, text=txt, score=score))
    return _dedup_chunks(_merge_consecutive(chunks))


def _has_module(module_name: str) -> bool:
    try:
        import importlib.util
        return importlib.util.find_spec(module_name) is not None
    except Exception:
        return False


def build_asr_pipeline(model: str, lang: str, device: str = "cpu", chunk_s: int = 30, batch: int = 4, engine: str = "transformers"):
    if engine == "faster-whisper":
        if not _has_module("faster_whisper"):
            raise RuntimeError("faster-whisper 未安装")
        from faster_whisper import WhisperModel
        compute_type = "float16" if device.lower() == "cuda" else "int8"
        dev = "cuda" if device.lower() == "cuda" else "cpu"
        return WhisperModel(model, device=dev, compute_type=compute_type)

    device_id = 0 if device.lower() == "cuda" else -1
    gen_kwargs = {"task": "transcribe"}
    if lang and lang.lower() != "auto":
        gen_kwargs["language"] = lang
    return pipeline(
        "automatic-speech-recognition",
        model=model,
        device=device_id,
        return_timestamps=True,
        chunk_length_s=chunk_s,
        stride_length_s=(4, 2),
        batch_size=batch,
        generate_kwargs=gen_kwargs,
    )


def transcribe_audio(asr_engine, wav: Path, backend: str, lang: str, chunk_s: int, batch_size: int, beam: int = 5, vad: bool = False):
    if backend == "faster-whisper":
        return asr_engine.transcribe(
            str(wav),
            beam_size=beam,
            language=lang if lang and lang.lower() != "auto" else None,
            vad_filter=vad,
            word_timestamps=True,
        )[0]
    return asr_engine(str(wav), batch_size=batch_size, chunk_length_s=chunk_s)


def build_diarization_pipeline(token: Optional[str] = None, model: Optional[str] = None):
    try:
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
        pipe = Pipeline.from_pretrained(model_name, use_auth_token=auth)
        return pipe
    except Exception as e:
        print(f"[warn] 发言人分离未启用：{type(e).__name__}: {e}")
        return None


def infer_speakers(audio_wav: Path, diarization_pipe):
    if diarization_pipe is None:
        return []
    spans = []
    diar = diarization_pipe(str(audio_wav))
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


def pick_engine(requested: str) -> List[str]:
    if requested == "faster-whisper":
        return ["faster-whisper", "transformers"]
    if requested == "transformers":
        return ["transformers"]
    if _has_module("faster_whisper"):
        return ["faster-whisper", "transformers"]
    return ["transformers", "faster-whisper"]


def build_asr_with_fallback(model: str, lang: str, device: str, chunk_s: int, batch: int, requested: str):
    last_error: Optional[Exception] = None
    for engine in pick_engine(requested):
        try:
            asr = build_asr_pipeline(model=model, lang=lang, device=device, chunk_s=chunk_s, batch=batch, engine=engine)
            print(f"[info] 使用 ASR 后端: {engine}")
            return asr, engine
        except Exception as e:
            print(f"[warn] 尝试 {engine} 失败: {type(e).__name__}: {e}")
            last_error = e
    raise RuntimeError(f"ASR 引擎初始化失败: {last_error}")


def apply_preset_defaults(args):
    preset = PRESET_DEFAULTS[args.preset]
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


def parse_args():
    ap = argparse.ArgumentParser(description="Audio ASR with speaker labels + sentence split + cleanup")
    ap.add_argument("--audio", required=True, help="输入音频")
    ap.add_argument("--output", required=True, help="文本输出路径")
    ap.add_argument("--preset", default="production", choices=sorted(PRESET_DEFAULTS.keys()), help="预置配置")
    ap.add_argument("--asr-model", default=None, help="ASR 模型名/本地路径")
    ap.add_argument("--language", default="zh", help="ASR 语言码")
    ap.add_argument("--section-seconds", type=int, default=0, help="每段秒数（0=预置值）")
    ap.add_argument("--chunk-length", type=int, default=0, help="Whisper chunk 长度（0=预置值）")
    ap.add_argument("--batch-size", type=int, default=0, help="transformers 批大小（0=预置值）")
    ap.add_argument("--asr-device", default="cpu", choices=["cpu", "cuda"], help="ASR 设备")
    ap.add_argument("--engine", default="auto", choices=["auto", "transformers", "faster-whisper"], help="ASR 引擎")
    ap.add_argument("--beam-size", type=int, default=0, help="faster-whisper beam_size")
    ap.add_argument("--vad", action="store_true", help="faster-whisper 开启 VAD")
    ap.add_argument("--no-vad", action="store_true", help="显式关闭 VAD")
    ap.add_argument("--diarize", action="store_true", help="启用发言人分离")
    ap.add_argument("--diarization-model", default=None, help="pyannote 模型名或本地路径")
    ap.add_argument("--hf-token", default=None, help="HF token")
    ap.add_argument("--offline", action="store_true", help="强制离线")
    ap.add_argument("--keep-fillers", action="store_true", help="保留口语词，不做清洗")
    ap.add_argument("--json", default=None, help="导出 JSON")
    return ap.parse_args()


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

    wav = ensure_wav16k_mono(audio, Path("/tmp") / f"{audio.stem}_16k.wav")

    asr, final_engine = build_asr_with_fallback(
        model=args.asr_model,
        lang=args.language,
        device=args.asr_device,
        chunk_s=args.chunk_length,
        batch=args.batch_size,
        requested=args.engine,
    )

    raw_result = transcribe_audio(
        asr_engine=asr,
        wav=wav,
        backend=final_engine,
        lang=args.language,
        chunk_s=args.chunk_length,
        batch_size=args.batch_size,
        beam=args.beam_size,
        vad=args.vad,
    )

    if final_engine == "faster-whisper":
        asr_chunks = extract_chunks_faster_whisper(raw_result)
    else:
        asr_chunks = extract_chunks(raw_result)

    for chunk in asr_chunks:
        chunk.text = clean_text(chunk.text, remove_fillers=not args.keep_fillers)
    asr_chunks = _dedup_chunks(_merge_consecutive(asr_chunks))

    speaker_spans = []
    if args.diarize:
        diarization_pipe = build_diarization_pipeline(args.hf_token, args.diarization_model)
        speaker_spans = infer_speakers(wav, diarization_pipe) if diarization_pipe is not None else []
    apply_speakers(asr_chunks, speaker_spans)

    export_text(asr_chunks, args.section_seconds, out_txt)
    if args.json:
        export_json(asr_chunks, Path(args.json).expanduser().resolve())

    if not asr_chunks:
        print("结果为空，建议检查音频质量、语言参数或模型下载")
        return

    print(f"预置：{args.preset}")
    print(f"ASR 后端：{final_engine}")
    print(f"ASR 模型：{args.asr_model}")
    print(f"已输出：{out_txt}")
    if args.json:
        print(f"JSON：{Path(args.json).resolve()}")
    print(f"说话人标签：{sorted(set(u.speaker for u in asr_chunks))}")
    if args.diarize and not speaker_spans:
        print("未识别到发言人时间轴，已降级为“说话人1”。")


if __name__ == "__main__":
    main()
