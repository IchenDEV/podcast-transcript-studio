from __future__ import annotations

from dataclasses import dataclass
from html import unescape
import json
import re
from typing import Callable, Optional
from urllib.parse import parse_qs, quote, urljoin, urlparse
from urllib.request import Request, urlopen
import xml.etree.ElementTree as ET


AUDIO_EXTENSIONS = ('.mp3', '.m4a', '.mp4', '.m4b', '.wav', '.aac', '.flac', '.ogg', '.opus')
USER_AGENT = (
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
    'AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36'
)


class PodcastAudioError(RuntimeError):
    pass


@dataclass(frozen=True)
class ResolvedPodcastAudio:
    page_url: str
    audio_url: str
    title: Optional[str]
    platform: str
    feed_url: Optional[str] = None


ReadURL = Callable[[str], bytes]


def resolve_podcast_audio(source_url: str, read_url: Optional[ReadURL] = None) -> ResolvedPodcastAudio:
    read = read_url or _read_url
    page_url = _validate_url(source_url)
    platform = _platform_name(page_url)

    if _is_audio_url(page_url):
        return ResolvedPodcastAudio(page_url=page_url, audio_url=page_url, title=None, platform=platform)

    if 'ximalaya.com' in urlparse(page_url).netloc:
        ximalaya_audio = _resolve_ximalaya_audio(page_url, read)
        if ximalaya_audio:
            return ResolvedPodcastAudio(
                page_url=page_url,
                audio_url=ximalaya_audio[0],
                title=ximalaya_audio[1],
                platform='ximalaya',
            )
        ximalaya_feed_url = _ximalaya_album_feed_url(page_url)
        if ximalaya_feed_url:
            try:
                item = _pick_rss_item(_decode(read(ximalaya_feed_url)), None)
            except Exception:
                item = None
            if item:
                item_title, item_audio = item
                return ResolvedPodcastAudio(
                    page_url=page_url,
                    audio_url=item_audio,
                    title=item_title,
                    platform='ximalaya',
                    feed_url=ximalaya_feed_url,
                )

    html = _decode(read(page_url))
    title = _extract_title(html)

    if _looks_like_feed(html):
        item = _pick_rss_item(html, title)
        if item:
            item_title, item_audio = item
            return ResolvedPodcastAudio(
                page_url=page_url,
                audio_url=item_audio,
                title=title or item_title,
                platform=platform,
                feed_url=page_url,
            )

    audio_url = _find_meta_audio_url(html, page_url) or _find_audio_url(html, page_url)
    if audio_url:
        return ResolvedPodcastAudio(page_url=page_url, audio_url=audio_url, title=title, platform=platform)

    feed_url = _find_feed_url(html, page_url)
    if not feed_url and 'podcasts.apple.com' in urlparse(page_url).netloc:
        feed_url = _lookup_apple_feed(page_url, read)

    if feed_url:
        rss = _decode(read(feed_url))
        item = _pick_rss_item(rss, title)
        if item:
            item_title, item_audio = item
            return ResolvedPodcastAudio(
                page_url=page_url,
                audio_url=item_audio,
                title=title or item_title,
                platform=platform,
                feed_url=feed_url,
            )

    raise PodcastAudioError('没有找到公开音频地址。请确认链接可公开访问，或改用本地音频文件。')


def _read_url(url: str) -> bytes:
    request = Request(url, headers={'User-Agent': USER_AGENT, 'Accept': '*/*'})
    with urlopen(request, timeout=30) as response:
        return response.read()


def _validate_url(source_url: str) -> str:
    value = source_url.strip()
    parsed = urlparse(value)
    if parsed.scheme not in {'http', 'https'} or not parsed.netloc:
        raise PodcastAudioError('请输入 http 或 https 链接。')
    return value


def _decode(payload: bytes) -> str:
    for encoding in ('utf-8', 'gb18030', 'latin-1'):
        try:
            return payload.decode(encoding)
        except UnicodeDecodeError:
            continue
    return payload.decode('utf-8', errors='replace')


def _platform_name(url: str) -> str:
    host = urlparse(url).netloc.lower()
    if 'podcasts.apple.com' in host:
        return 'apple_podcasts'
    if 'xiaoyuzhoufm.com' in host:
        return 'xiaoyuzhou'
    if 'ximalaya.com' in host:
        return 'ximalaya'
    return 'generic'


def _is_audio_url(url: str) -> bool:
    parsed = urlparse(url)
    return any(parsed.path.lower().endswith(extension) for extension in AUDIO_EXTENSIONS)


def _extract_title(html: str) -> Optional[str]:
    for pattern in (
        r'<meta\b[^>]*(?:property|name)=["\']og:title["\'][^>]*content=["\']([^"\']+)["\']',
        r'<meta\b[^>]*content=["\']([^"\']+)["\'][^>]*(?:property|name)=["\']og:title["\']',
        r'<title[^>]*>(.*?)</title>',
    ):
        match = re.search(pattern, html, flags=re.IGNORECASE | re.DOTALL)
        if match:
            title = re.sub(r'\s+', ' ', unescape(match.group(1))).strip()
            if title:
                return title
    return None


def _find_meta_audio_url(html: str, base_url: str) -> Optional[str]:
    for tag in re.findall(r'<meta\b[^>]*>', html, flags=re.IGNORECASE):
        attrs = _parse_attrs(tag)
        key = (attrs.get('property') or attrs.get('name') or '').lower()
        if key in {'og:audio', 'og:audio:url', 'twitter:player:stream'} and attrs.get('content'):
            return _make_absolute(attrs['content'], base_url)
    return None


