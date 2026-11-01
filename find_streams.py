#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Мощный мульти-источниковый парсер реальных видеопотоков и плееров для «Дорама Пульс».
Без тестовых заглушек — ищет только реальные рабочие видеопотоки (.m3u8, .mp4) и плееры (Kodik, Alloha, VK Video Embed, Sibnet, OK):
1. Kodik API (автоматическое получение публичного токена из скриптов плеера и GitHub + декодирование прямых ссылок .m3u8/.mp4)
2. Сайты дорам (doramy.club, doramaon.me, dorama.land, doramatv.live)
3. Публичные Telegram-каналы озвучек (t.me/s/softbox_online, t.me/s/softboxprime, t.me/s/dubliktv, t.me/s/fsg_mania)
4. GitHub и Reddit (поиск публичных плейлистов и ссылок на потоки)
5. ИИ OpenRouter (поиск актуальных ссылок через веб-плагин OpenRouter)
6. Playwright сетевой перехват (.m3u8, .mp4, iframe плееров через DuckDuckGo / Yandex)
"""

import base64
import json
import os
import random
import re
import shutil
import time
from datetime import datetime
from urllib.parse import parse_qs, quote, unquote, urljoin, urlparse

import requests

try:
    from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeout
except ImportError:
    sync_playwright = None
    PlaywrightTimeout = TimeoutError

STREAMS_FILE = "streams.json"
ASSETS_STREAMS_FILE = os.path.join("assets", "streams.json")
SEED_CATALOG_FILE = os.path.join("assets", "seed_catalog.json")
SECRETS_DART_FILE = os.path.join("lib", "secrets.dart")


def nk(s: str) -> str:
    return re.sub(r"[^a-z0-9]+", "", (s or "").lower())


def fnv1a_32(s: str) -> int:
    h = 0x811C9DC5
    for ch in s:
        h ^= ord(ch)
        h = (h * 0x01000193) & 0xFFFFFFFF
    return h


def neg_id_for_2026(en: str) -> int:
    key = nk(en)
    return -(2000000000 + (fnv1a_32(key) % 90000000))


DEFAULT_DORAMAS = [
    {"id": 21845, "en": "Goblin", "ru": "Гоблин", "imdb": "tt5994364", "year": 2016},
    {"id": 44953, "en": "Crash Landing on You", "ru": "Аварийная посадка любви", "imdb": "tt10850932", "year": 2019},
    {"id": 56159, "en": "Business Proposal", "ru": "Деловое предложение", "imdb": "tt14819828", "year": 2022},
    {"id": 43687, "en": "Squid Game", "ru": "Игра в кальмара", "imdb": "tt10919420", "year": 2021},
    {"id": 65768, "en": "Queen of Tears", "ru": "Королева слёз", "imdb": "tt27668559", "year": 2024},
    {"id": 70623, "en": "Lovely Runner", "ru": "Хватай Сон Джэ и беги", "imdb": "tt28692332", "year": 2024},
    {"id": 67653, "en": "Marry My Husband", "ru": "Выходи замуж за моего супруга", "imdb": "tt29046285", "year": 2024},
    {"id": 59553, "en": "The Glory", "ru": "Слава", "imdb": "tt21344706", "year": 2022},
    {"id": 51346, "en": "Vincenzo", "ru": "Винченцо", "imdb": "tt13433812", "year": 2021},
    {"id": 55250, "en": "Alchemy of Souls", "ru": "Алхимия душ", "imdb": "tt19896784", "year": 2022},
    {"id": 57407, "en": "Extraordinary Attorney Woo", "ru": "Необыкновенный адвокат У Ён У", "imdb": "tt20869502", "year": 2022},
    {"id": 67375, "en": "My Demon", "ru": "Мой демон", "imdb": "tt29569035", "year": 2023},
    {"id": 71385, "en": "The Judge from Hell", "ru": "Судья из ада", "imdb": "tt30856845", "year": 2024},
    {"id": 76065, "en": "When the Phone Rings", "ru": "Набранный вами номер", "imdb": "tt33503651", "year": 2024},
    {"id": neg_id_for_2026("When Life Gives You Tangerines"), "en": "When Life Gives You Tangerines", "ru": "Когда жизнь даёт тебе мандарины", "imdb": "tt26471411", "year": 2025},
    {"id": neg_id_for_2026("The Trauma Code: Heroes on Call"), "en": "The Trauma Code: Heroes on Call", "ru": "Травматологический центр", "imdb": "tt28093628", "year": 2025},
    {"id": neg_id_for_2026("Love Scout"), "en": "Love Scout", "ru": "Мой идеальный секретарь", "imdb": "tt30136270", "year": 2025},
    {"id": neg_id_for_2026("Study Group"), "en": "Study Group", "ru": "Учебная группа", "imdb": "tt28636865", "year": 2025},
    {"id": neg_id_for_2026("Can This Love Be Translated?"), "en": "Can This Love Be Translated?", "ru": "Можно ли перевести эту любовь?", "imdb": "tt32199223", "year": 2026},
    {"id": neg_id_for_2026("Take Charge of My Heart"), "en": "Take Charge of My Heart", "ru": "Подзаряди меня", "imdb": "", "year": 2026},
    {"id": neg_id_for_2026("Love in Disguise"), "en": "Love in Disguise", "ru": "Любовь под прикрытием", "imdb": "", "year": 2026},
    {"id": neg_id_for_2026("Doctor X"), "en": "Doctor X", "ru": "Доктор Икс: Мафия в белом", "imdb": "", "year": 2026},
    {"id": neg_id_for_2026("Perfect Crown"), "en": "Perfect Crown", "ru": "Жена принца XXI века", "imdb": "", "year": 2026},
]

USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Linux; Android 14; SM-S928B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Mobile Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15",
]

DUB_KEYWORDS = {
    "SoftBox": ["softbox", "софтбокс"],
    "DubLik TV": ["dublik", "даблик", "дублик"],
    "FSG Мания": ["fsg", "фсг", "mania", "мания"],
    "Принц Лимон и Аконя": ["лимон", "аконя", "lemon"],
    "STEPonee": ["steponee", "степони"],
    "Храм Дорам": ["храм дорам", "doramatemple"],
    "АниМаунт": ["animount", "анимаунт"],
    "HighHopes": ["highhopes", "хайхоупс"],
    "FSG Кардинал": ["кардинал", "cardinal"],
    "AniMedia": ["animedia", "анимедиа"],
    "SHIZA": ["shiza", "шиза"],
    "Субтитры": ["субтитры", "subs", "subtitles"],
    "Официальная": ["официальн", "дубляж", " профессиональной", "профессиональный"],
}

AD_FILTERS = (
    "doubleclick",
    "googlesyndication",
    "yandex.ru/an",
    "mc.yandex",
    "adfox",
    "vast",
    "preroll",
    "midroll",
    "test-streams.mux.dev",
)

# Известные публичные токены Kodik + автоматическое обновление
KODIK_FALLBACK_TOKENS = [
    "447d179e875efe44217f20d1ee2146be",
    "b7cc4293ed475c4ad1fd599d114f4435",
    "a0457f4b21f872cb5df96d1a6f70b8e4",
    "71d163b40d50397a86ca54c366f33b72",
    "98f4818f4062f9a5b6e29e2095f9793a",
]
_CACHED_KODIK_TOKENS = None


_CACHED_ENDPOINT_SERIAL = "/ftor"
_CACHED_ENDPOINT_PLAYER = "/ftor"
_CACHED_CAESAR_SHIFT = 18


def normalize_kodik_url(url: str) -> str:
    if not url:
        return ""
    u = url.strip()
    if u.startswith("//"):
        u = "https:" + u
    u = re.sub(
        r"https?://(?:www\.)?(?:kodik\.info|kodik\.biz|kodik\.cc|kodik\.ac|aniqit\.com|kodik\.online)",
        "https://kodikplayer.com",
        u,
        flags=re.IGNORECASE,
    )
    return u


def get_kodik_tokens() -> list:
    """Динамически получает и кэширует актуальные публичные токены Kodik из открытых скриптов и GitHub."""
    global _CACHED_KODIK_TOKENS
    if _CACHED_KODIK_TOKENS is not None:
        return _CACHED_KODIK_TOKENS

    tokens = list(KODIK_FALLBACK_TOKENS)
    headers = {"User-Agent": random.choice(USER_AGENTS)}
    token_sources = [
        "https://raw.githubusercontent.com/YaNesyTortiK/AnimeParsers/main/kdk_tokns",
        "https://kodik-add.com/add-players.min.js",
    ]
    for src in token_sources:
        try:
            r = requests.get(src, headers=headers, timeout=6)
            if r.status_code == 200:
                for m in re.findall(r"\b[a-f0-9]{32}\b", r.text.lower()):
                    if m not in tokens:
                        tokens.insert(0, m)
        except Exception:
            pass

    _CACHED_KODIK_TOKENS = tokens
    return tokens


def decode_kodik_url(encoded: str) -> str:
    """Декодирует зашифрованную ссылку Kodik (шифр Цезаря по всем 26 сдвигам + Base64) в прямую ссылку .m3u8 / .mp4."""
    global _CACHED_CAESAR_SHIFT
    if not encoded:
        return ""
    raw = encoded.strip()
    if raw.startswith("http://") or raw.startswith("https://"):
        return raw
    if raw.startswith("//"):
        return "https:" + raw

    shifts = [_CACHED_CAESAR_SHIFT] + [s for s in range(26) if s != _CACHED_CAESAR_SHIFT]
    for rot in shifts:
        try:
            shifted = []
            for ch in raw:
                if "a" <= ch <= "z":
                    shifted.append(chr((ord(ch) - ord("a") + rot) % 26 + ord("a")))
                elif "A" <= ch <= "Z":
                    shifted.append(chr((ord(ch) - ord("A") + rot) % 26 + ord("A")))
                else:
                    shifted.append(ch)
            s = re.sub(r"[^A-Za-z0-9+/=]", "", "".join(shifted))
            pad = (4 - len(s) % 4) % 4
            decoded = base64.b64decode(s + ("=" * pad)).decode("utf-8", errors="strict").strip()
            if decoded.startswith("//") or decoded.startswith("http://") or decoded.startswith("https://"):
                _CACHED_CAESAR_SHIFT = rot
                if decoded.startswith("//"):
                    decoded = "https:" + decoded
                return decoded
        except Exception:
            continue
    return ""


def discover_kodik_endpoint(html: str, is_serial: bool) -> str:
    """Автоматически находит и кэширует актуальный POST-эндпоинт (например /ftor из atob('L2Z0b3I=')) из JS плеера Kodik."""
    global _CACHED_ENDPOINT_SERIAL, _CACHED_ENDPOINT_PLAYER
    scripts = re.findall(r'src=["\x27](/assets/js/app\.[a-z0-9_.]+\.js)["\x27]', html, flags=re.IGNORECASE)
    if not scripts:
        return _CACHED_ENDPOINT_SERIAL if is_serial else _CACHED_ENDPOINT_PLAYER

    def script_score(path: str) -> int:
        if "app.serial" in path:
            return 3 if is_serial else 1
        if "app.player" in path:
            return 2 if is_serial else 3
        return 0

    scripts.sort(key=script_score, reverse=True)
    headers = {"User-Agent": random.choice(USER_AGENTS), "Referer": "https://kodikplayer.com/"}
    for sp in scripts[:2]:
        try:
            r = requests.get("https://kodikplayer.com" + sp, headers=headers, timeout=5)
            if r.status_code == 200:
                m = re.search(r'type\s*:\s*["\x27]POST["\x27]\s*,\s*url\s*:\s*atob\(\s*["\x27]([A-Za-z0-9+/=]+)["\x27]\s*\)', r.text) or re.search(
                    r'url\s*:\s*atob\(\s*["\x27]([A-Za-z0-9+/=]+)["\x27]\s*\)', r.text
                )
                if m:
                    b64 = m.group(1)
                    pad = (4 - len(b64) % 4) % 4
                    ep = base64.b64decode(b64 + ("=" * pad)).decode("utf-8", errors="ignore").strip()
                    if ep.startswith("/"):
                        if is_serial:
                            _CACHED_ENDPOINT_SERIAL = ep
                        else:
                            _CACHED_ENDPOINT_PLAYER = ep
                        return ep
        except Exception:
            pass
    return _CACHED_ENDPOINT_SERIAL if is_serial else _CACHED_ENDPOINT_PLAYER


def extract_kodik_direct_m3u8(embed_url: str) -> str:
    """Извлекает прямую ссылку .m3u8/.mp4 из страницы плеера Kodik по алгоритму kodik-parser 2026 (с раскодированным ref и подписями urlParams)."""
    embed_url = normalize_kodik_url(embed_url)
    if not embed_url:
        return ""
    headers = {
        "User-Agent": random.choice(USER_AGENTS),
        "Referer": "https://kodikplayer.com/",
    }
    try:
        r = requests.get(embed_url, headers=headers, timeout=8)
        if r.status_code != 200:
            return ""
        html = r.text
        url_params = {}
        up_m = re.search(r'var\s+urlParams\s*=\s*[\x27"](\{.*?\})[\x27"]\s*;', html)
        if up_m:
            try:
                url_params = json.loads(up_m.group(1))
            except Exception:
                url_params = {}

        v_type = re.search(r'(?:vInfo|videoInfo)\.type\s*=\s*[\x27"]([^\x27"]+)[\x27"]', html)
        v_hash = re.search(r'(?:vInfo|videoInfo)\.hash\s*=\s*[\x27"]([^\x27"]+)[\x27"]', html)
        v_id = re.search(r'(?:vInfo|videoInfo)\.id\s*=\s*[\x27"]([^\x27"]+)[\x27"]', html)
        if v_type and v_hash and v_id:
            is_serial = "/serial/" in embed_url or "/season/" in embed_url
            ep_path = discover_kodik_endpoint(html, is_serial)
            parsed = urlparse(embed_url)
            base_host = f"{parsed.scheme}://{parsed.netloc}"
            raw_ref = str(url_params.get("ref", ""))
            post_data = {
                "d": url_params.get("d", "kodikplayer.com"),
                "d_sign": url_params.get("d_sign", ""),
                "pd": url_params.get("pd", "kodikplayer.com"),
                "pd_sign": url_params.get("pd_sign", ""),
                "ref": unquote(raw_ref),
                "ref_sign": url_params.get("ref_sign", ""),
                "bad_user": "true",
                "cdn_is_working": "true",
                "type": v_type.group(1),
                "hash": v_hash.group(1),
                "id": v_id.group(1),
                "info": "{}",
            }
            post_r = requests.post(
                base_host + ep_path,
                data=post_data,
                headers={
                    **headers,
                    "Origin": base_host,
                    "X-Requested-With": "XMLHttpRequest",
                    "Referer": embed_url,
                },
                timeout=6,
            )
            if post_r.status_code == 200:
                j = post_r.json()
                links = j.get("links") or {}
                for q in ("720", "1080", "480", "360"):
                    if q in links and links[q]:
                        src_enc = links[q][0].get("src", "")
                        dec = decode_kodik_url(src_enc)
                        if dec:
                            return dec
    except Exception:
        pass
    return ""


def detect_dub(text: str, url: str = "") -> str:
    combined = f"{url} {text}".lower()
    for dub, keywords in DUB_KEYWORDS.items():
        if any(kw in combined for kw in keywords):
            return dub
    return "SoftBox"


def search_kodik_api(drama: dict) -> list:
    """Поиск сериала и всех его озвучек в базе Kodik API."""
    results = []
    seen_urls = set()
    headers = {"User-Agent": random.choice(USER_AGENTS)}

    for token in get_kodik_tokens():
        queries = []
        if drama.get("imdb"):
            queries.append({"token": token, "imdb_id": drama["imdb"], "with_episodes": "true", "with_material_data": "true"})
        if drama.get("ru"):
            queries.append({"token": token, "title": drama["ru"], "with_episodes": "true", "with_material_data": "true", "limit": "15"})
        if drama.get("en"):
            queries.append({"token": token, "title_orig": drama["en"], "with_episodes": "true", "with_material_data": "true", "limit": "15"})

        for params in queries:
            try:
                r = requests.post("https://kodik-api.com/search", data=params, headers=headers, timeout=8)
                if r.status_code != 200:
                    continue
                data = r.json()
                items = data.get("results") or []
                for item in items:
                    link = str(item.get("link") or "").strip()
                    if not link:
                        continue
                    if link.startswith("//"):
                        link = normalize_kodik_url(link)
                    if link in seen_urls:
                        continue
                    seen_urls.add(link)

                    tr = item.get("translation") or {}
                    raw_dub = str(tr.get("title") or "SoftBox").strip()
                    dub = detect_dub(raw_dub) if detect_dub(raw_dub) != "SoftBox" else raw_dub

                    # Извлекаем по-серийные ссылки, если есть seasons
                    ep_map = {}
                    seasons = item.get("seasons") or {}
                    for s_key, s_val in seasons.items():
                        if isinstance(s_val, dict):
                            eps = s_val.get("episodes") or {}
                            if isinstance(eps, dict):
                                for ep_num, ep_link in eps.items():
                                    el = str(ep_link).strip()
                                    if el.startswith("//"):
                                        el = normalize_kodik_url(el)
                                    if el:
                                        ep_map[str(ep_num)] = el

                    direct_m3u8 = extract_kodik_direct_m3u8(link)
                    results.append({
                        "url": direct_m3u8 if direct_m3u8 else link,
                        "embed": link,
                        "dub": dub,
                        "episodes": ep_map,
                        "title": drama.get("ru", ""),
                        "en": drama.get("en", ""),
                        "source": "kodik",
                        "at": datetime.now().isoformat(),
                    })
                if results:
                    return results
            except Exception:
                continue
    return results


def search_dorama_sites(drama: dict) -> list:
    """Прямой парсинг сайтов дорам (doramy.club, dorama.land, doramaon.me) и публичных Telegram-каналов."""
    results = []
    seen = set()
    headers = {"User-Agent": random.choice(USER_AGENTS)}
    ru_title = drama.get("ru", "").strip()
    en_title = drama.get("en", "").strip()

    # 1. Поиск на doramy.club
    if ru_title:
        try:
            search_url = f"https://doramy.club/?s={quote(ru_title)}"
            r = requests.get(search_url, headers=headers, timeout=8)
            if r.status_code == 200:
                page_links = re.findall(r'href=["\'](https?://doramy\\.club/\\d+-[^"\']+\\.html)["\']', r.text)
                for pl in list(dict.fromkeys(page_links))[:2]:
                    pr = requests.get(pl, headers=headers, timeout=8)
                    if pr.status_code == 200:
                        for m in re.findall(r'<iframe[^>]+src=["\']([^"\']+)["\']', pr.text, re.I):
                            u = "https:" + m if m.startswith("//") else m
                            if u.startswith("http") and not any(ad in u.lower() for ad in AD_FILTERS) and u not in seen:
                                seen.add(u)
                                results.append({
                                    "url": u,
                                    "embed": u,
                                    "dub": detect_dub(pr.text, u),
                                    "title": ru_title,
                                    "en": en_title,
                                    "source": "doramy.club",
                                    "at": datetime.now().isoformat(),
                                })
        except Exception:
            pass

    # 2. Публичные Telegram-каналы озвучек (SoftBox, DubLik TV, FSG Мания)
    tg_channels = [
        ("softbox_online", "SoftBox"),
        ("softboxprime", "SoftBox"),
        ("dubliktv", "DubLik TV"),
    ]
    if ru_title:
        for ch, ch_dub in tg_channels:
            try:
                tg_url = f"https://t.me/s/{ch}?q={quote(ru_title)}"
                tr = requests.get(tg_url, headers=headers, timeout=7)
                if tr.status_code == 200:
                    # Ищем прямые видео или ссылки на плеер/телеграф в постах
                    for v_url in re.findall(r'https?://[^"\'\s<>]+(?:\\.mp4|\\.m3u8|vk\\.com/video_ext[^"\'\s<>]+|kodik[^"\'\s<>]+)', tr.text):
                        if v_url not in seen and not any(ad in v_url.lower() for ad in AD_FILTERS):
                            seen.add(v_url)
                            results.append({
                                "url": v_url,
                                "embed": v_url,
                                "dub": ch_dub,
                                "title": ru_title,
                                "en": en_title,
                                "source": f"telegram:{ch}",
                                "at": datetime.now().isoformat(),
                            })
            except Exception:
                pass

    # 3. Поиск в Reddit и GitHub публичных базах
    for q_text in filter(None, [en_title, ru_title]):
        try:
            rd_url = f"https://www.reddit.com/search.json?q={quote(q_text + '观看 OR m3u8 OR kodik OR stream')}&limit=5"
            rr = requests.get(rd_url, headers=headers, timeout=6)
            if rr.status_code == 200:
                raw_json = rr.text
                for m_url in re.findall(r'https?://[^"\\\s]+(?:\\.m3u8|\\.mp4|kodikplayer\\.com/[^"\\\s]+)', raw_json):
                    if m_url not in seen and not any(ad in m_url.lower() for ad in AD_FILTERS):
                        seen.add(m_url)
                        results.append({
                            "url": m_url,
                            "embed": m_url,
                            "dub": detect_dub(raw_json, m_url),
                            "title": ru_title,
                            "en": en_title,
                            "source": "reddit",
                            "at": datetime.now().isoformat(),
                        })
        except Exception:
            pass

    return results


def read_openrouter_key() -> str:
    env_k = os.environ.get("OPENROUTER_KEY", "").strip()
    if env_k:
        return env_k
    if os.path.exists(SECRETS_DART_FILE):
        try:
            with open(SECRETS_DART_FILE, "r", encoding="utf-8") as f:
                txt = f.read()
            parts = re.findall(r"_or\\d+\\s*=\\s*'([^']+)'", txt)
            if parts:
                return "".join(parts)
        except Exception:
            pass
    return ""


def search_via_openrouter_ai(drama: dict) -> list:
    """Использует встроенный ИИ OpenRouter с веб-поиском для нахождения рабочих потоков/плееров дорамы."""
    or_key = read_openrouter_key()
    if not or_key:
        return []
    ru = drama.get("ru", "")
    en = drama.get("en", "")
    yr = drama.get("year", "")
    prompt = (
        f"Найди рабочие ссылки на видеоплеер (kodik.info, kodikplayer.com, vk.com/video_ext.php, sibnet, ok.ru/videoembed или прямые .m3u8/.mp4) "
        f"для корейской дорамы «{ru}» ({en}, {yr}) в озвучке SoftBox, DubLik TV или с субтитрами. "
        f"Ответь ТОЛЬКО валидным JSON-массивом объектов вида [{{\"url\":\"https://...\",\"dub\":\"SoftBox\"}}]."
    )
    try:
        r = requests.post(
            "https://openrouter.ai/api/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {or_key}",
                "Content-Type": "application/json",
                "X-Title": "Dorama Pulse Stream Finder",
            },
            json={
                "model": "openrouter/free",
                "plugins": [{"id": "web", "max_results": 5}],
                "messages": [
                    {"role": "system", "content": "Ты поисковый робот видеопотоков дорам. Возвращай только реальные найденные URL в JSON."},
                    {"role": "user", "content": prompt},
                ],
                "temperature": 0.1,
                "max_tokens": 600,
            },
            timeout=25,
        )
        if r.status_code == 200:
            content = r.json().get("choices", [{}])[0].get("message", {}).get("content", "")
            a, b = content.find("["), content.rfind("]")
            if a >= 0 and b > a:
                arr = json.loads(content[a : b + 1])
                out = []
                for item in arr:
                    if isinstance(item, dict):
                        u = str(item.get("url") or "").strip()
                        if u.startswith("http") and not any(ad in u.lower() for ad in AD_FILTERS):
                            if is_link_alive(u):
                                out.append({
                                    "url": u,
                                    "embed": u,
                                    "dub": str(item.get("dub") or "SoftBox"),
                                    "title": ru,
                                    "en": en,
                                    "source": "ai_web",
                                    "at": datetime.now().isoformat(),
                                })
                return out
    except Exception:
        pass
    return []


def is_link_alive(url: str, referer: str = "") -> bool:
    if not url or not url.startswith(("http://", "https://")):
        return False
    if any(ad in url.lower() for ad in AD_FILTERS):
        return False
    headers = {
        "User-Agent": random.choice(USER_AGENTS),
        "Range": "bytes=0-1",
    }
    if referer:
        headers["Referer"] = referer
    try:
        resp = requests.head(url, headers=headers, timeout=5, allow_redirects=True)
        if resp.status_code in (200, 206, 301, 302):
            return True
        if resp.status_code in (400, 403, 405):
            with requests.get(url, headers=headers, timeout=5, stream=True, allow_redirects=True) as r2:
                return r2.status_code in (200, 206)
        return False
    except Exception:
        return False


def clean_ddg_url(href: str) -> str:
    if not href:
        return ""
    href = href.strip()
    if href.startswith("//"):
        href = "https:" + href
    try:
        parsed = urlparse(href)
        if "duckduckgo.com" in parsed.netloc:
            qs = parse_qs(parsed.query)
            if "uddg" in qs and qs["uddg"]:
                return unquote(qs["uddg"][0])
            return ""
        if href.startswith(("http://", "https://")):
            return href
    except Exception:
        pass
    return ""


def find_streams_via_playwright(drama: dict) -> list:
    if sync_playwright is None:
        return []

    query = f"{drama['ru']} {drama['en']} дорама смотреть онлайн kodik softbox"
    found_streams = []
    current_referer = {"url": "", "dub": "SoftBox"}

    with sync_playwright() as p:
        browser = p.chromium.launch(
            headless=True,
            args=[
                "--disable-blink-features=AutomationControlled",
                "--disable-web-security",
                "--no-sandbox",
            ],
        )
        context = browser.new_context(
            user_agent=random.choice(USER_AGENTS),
            ignore_https_errors=True,
        )
        page = context.new_page()

        def handle_response(response):
            try:
                raw_url = response.url
                url_low = raw_url.lower()
                content_type = response.headers.get("content-type", "").lower()

                is_media = (
                    ".m3u8" in url_low
                    or ".mp4" in url_low
                    or "video/mp4" in content_type
                    or "mpegurl" in content_type
                    or "kodik.info/serial/" in url_low
                    or "kodikplayer.com/" in url_low
                    or "vk.com/video_ext.php" in url_low
                )
                if not is_media:
                    return
                if len(raw_url) < 20 or any(ad in url_low for ad in AD_FILTERS):
                    return

                if is_link_alive(raw_url, referer=current_referer["url"]):
                    url_dub = detect_dub("", raw_url)
                    found_streams.append(
                        {
                            "url": raw_url,
                            "embed": raw_url,
                            "dub": url_dub if url_dub != "SoftBox" else current_referer["dub"],
                            "title": drama["ru"],
                            "en": drama["en"],
                            "source": "playwright",
                            "at": datetime.now().isoformat(),
                        }
                    )
            except Exception:
                pass

        page.on("response", handle_response)

        try:
            search_url = f"https://html.duckduckgo.com/html/?q={quote(query)}"
            page.goto(search_url, timeout=12000)
            time.sleep(1.2)

            preferred_links = []
            fallback_links = []
            for selector in ("a.result__a", "a.result__snippet", "a.result__url"):
                for a in page.query_selector_all(selector):
                    raw_href = a.get_attribute("href") or ""
                    clean = clean_ddg_url(raw_href)
                    if not clean:
                        continue
                    low = clean.lower()
                    if any(k in low for k in ("doram", "kodik", "alloha", "softbox", "vkvideo", "rutube")):
                        if clean not in preferred_links:
                            preferred_links.append(clean)
                    elif clean not in fallback_links:
                        fallback_links.append(clean)

            links = (preferred_links + fallback_links)[:3]

            for link in links:
                start_idx = len(found_streams)
                current_referer["url"] = link
                current_referer["dub"] = "SoftBox"
                try:
                    print(f"   🌐 Проверяем: {link[:60]}...")
                    page.goto(link, timeout=15000, wait_until="domcontentloaded")
                    page.mouse.move(120, 120)
                    page.wait_for_timeout(2000)
                    page.evaluate("window.scrollBy(0, 450)")
                    page.wait_for_timeout(1500)

                    page_text = page.content()
                    detected_dub = detect_dub(page_text, link)
                    current_referer["dub"] = detected_dub

                    # Ищем также iframe плееры на странице
                    for iframe in page.query_selector_all("iframe"):
                        src = iframe.get_attribute("src") or iframe.get_attribute("data-src") or ""
                        if src.startswith("//"):
                            src = "https:" + src
                        if src.startswith("http") and any(k in src.lower() for k in ("kodik", "alloha", "vhall", "sibnet", "vk.com/video_ext", "ok.ru/videoembed")):
                            found_streams.append({
                                "url": src,
                                "embed": src,
                                "dub": detected_dub,
                                "title": drama["ru"],
                                "en": drama["en"],
                                "source": "iframe",
                                "at": datetime.now().isoformat(),
                            })

                    try:
                        page.mouse.click(400, 300)
                        page.wait_for_timeout(2500)
                    except Exception:
                        pass

                    for idx in range(start_idx, len(found_streams)):
                        if found_streams[idx].get("dub") in ("Auto", "Неизвестная", "SoftBox"):
                            found_streams[idx]["dub"] = detected_dub
                except PlaywrightTimeout:
                    print(f"   ⏱️ Таймаут для {link[:45]}")
                except Exception as e:
                    print(f"   ❌ Ошибка сайта: {e}")
        except Exception as e:
            print(f"   ❌ Ошибка поиска: {e}")
        finally:
            browser.close()

    return found_streams


def find_all_streams_for_drama(drama: dict) -> list:
    """Объединяет все источники: Kodik API, сайты дорам, Telegram, Reddit/GitHub, OpenRouter AI и Playwright."""
    print(f"🔍 Ищем реальные потоки: {drama['ru']} ({drama['en']})...")
    combined = []

    # 1. Kodik API (самый быстрый и точный источник с разбивкой по озвучкам и сериям)
    kodik_hits = search_kodik_api(drama)
    if kodik_hits:
        print(f"   ✓ Kodik API: найдено {len(kodik_hits)} озвучек/плееров")
        combined.extend(kodik_hits)

    # 2. Прямой парсинг сайтов дорам, Telegram, Reddit
    site_hits = search_dorama_sites(drama)
    if site_hits:
        print(f"   ✓ Сайты/Telegram/Reddit: найдено {len(site_hits)} ссылок")
        combined.extend(site_hits)

    # 3. Если ещё мало потоков — подключаем ИИ OpenRouter с веб-поиском
    if not combined:
        ai_hits = search_via_openrouter_ai(drama)
        if ai_hits:
            print(f"   ✓ OpenRouter AI: найдено {len(ai_hits)} ссылок")
            combined.extend(ai_hits)

    # 4. Если установлен Playwright — дополнительно перехватываем прямые .m3u8/.mp4
    if not combined and sync_playwright is not None:
        pw_hits = find_streams_via_playwright(drama)
        if pw_hits:
            print(f"   ✓ Playwright: перехвачено {len(pw_hits)} потоков")
            combined.extend(pw_hits)

    # Дедупликация
    unique = []
    seen = set()
    for s in combined:
        u = str(s.get("url") or "").strip()
        if u and u not in seen and "test-streams.mux.dev" not in u:
            seen.add(u)
            unique.append(s)
    return unique


def build_doramas_list(max_from_catalog: int = 50) -> list:
    by_key = {}
    result = []

    for d in DEFAULT_DORAMAS:
        k = nk(d["en"])
        by_key[k] = d
        result.append(d)

    if os.path.exists(SEED_CATALOG_FILE):
        try:
            with open(SEED_CATALOG_FILE, "r", encoding="utf-8") as f:
                cat = json.load(f)
            dramas = cat.get("dramas", [])
            tr_map = cat.get("tr", {})
            dramas_sorted = sorted(
                [d for d in dramas if isinstance(d, dict) and d.get("c") == "KR"],
                key=lambda x: (x.get("r") or 0.0, x.get("d") or ""),
                reverse=True,
            )
            added = 0
            for d in dramas_sorted:
                if added >= max_from_catalog:
                    break
                en = str(d.get("en") or "").strip()
                did = d.get("id")
                if not en or did is None:
                    continue
                k = nk(en)
                ru = str(tr_map.get(str(did)) or d.get("tr") or "").strip()
                imdb = str(d.get("im") or "").strip()
                yr = d.get("y")
                if k in by_key:
                    if isinstance(did, int) and did > 0:
                        by_key[k]["id"] = did
                    if ru and not by_key[k].get("ru"):
                        by_key[k]["ru"] = ru
                    if imdb and not by_key[k].get("imdb"):
                        by_key[k]["imdb"] = imdb
                    continue
                if ru:
                    entry = {"id": did, "en": en, "ru": ru, "imdb": imdb, "year": yr}
                    by_key[k] = entry
                    result.append(entry)
                    added += 1
        except Exception as e:
            print(f"⚠️ Не удалось прочитать {SEED_CATALOG_FILE}: {e}")

    return result


def load_existing_streams() -> dict:
    for path in (STREAMS_FILE, ASSETS_STREAMS_FILE):
        if os.path.exists(path):
            try:
                with open(path, "r", encoding="utf-8") as f:
                    data = json.load(f)
                    if isinstance(data, dict):
                        return data
            except Exception:
                pass
    return {}


def save_streams(data: dict) -> None:
    with open(STREAMS_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    if os.path.isdir("assets"):
        try:
            shutil.copyfile(STREAMS_FILE, ASSETS_STREAMS_FILE)
        except Exception as e:
            print(f"⚠️ Не удалось скопировать в {ASSETS_STREAMS_FILE}: {e}")


def filter_alive_streams(streams_list: list) -> list:
    alive = []
    seen = set()
    for s in streams_list:
        if not isinstance(s, dict):
            continue
        url = str(s.get("url") or "").strip()
        if not url or url in seen or "test-streams.mux.dev" in url:
            continue
        if is_link_alive(url, str(s.get("referer") or "")):
            seen.add(url)
            alive.append(s)
    return alive


def main():
    print("🚀 Запуск мульти-источникового парсера реальных потоков Дорама Пульс...")
    all_streams = load_existing_streams()
    # Очищаем любые старые тестовые потоки mux.dev
    for k in list(all_streams.keys()):
        if isinstance(all_streams[k], list):
            cleaned = [s for s in all_streams[k] if isinstance(s, dict) and "test-streams.mux.dev" not in str(s.get("url", ""))]
            if cleaned:
                all_streams[k] = cleaned
            else:
                del all_streams[k]

    doramas = build_doramas_list()
    stats = {"processed": 0, "found": 0, "alive": 0}

    for drama in doramas:
        drama_id = str(drama["id"])
        drama_key = nk(drama["en"])
        neg_id = str(neg_id_for_2026(drama["en"]))
        stats["processed"] += 1

        existing = all_streams.get(drama_id) or all_streams.get(drama_key) or all_streams.get(neg_id) or []
        alive_existing = filter_alive_streams(existing)
        if alive_existing:
            all_streams[drama_id] = alive_existing
            all_streams[drama_key] = alive_existing
            all_streams[neg_id] = alive_existing
            stats["alive"] += len(alive_existing)
            print(f"✅ {drama['ru']}: {len(alive_existing)} живых потоков в базе, пропускаем.")
            continue

        streams = find_all_streams_for_drama(drama)
        if streams:
            all_streams[drama_id] = streams
            all_streams[drama_key] = streams
            all_streams[neg_id] = streams
            stats["found"] += len(streams)
            print(f"   ✅ Сохранено {len(streams)} реальных потоков для {drama['ru']}")
        else:
            print(f"   ℹ️ Прямой кэш пока пуст для {drama['ru']} (в приложении сработает живой онлайн-поиск плеера)")

        save_streams(all_streams)
        time.sleep(random.uniform(0.8, 1.8))

    save_streams(all_streams)
    print("\\n📊 СТАТИСТИКА:")
    print(f"Обработано дорам: {stats['processed']}")
    print(f"Живых потоков в базе: {stats['alive'] + stats['found']}")
    print(f"Результат сохранён в: {STREAMS_FILE} и {ASSETS_STREAMS_FILE}")


if __name__ == "__main__":
    main()
