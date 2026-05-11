from __future__ import annotations

import importlib
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, List, Optional, Tuple


DEFAULT_QWEN_ASR_MODEL = "Qwen/Qwen3-ASR-1.7B"
DEFAULT_QWEN_ALIGNER_MODEL = "Qwen/Qwen3-ForcedAligner-0.6B"


class ASRProviderUnavailable(RuntimeError):
    pass


@dataclass
class ASRUtterance:
    start: float
    end: float
    text: str
    speaker: str = "说话人1"
    score: Optional[float] = None


def transcribe_with_provider(
    *,
    provider: str,
    wav: Path,
    whisper_model: str,
    lang: str,
    device: str,
    chunk_s: int,
    batch_size: int,
    whisper_engine: str,
    beam: int,
    vad: bool,
    qwen_asr_model: str,
    qwen_aligner_model: str,
    mimo_model_path: Optional[str],
    mimo_tokenizer_path: Optional[str],
    mimo_source_dir: Optional[str],
) -> Tuple[List[ASRUtterance], str, str]:
    provider = (provider or "whisper").lower()

    if provider == "whisper":
        chunks, engine = transcribe_whisper(
            wav=wav,
            model=whisper_model,
            lang=lang,
            device=device,
            chunk_s=chunk_s,
            batch_size=batch_size,
            requested_engine=whisper_engine,
            beam=beam,
            vad=vad,
        )
        return chunks, f"whisper/{engine}", whisper_model

    if provider == "qwen3":
        chunks = transcribe_qwen3(
            wav=wav,
            lang=lang,
            device=device,
            batch_size=batch_size,
            qwen_asr_model=qwen_asr_model,
            qwen_aligner_model=qwen_aligner_model,
        )
        return chunks, "qwen3", qwen_asr_model

    if provider == "mimo":
        chunks = transcribe_mimo(
            wav=wav,
            lang=lang,
            model_path=mimo_model_path,
            tokenizer_path=mimo_tokenizer_path,
            source_dir=mimo_source_dir,
        )
        return chunks, "mimo", str(mimo_model_path or "")

    if provider == "auto":
        try:
            chunks = transcribe_qwen3(
                wav=wav,
                lang=lang,
                device=device,
                batch_size=batch_size,
                qwen_asr_model=qwen_asr_model,
                qwen_aligner_model=qwen_aligner_model,
                require_cuda=True,
            )
            return chunks, "qwen3", qwen_asr_model
        except Exception as exc:
            print(f"[warn] Qwen3-ASR 不可用，回退 Whisper：{type(exc).__name__}: {exc}")
            chunks, engine = transcribe_whisper(
                wav=wav,
                model=whisper_model,
                lang=lang,
                device=device,
                chunk_s=chunk_s,
                batch_size=batch_size,
                requested_engine=whisper_engine,
                beam=beam,
                vad=vad,
            )
            return chunks, f"whisper/{engine}", whisper_model

    raise ValueError(f"不支持的 ASR provider: {provider}")


def transcribe_whisper(
    *,
    wav: Path,
    model: str,
    lang: str,
    device: str,
    chunk_s: int,
    batch_size: int,
    requested_engine: str,
    beam: int,
    vad: bool,
) -> Tuple[List[ASRUtterance], str]:
    asr, final_engine = build_asr_with_fallback(
        model=model,
        lang=lang,
        device=device,
        chunk_s=chunk_s,
        batch=batch_size,
        requested=requested_engine,
    )

    raw_result = transcribe_whisper_audio(
        asr_engine=asr,
        wav=wav,
        audio_wav=None,
        backend=final_engine,
        lang=lang,
        chunk_s=chunk_s,
        batch_size=batch_size,
        beam=beam,
        vad=vad,
    )
    return raw_result, final_engine


def transcribe_whisper_audio(
    *,
    asr_engine: Any,
    wav: Optional[Path],
    audio_wav: Optional[Path],
    backend: str,
    lang: str,
    chunk_s: int,
    batch_size: int,
    beam: int = 5,
    vad: bool = False,
) -> List[ASRUtterance]:
    source_wav = audio_wav or wav
    if source_wav is None:
        raise ValueError("缺少 WAV 路径")
    if backend == "faster-whisper":
        result = asr_engine.transcribe(
            str(source_wav),
            beam_size=beam,
            language=lang if lang and lang.lower() != "auto" else None,
            vad_filter=vad,
            word_timestamps=True,
        )[0]
        return extract_chunks_faster_whisper(result)
    result = asr_engine(_load_wav_for_transformers(source_wav), batch_size=batch_size, chunk_length_s=chunk_s)
    return extract_chunks(result)