def _parse_attrs(tag: str) -> dict[str, str]:
    attrs = {}
    for name, _, value in re.findall(r'([:\w-]+)\s*=\s*(["\'])(.*?)\2', tag, flags=re.DOTALL):
        attrs[name.lower()] = unescape(value.strip())
    return attrs


def _find_audio_url(text: str, base_url: str) -> Optional[str]:
    normalized = unescape(text).replace('\\/', '/')
    extension_pattern = '|'.join(re.escape(extension[1:]) for extension in AUDIO_EXTENSIONS)
    pattern = rf'https?://[^\s"\'<>]+?\.(?:{extension_pattern})(?:\?[^\s"\'<>]*)?'
    for match in re.finditer(pattern, normalized, flags=re.IGNORECASE):
        candidate = match.group(0).rstrip('.,);]')
        if _is_audio_url(candidate):
            return _make_absolute(candidate, base_url)
    return None


def _find_feed_url(html: str, base_url: str) -> Optional[str]:
    for tag in re.findall(r'<link\b[^>]*>', html, flags=re.IGNORECASE):
        attrs = _parse_attrs(tag)
        tag_type = attrs.get('type', '').lower()
        href = attrs.get('href')
        if href and ('rss' in tag_type or 'xml' in tag_type):
            return _make_absolute(href, base_url)

    normalized = unescape(html).replace('\\/', '/')
    for match in re.finditer(r'https?://[^\s"\'<>]+', normalized):
        candidate = match.group(0).rstrip('.,);]')
        lower = candidate.lower()
        if 'rss' in lower or 'feed' in lower or lower.endswith('.xml'):
            return _make_absolute(candidate, base_url)
    return None


def _lookup_apple_feed(page_url: str, read: ReadURL) -> Optional[str]:
    show_id = _apple_show_id(page_url)
    if not show_id:
        return None
    lookup_url = f'https://itunes.apple.com/lookup?id={quote(show_id)}&entity=podcast'
    try:
        payload = json.loads(_decode(read(lookup_url)))
    except (PodcastAudioError, json.JSONDecodeError):
        return None
    for result in payload.get('results', []):
        feed_url = result.get('feedUrl')
        if feed_url:
            return feed_url
    return None


def _apple_show_id(page_url: str) -> Optional[str]:
    match = re.search(r'/id(\d+)', urlparse(page_url).path)
    return match.group(1) if match else None


def _resolve_ximalaya_audio(page_url: str, read: ReadURL) -> Optional[tuple[str, Optional[str]]]:
    sound_id = _ximalaya_sound_id(page_url)
    if not sound_id:
        return None
    api_url = f'https://www.ximalaya.com/revision/play/v1/audio?id={quote(sound_id)}&ptype=1'
    try:
        payload = json.loads(_decode(read(api_url)))
    except Exception:
        return None
    data = payload.get('data') or {}
    audio_url = data.get('src') or data.get('playUrl64') or data.get('playUrl32')
    if not audio_url:
        return None
    return audio_url, data.get('trackName') or data.get('title')


def _ximalaya_sound_id(page_url: str) -> Optional[str]:
    parsed = urlparse(page_url)
    query = parse_qs(parsed.query)
    for key in ('id', 'trackId'):
        values = query.get(key)
        if values and values[0].isdigit():
            return values[0]
    for part in reversed([segment for segment in parsed.path.split('/') if segment]):
        if part.isdigit():
            return part
    return None


def _ximalaya_album_feed_url(page_url: str) -> Optional[str]:
    parsed = urlparse(page_url)
    match = re.search(r'/album/(\d+)(?:\.xml)?/?$', parsed.path)
    if not match:
        return None
    return f'{parsed.scheme or "https"}://www.ximalaya.com/album/{match.group(1)}.xml'


def _pick_rss_item(rss: str, title: Optional[str]) -> Optional[tuple[Optional[str], str]]:
    try:
        root = ET.fromstring(rss)
    except ET.ParseError:
        return None
    items = []
    for item in root.findall('.//item'):
        item_title = _node_text(item, 'title')
        enclosure = item.find('enclosure')
        audio_url = enclosure.get('url') if enclosure is not None else None
        if not audio_url:
            media = item.find('{http://search.yahoo.com/mrss/}content')
            audio_url = media.get('url') if media is not None else None
        if audio_url:
            items.append((item_title, audio_url))
    if not items:
        return None
    if title:
        needle = _normalize_title(title)
        for item_title, audio_url in items:
            haystack = _normalize_title(item_title or '')
            if haystack and (haystack in needle or needle in haystack):
                return item_title, audio_url
    return items[0]


def _looks_like_feed(text: str) -> bool:
    prefix = text[:500].lower()
    return '<rss' in prefix or '<feed' in prefix


def _node_text(parent: ET.Element, tag: str) -> Optional[str]:
    node = parent.find(tag)
    if node is None or node.text is None:
        return None
    return unescape(node.text.strip()) or None


def _normalize_title(value: str) -> str:
    return re.sub(r'[\W_]+', '', value.lower(), flags=re.UNICODE)


def _make_absolute(url: str, base_url: str) -> str:
    return urljoin(base_url, unescape(url).replace('\\/', '/').strip())
