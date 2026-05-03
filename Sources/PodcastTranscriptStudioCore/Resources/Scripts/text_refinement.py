from __future__ import annotations

from dataclasses import dataclass, field
import json
import os
import re
from difflib import SequenceMatcher
from typing import Iterable, Protocol


DEFAULT_TEXT_MODEL_REPOSITORY = 'Qwen/Qwen3-0.6B'
DEFAULT_TEXT_MODEL_DIRECTORY = 'Qwen3-0.6B'


@dataclass(frozen=True)
class RefinementSegment:
    index: int
    speaker: str
    text: str


@dataclass
class TranscriptRefinement:
    speaker_display_names: dict[str, str] = field(default_factory=dict)
    corrected_texts: dict[int, str] = field(default_factory=dict)


class TextGenerationBackend(Protocol):
    def generate(self, prompt: str) -> str:
        ...


def build_refinement_prompt(segments: Iterable[RefinementSegment]) -> str:
    return build_text_correction_prompt(segments)


def build_speaker_name_prompt(segments: Iterable[RefinementSegment]) -> str:
    payload = [
        {'index': segment.index, 'speaker': segment.speaker, 'text': segment.text}
        for segment in segments
    ]
    return (
        '你只做姓名识别。输入是播客转写片段。\n'
        '如果某个 speaker 的文本里明确出现自我介绍，例如“我是张三”“我叫张三”“我的名字是张三”，'
        '输出这个 speaker 对应的姓名。\n'
        '没有明确姓名就不要输出。\n'
        '只输出 JSON 对象，格式：{"speaker_display_names":{"说话人1":"张三"}}\n'
        '输入：'
        f'{json.dumps(payload, ensure_ascii=False)}\n'
        '/no_think'
    )


def build_text_correction_prompt(segments: Iterable[RefinementSegment]) -> str:
    payload = [
        {'index': segment.index, 'speaker': segment.speaker, 'text': segment.text}
        for segment in segments
    ]
    return (
        '你是播客 ASR 后处理模型。只做保守修改。\n'
        '任务：\n'
        '1. 如果说话人在自己的发言里明确说“我是/我叫/我的名字是 + 姓名”，把姓名写入 speaker_display_names。\n'
        '2. 修正明显 ASR 错别字和英文技术词大小写。严禁改写句子，严禁替换不确定的中文词，严禁扩写。\n'
        '3. 如果不确定，保持原文。\n'
        '只输出 JSON，不要解释。JSON 格式必须是：\n'
        '{"speaker_display_names":{"说话人1":"姓名"},"segments":[{"index":0,"text":"原句或最小修正后的句子"}]}\n'
        '没有识别到姓名时，speaker_display_names 使用空对象。每个输入片段都要返回一条 segments 记录。\n'
        '输入片段：\n'
        f'{json.dumps(payload, ensure_ascii=False)}\n'
        '/no_think'
    )


def parse_refinement_response(raw: str) -> TranscriptRefinement:
    payload = json.loads(_extract_json_object(raw))
    speaker_display_names: dict[str, str] = {}
    corrected_texts: dict[int, str] = {}

    raw_names = payload.get('speaker_display_names', {})
    if isinstance(raw_names, dict):
        for speaker, name in raw_names.items():
            speaker_text = str(speaker).strip()
            name_text = str(name).strip()
            if speaker_text and name_text and speaker_text != name_text:
                speaker_display_names[speaker_text] = name_text

    raw_segments = payload.get('segments', [])
    if isinstance(raw_segments, list):
        for item in raw_segments:
            if not isinstance(item, dict):
                continue
            try:
                index = int(item.get('index'))
            except (TypeError, ValueError):
                continue
            text = str(item.get('text') or '').strip()
            if text:
                corrected_texts[index] = text

    return TranscriptRefinement(
        speaker_display_names=speaker_display_names,
        corrected_texts=corrected_texts,
    )


def parse_speaker_name_response(raw: str) -> dict[str, str]:
    return parse_refinement_response(raw).speaker_display_names


def apply_refinement_to_utterances(utterances, refinement: TranscriptRefinement) -> None:
    for index, utterance in enumerate(utterances):
        if index in refinement.corrected_texts:
            utterance.text = refinement.corrected_texts[index]
        display_name = refinement.speaker_display_names.get(utterance.speaker)
        if display_name:
            utterance.speaker = display_name


