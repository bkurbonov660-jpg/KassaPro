#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Автоматический поиск видеопотоков (.m3u8, .mp4) для приложения «Дорама Пульс».
Исправленная и улучшенная версия:
- Автоматически подхватывает реальные ID дорам из assets/seed_catalog.json и встроенного списка хитов
- Сохраняет ключи как по ID TVmaze / внутреннему FNV-ID, так и по нормализованному названию (nk),
  чтобы Flutter гарантированно находил потоки для любой карточки
- Проверяет живучесть уже сохранённых ссылок (is_link_alive) перед пропуском дорамы
- Корректно привязывает озвучку (dub) только к потокам конкретного сайта (не перезаписывая предыдущие)
- Корректно распаковывает редирект-ссылки DuckDuckGo (uddg=...) и проверяет HLS/MP4 с Referer
- Автоматически сохраняет результат в streams.json и дублирует в assets/streams.json
"""

import json
import os
import random
import re
import shutil
import time
from datetime import datetime
from urllib.parse import parse_qs, quote, unquote, urlparse

import requests

try:
    from playwright.sync_api import sync_playwright, TimeoutError as PlaywrightTimeout
except ImportError:
    sync_playwright = None
    PlaywrightTimeout = TimeoutError

# --- КОНФИГУРАЦИЯ ---
STREAMS_FILE = "streams.json"
ASSETS_STREAMS_FILE = os.path.join("assets", "streams.json")
SEED_CATALOG_FILE = os.path.join("assets", "seed_catalog.json")


def nk(s: str) -> str:
    """Нормализация английского названия (совпадает с nk() в lib/dict.dart)."""
    return re.sub(r"[^a-z0-9]+", "", (s or "").lower())


def fnv1a_32(s: str) -> int:
    """FNV-1a 32-bit хэш (совпадает с Store._fnv в lib/store.dart)."""
    h = 0x811C9DC5
    for ch in s:
        h ^= ord(ch)
        h = (h * 0x01000193) & 0xFFFFFFFF
    return h


def neg_id_for_2026(en: str) -> int:
    """Генерация локального отрицательного ID (совпадает с Store.seed2026)."""
    key = nk(en)
    return -(2000000000 + (fnv1a_32(key) % 90000000))


# Базовый список проверенных дорам с реальными ID TVmaze и FNV-ID для новинок 2025–2026
DEFAULT_DORAMAS = [
    {"id": 21845, "en": "Goblin", "ru": "Гоблин"},
    {"id": 44953, "en": "Crash Landing on You", "ru": "Аварийная посадка любви"},
    {"id": 56159, "en": "Business Proposal", "ru": "Деловое предложение"},
    {"id": 43687, "en": "Squid Game", "ru": "Игра в кальмара"},
    {"id": 65768, "en": "Queen of Tears", "ru": "Королева слёз"},
    {"id": 70623, "en": "Lovely Runner", "ru": "Хватай Сон Джэ и беги"},
    {"id": 67653, "en": "Marry My Husband", "ru": "Выходи замуж за моего супруга"},
    {"id": 59553, "en": "The Glory", "ru": "Слава"},
    {"id": 51346, "en": "Vincenzo", "ru": "Винченцо"},
    {"id": 55250, "en": "Alchemy of Souls", "ru": "Алхимия душ"},
    {"id": 57407, "en": "Extraordinary Attorney Woo", "ru": "Необыкновенный адвокат У Ён У"},
    {"id": 67375, "en": "My Demon", "ru": "Мой демон"},
    {"id": 71385, "en": "The Judge from Hell", "ru": "Судья из ада"},
    {"id": 76065, "en": "When the Phone Rings", "ru": "Набранный вами номер"},
    {"id": neg_id_for_2026("When Life Gives You Tangerines"), "en": "When Life Gives You Tangerines", "ru": "Когда жизнь даёт тебе мандарины"},
    {"id": neg_id_for_2026("The Trauma Code: Heroes on Call"), "en": "The Trauma Code: Heroes on Call", "ru": "Травматологический центр"},
    {"id": neg_id_for_2026("Love Scout"), "en": "Love Scout", "ru": "Мой идеальный секретарь"},
    {"id": neg_id_for_2026("Study Group"), "en": "Study Group", "ru": "Учебная группа"},
    {"id": neg_id_for_2026("Can This Love Be Translated?"), "en": "Can This Love Be Translated?", "ru": "Можно ли перевести эту любовь?"},
    {"id": neg_id_for_2026("Take Charge of My Heart"), "en": "Take Charge of My Heart", "ru": "Подзаряди меня"},
    {"id": neg_id_for_2026("Love in Disguise"), "en": "Love in Disguise", "ru": "Любовь под прикрытием"},
    {"id": neg_id_for_2026("Perfect Crown"), "en": "Perfect Crown", "ru": "Жена принца XXI века"},
]

USER_AGENTS = [
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15",
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
]

# Ключевые слова студий озвучки (синхронизировано с kDubStudios в lib/data2026.dart)
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
    "Официальная": ["официальн", "дубляж"],
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
    " banner",
    "/ads/",
    "ad_",
)


def build_doramas_list(max_from_catalog: int = 30) -> list:
    """Собирает список дорам из DEFAULT_DORAMAS и дополняет из assets/seed_catalog.json."""
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
            # Сортируем по рейтингу и новизне
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
                if k in by_key:
                    # Обновляем реальный ID из базы TVmaze, если в DEFAULT_DORAMAS был локальный
                    if isinstance(did, int) and did > 0:
                        by_key[k]["id"] = did
                    if ru and not by_key[k].get("ru"):
                        by_key[k]["ru"] = ru
                    continue
                if ru:
                    entry = {"id": did, "en": en, "ru": ru}
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


def detect_dub(text: str, url: str = "") -> str:
    combined = f"{url} {text}".lower()
    for dub, keywords in DUB_KEYWORDS.items():
        if any(kw in combined for kw in keywords):
            return dub
    return "SoftBox"


def is_link_alive(url: str, referer: str = "") -> bool:
    if not url or not url.startswith(("http://", "https://")):
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
        # Многие HLS (.m3u8) серверы блокируют HEAD (403/405), проверяем быстрым GET
        if resp.status_code in (400, 403, 405):
            with requests.get(url, headers=headers, timeout=5, stream=True, allow_redirects=True) as r2:
                return r2.status_code in (200, 206)
        return False
    except Exception:
        return False


def clean_ddg_url(href: str) -> str:
    """Извлекает прямую ссылку из редиректа DuckDuckGo и нормализует протокол."""
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


def filter_alive_streams(streams_list: list, include_demo: bool = False) -> list:
    """Проверяет список потоков и оставляет только живые и уникальные URL."""
    alive = []
    seen = set()
    for s in streams_list:
        if not isinstance(s, dict):
            continue
        url = str(s.get("url") or "").strip()
        if not url or url in seen:
            continue
        is_demo = "test-streams.mux.dev" in url
        if is_demo and not include_demo:
            continue
        if is_demo or is_link_alive(url, str(s.get("referer") or "")):
            seen.add(url)
            alive.append(s)
    return alive


def find_streams_for_drama(drama: dict) -> list:
    if sync_playwright is None:
        print("   ⚠️ Playwright не установлен. Выполните: python3 -m pip install playwright requests && python3 -m playwright install chromium")
        return []

    query = f"{drama['ru']} {drama['en']} дорама смотреть онлайн"
    print(f"🔍 Ищем: {drama['ru']} ({drama['en']})...")

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
                            "dub": url_dub if url_dub != "SoftBox" else current_referer["dub"],
                            "title": drama["ru"],
                            "en": drama["en"],
                            "at": datetime.now().isoformat(),
                        }
                    )
            except Exception:
                pass

        page.on("response", handle_response)

        try:
            search_url = f"https://html.duckduckgo.com/html/?q={quote(query)}"
            page.goto(search_url, timeout=12000)
            time.sleep(1.5)

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
                    page.wait_for_timeout(2500)
                    page.evaluate("window.scrollBy(0, 450)")
                    page.wait_for_timeout(1500)

                    page_text = page.content()
                    detected_dub = detect_dub(page_text, link)
                    current_referer["dub"] = detected_dub

                    try:
                        page.mouse.click(400, 300)
                        page.wait_for_timeout(2500)
                    except Exception:
                        pass

                    # Привязываем распознанную озвучку ТОЛЬКО к потокам, найденным на текущем сайте
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

    unique_streams = []
    seen_urls = set()
    for s in found_streams:
        if s["url"] not in seen_urls:
            seen_urls.add(s["url"])
            unique_streams.append(s)

    return unique_streams


def main():
    print("🚀 Запуск парсера потоков Дорама Пульс...")
    all_streams = load_existing_streams()
    doramas = build_doramas_list()

    stats = {"processed": 0, "found": 0, "alive": 0}

    for drama in doramas:
        drama_id = str(drama["id"])
        drama_key = nk(drama["en"])
        neg_id = str(neg_id_for_2026(drama["en"]))
        stats["processed"] += 1

        # 1. Проверяем старые реальные ссылки на живучесть
        existing = all_streams.get(drama_id) or all_streams.get(drama_key) or all_streams.get(neg_id) or []
        alive_existing = filter_alive_streams(existing, include_demo=False)
        if alive_existing:
            all_streams[drama_id] = alive_existing
            all_streams[drama_key] = alive_existing
            all_streams[neg_id] = alive_existing
            stats["alive"] += len(alive_existing)
            print(f"✅ {drama['ru']}: {len(alive_existing)} живых потоков в базе, пропускаем.")
            continue

        # 2. Ищем новые потоки через Playwright (если установлен)
        streams = find_streams_for_drama(drama)
        if streams:
            all_streams[drama_id] = streams
            all_streams[drama_key] = streams
            all_streams[neg_id] = streams
            stats["found"] += len(streams)
            print(f"   ✅ Найдено {len(streams)} потоков для {drama['ru']}")
        else:
            fallback_demo = filter_alive_streams(existing, include_demo=True)
            if fallback_demo:
                all_streams[drama_id] = fallback_demo
                all_streams[drama_key] = fallback_demo
                all_streams[neg_id] = fallback_demo
                print(f"   ℹ️ Оставлены резервные потоки ({len(fallback_demo)}) для {drama['ru']}")
            else:
                print(f"   ⚠️ NOT_FOUND: {drama['ru']}")

        save_streams(all_streams)
        time.sleep(random.uniform(1.5, 3.0))

    save_streams(all_streams)
    print("\n📊 СТАТИСТИКА:")
    print(f"Обработано дорам: {stats['processed']}")
    print(f"Проверено живых старых ссылок: {stats['alive']}")
    print(f"Новых ссылок найдено: {stats['found']}")
    print(f"Результат сохранён в: {STREAMS_FILE} и {ASSETS_STREAMS_FILE}")


if __name__ == "__main__":
    main()