def transcribe_qwen3(
    *,
    wav: Path,
    lang: str,
    device: str,
    batch_size: int,
    qwen_asr_model: str,
    qwen_aligner_model: str,
    require_cuda: bool = False,
) -> List[ASRUtterance]:
    if not qwen_asr_model or not qwen_aligner_model:
        raise ASRProviderUnavailable("缺少 Qwen3-ASR 或 ForcedAligner 模型")

    try:
        import torch
        from qwen_asr import Qwen3ASRModel
    except Exception as exc:
        raise ASRProviderUnavailable("缺少 qwen-asr 运行依赖") from exc

    cuda_ready = bool(getattr(torch, "cuda", None) and torch.cuda.is_available())
    if require_cuda and not cuda_ready:
        raise ASRProviderUnavailable("Qwen3-ASR 本地模式需要 CUDA")

    device_map = "cuda:0" if cuda_ready and (require_cuda or device.lower() == "cuda") else "cpu"
    dtype = torch.bfloat16 if device_map.startswith("cuda") else torch.float32
    max_batch = max(1, int(batch_size or 1))

    model = Qwen3ASRModel.from_pretrained(
        qwen_asr_model,
        dtype=dtype,
        device_map=device_map,
        max_inference_batch_size=max_batch,
        max_new_tokens=4096,
        forced_aligner=qwen_aligner_model,
        forced_aligner_kwargs={
            "dtype": dtype,
            "device_map": device_map,
        },
    )
    results = model.transcribe(
        audio=str(wav),
        language=_qwen_language(lang),
        return_time_stamps=True,
    )
    first = results[0] if isinstance(results, list) and results else results
    return parse_qwen_result(first)


def transcribe_mimo(
    *,
    wav: Path,
    lang: str,
    model_path: Optional[str],
    tokenizer_path: Optional[str],
    source_dir: Optional[str],
) -> List[ASRUtterance]:
    if not model_path or not tokenizer_path:
        raise ASRProviderUnavailable("缺少 MiMo 模型或 tokenizer 路径")
    if not source_dir:
        raise ASRProviderUnavailable("缺少 MiMo 官方源码目录")

    source_path = Path(source_dir).expanduser().resolve()
    if not source_path.exists():
        raise ASRProviderUnavailable(f"找不到 MiMo 官方源码目录: {source_path}")

    sys.path.insert(0, str(source_path))
    try:
        module = importlib.import_module("src.mimo_audio.mimo_audio")
        model_cls = getattr(module, "MimoAudio")
    except Exception as exc:
        raise ASRProviderUnavailable("MiMo 源码目录中找不到 MimoAudio") from exc

    model = model_cls(str(model_path), str(tokenizer_path))
    text = model.asr_sft(str(wav), audio_tag=_mimo_language_tag(lang))
    text = _clean_provider_text(text)
    if not text:
        return []
    return [ASRUtterance(start=0.0, end=0.5, text=text)]


def parse_qwen_result(result: Any) -> List[ASRUtterance]:
    text = _clean_provider_text(_get_value(result, "text", ""))
    timestamps = _get_value(result, "time_stamps", None) or _get_value(result, "timestamps", None)
    chunks: List[ASRUtterance] = []

    if isinstance(timestamps, Iterable) and not isinstance(timestamps, (str, bytes, dict)):
        for item in timestamps:
            item_text = _clean_provider_text(_get_value(item, "text", ""))
            start = _get_float(item, "start_time", "start", default=0.0)
            end = _get_float(item, "end_time", "end", default=start + 0.5)
            if not item_text:
                continue
            if end <= start:
                end = start + 0.5
            chunks.append(ASRUtterance(start=start, end=end, text=item_text))

    if chunks:
        return chunks
    return [ASRUtterance(start=0.0, end=0.5, text=text)] if text else []