class QwenTranscriptRefiner:
    def __init__(
        self,
        model_ref: str | None = None,
        device: str = 'cpu',
        backend: TextGenerationBackend | None = None,
        batch_size: int = 80,
    ) -> None:
        self.model_ref = (
            model_ref
            or os.environ.get('PODCAST_TEXT_MODEL')
            or os.environ.get('PODCAST_TEXT_MODEL_REPOSITORY')
            or DEFAULT_TEXT_MODEL_REPOSITORY
        )
        self.device = device
        self.backend = backend
        self.batch_size = batch_size

    def refine(self, utterances) -> TranscriptRefinement:
        merged = TranscriptRefinement()
        segments = [
            RefinementSegment(index=index, speaker=utterance.speaker, text=utterance.text)
            for index, utterance in enumerate(utterances)
            if getattr(utterance, 'text', '').strip()
        ]
        if not segments:
            return merged

        backend = self.backend or TransformersTextGenerationBackend(self.model_ref, self.device)
        for batch in _batches(segments, self.batch_size):
            try:
                merged.speaker_display_names.update(parse_speaker_name_response(backend.generate(build_speaker_name_prompt(batch))))
            except Exception:
                pass

            try:
                result = parse_refinement_response(backend.generate(build_text_correction_prompt(batch)))
            except Exception:
                continue
            originals = {segment.index: segment.text for segment in batch}
            for index, text in result.corrected_texts.items():
                if _is_safe_correction(originals.get(index, ''), text):
                    merged.corrected_texts[index] = text
        return merged


class TransformersTextGenerationBackend:
    def __init__(self, model_ref: str, device: str = 'cpu', max_new_tokens: int = 2048) -> None:
        self.model_ref = model_ref
        self.device = device
        self.max_new_tokens = max_new_tokens
        self._tokenizer = None
        self._model = None

    def generate(self, prompt: str) -> str:
        tokenizer, model = self._load()
        messages = [{'role': 'user', 'content': prompt}]
        try:
            text = tokenizer.apply_chat_template(
                messages,
                tokenize=False,
                add_generation_prompt=True,
                enable_thinking=False,
            )
        except TypeError:
            text = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)

        model_inputs = tokenizer([text], return_tensors='pt').to(model.device)
        import torch

        with torch.no_grad():
            generated_ids = model.generate(
                **model_inputs,
                max_new_tokens=self.max_new_tokens,
                do_sample=False,
                pad_token_id=tokenizer.eos_token_id,
            )
        output_ids = generated_ids[0][len(model_inputs.input_ids[0]):].tolist()
        return _strip_thinking(tokenizer.decode(output_ids, skip_special_tokens=True))

    def _load(self):
        if self._tokenizer is not None and self._model is not None:
            return self._tokenizer, self._model

        from transformers import AutoModelForCausalLM, AutoTokenizer

        tokenizer = AutoTokenizer.from_pretrained(self.model_ref, trust_remote_code=True)
        model = AutoModelForCausalLM.from_pretrained(
            self.model_ref,
            torch_dtype='auto',
            trust_remote_code=True,
        )
        if self.device and self.device != 'auto':
            model = model.to(self.device)
        model.eval()
        self._tokenizer = tokenizer
        self._model = model
        return tokenizer, model


def _extract_json_object(raw: str) -> str:
    text = raw.strip()
    fenced = re.search(r'```(?:json)?\s*(\{.*?\})\s*```', text, flags=re.DOTALL | re.IGNORECASE)
    if fenced:
        return fenced.group(1)
    start = text.find('{')
    end = text.rfind('}')
    if start >= 0 and end > start:
        return text[start : end + 1]
    raise ValueError('模型没有返回 JSON 对象')


def _strip_thinking(text: str) -> str:
    return re.sub(r'<think>.*?</think>', '', text, flags=re.DOTALL).strip()


def _batches(items: list[RefinementSegment], size: int):
    size = max(size, 1)
    for start in range(0, len(items), size):
        yield items[start : start + size]


def _is_safe_correction(original: str, corrected: str) -> bool:
    original = (original or '').strip()
    corrected = (corrected or '').strip()
    if not original or not corrected:
        return False
    if original == corrected:
        return True
    if len(corrected) < len(original) * 0.7 or len(corrected) > len(original) * 1.3:
        return False
    if SequenceMatcher(None, original, corrected).ratio() < 0.75:
        return False

    original_cjk = _cjk_text(original)
    corrected_cjk = _cjk_text(corrected)
    if original_cjk and _lcs_length(original_cjk, corrected_cjk) / len(original_cjk) < 0.8:
        return False

    original_latin_count = len(re.findall(r'[A-Za-z][A-Za-z0-9._+-]*', original))
    corrected_latin_count = len(re.findall(r'[A-Za-z][A-Za-z0-9._+-]*', corrected))
    if original_latin_count and corrected_latin_count < original_latin_count:
        return False
    return True


def _cjk_text(text: str) -> str:
    return ''.join(ch for ch in text if '\u4e00' <= ch <= '\u9fff')


def _lcs_length(left: str, right: str) -> int:
    previous = [0] * (len(right) + 1)
    for left_char in left:
        current = [0]
        for index, right_char in enumerate(right, 1):
            if left_char == right_char:
                current.append(previous[index - 1] + 1)
            else:
                current.append(max(previous[index], current[-1]))
        previous = current
    return previous[-1]