def extract_chunks(asr_result: Any) -> List[ASRUtterance]:
    chunks: List[ASRUtterance] = []
    if isinstance(asr_result, dict):
        raw_chunks = asr_result.get("chunks")
        if isinstance(raw_chunks, list) and raw_chunks:
            for item in raw_chunks:
                if not isinstance(item, dict):
                    continue
                txt = _clean_provider_text(item.get("text") or "")
                if not txt:
                    continue
                start, end = _coerce_timestamps(item)
                if end <= start:
                    end = start + 0.5
                chunks.append(ASRUtterance(start=start, end=end, text=txt))
            if chunks:
                return chunks

        txt = _clean_provider_text(asr_result.get("text") or "")
        if txt:
            return [ASRUtterance(0.0, 0.5, text=txt)]

    if isinstance(asr_result, list):
        for item in asr_result:
            if not isinstance(item, dict):
                continue
            txt = _clean_provider_text(item.get("text") or "")
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

    return chunks


def extract_chunks_faster_whisper(result: Any) -> List[ASRUtterance]:
    if result is None:
        return []
    segments = result[0] if isinstance(result, tuple) and len(result) >= 1 else result
    chunks: List[ASRUtterance] = []
    for seg in segments:
        if isinstance(seg, dict):
            txt = _clean_provider_text(seg.get("text", ""))
            start = float(seg.get("start", 0.0))
            end = float(seg.get("end", start + 0.5))
            score = seg.get("avg_logprob")
        else:
            txt = _clean_provider_text(getattr(seg, "text", ""))
            start = float(getattr(seg, "start", 0.0))
            end = float(getattr(seg, "end", start + 0.5))
            score = getattr(seg, "avg_logprob", None)
        if not txt:
            continue
        if end <= start:
            end = start + 0.5
        chunks.append(ASRUtterance(start=start, end=end, text=txt, score=score))
    return chunks


def build_asr_pipeline(
    model: str,
    lang: str,
    device: str = "cpu",
    chunk_s: int = 30,
    batch: int = 4,
    engine: str = "transformers",
):
    if engine == "faster-whisper":
        if not _has_module("faster_whisper"):
            raise RuntimeError("faster-whisper 未安装")
        from faster_whisper import WhisperModel

        compute_type = "float16" if device.lower() == "cuda" else "int8"
        dev = "cuda" if device.lower() == "cuda" else "cpu"
        return WhisperModel(model, device=dev, compute_type=compute_type)

    from transformers import pipeline

    device_id = 0 if device.lower() == "cuda" else -1
    gen_kwargs = {"task": "transcribe"}
    if lang and lang.lower() != "auto":
        gen_kwargs["language"] = lang
    disable_transformers_torchcodec_probe()
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


def pick_engine(requested: str) -> List[str]:
    if requested == "faster-whisper":
        return ["faster-whisper", "transformers"]
    if requested == "transformers":
        return ["transformers"]
    if _has_module("faster_whisper"):
        return ["faster-whisper", "transformers"]
    return ["transformers", "faster-whisper"]


def disable_transformers_torchcodec_probe() -> None:
    try:
        from transformers.pipelines import automatic_speech_recognition

        automatic_speech_recognition.is_torchcodec_available = lambda: False
    except Exception:
        pass


def _load_wav_for_transformers(wav: Path) -> dict:
    audio, sample_rate = _read_wav_float32(wav)
    return {"array": audio, "sampling_rate": sample_rate}


def _read_wav_float32(wav: Path) -> Tuple[np.ndarray, int]:
    import numpy as np
    import wave

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


def _coerce_timestamps(item: dict) -> Tuple[float, float]:
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


def _has_module(module_name: str) -> bool:
    try:
        import importlib.util

        return importlib.util.find_spec(module_name) is not None
    except Exception:
        return False


def _qwen_language(lang: str) -> Optional[str]:
    normalized = (lang or "").lower()
    if normalized in {"", "auto"}:
        return None
    if normalized in {"zh", "cmn", "chinese"}:
        return "Chinese"
    if normalized in {"en", "eng", "english"}:
        return "English"
    return lang


def _mimo_language_tag(lang: str) -> str:
    normalized = (lang or "").lower()
    if normalized in {"zh", "cmn", "chinese"}:
        return "<chinese>"
    if normalized in {"en", "eng", "english"}:
        return "<english>"
    return ""


def _clean_provider_text(value: Any) -> str:
    text = str(value or "").strip()
    return re.sub(r"\s+", " ", text)


def _get_value(value: Any, key: str, default: Any = None) -> Any:
    if isinstance(value, dict):
        return value.get(key, default)
    return getattr(value, key, default)


def _get_float(value: Any, *keys: str, default: float) -> float:
    for key in keys:
        raw = _get_value(value, key, None)
        if raw is not None:
            return float(raw)
    return float(default)
