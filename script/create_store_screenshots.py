#!/usr/bin/env python3
"""Compose App Store screenshots for Corner Peek from real app captures.

Generates three 2880x1800 marketing images per locale (en-US, zh-Hans, ja):
  01 - edge-hidden window story (full desktop capture)
  02 - multi web-app rail close-up with real icon callouts
  03 - compact vs expanded window size comparison

Sources are the raw captures in screenshots/. Output goes to screenshots/store/.
"""
from __future__ import annotations

import math
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "screenshots"
OUT = SRC / "store"

CANVAS = (2880, 1800)

INK = (18, 25, 38, 255)
MUTED = (91, 104, 123, 255)
BLUE = (24, 119, 242, 255)
BLUE_DARK = (10, 87, 204, 255)
BLUE_SOFT = (221, 236, 255, 255)
WHITE = (255, 255, 255, 255)
CARD_LINE = (226, 231, 239, 255)

DESKTOP = SRC / "Screenshot 2026-07-09 at 10.15.46.png"
WIN_LARGE = SRC / "Screenshot 2026-07-09 at 10.17.55.png"
WIN_COMPACT = SRC / "Screenshot 2026-07-09 at 10.17.32.png"

# Pixel-measured window bounds inside the raw captures.
LARGE_BOUNDS = (24, 26, 1822, 2082)
COMPACT_BOUNDS = (24, 28, 1174, 1224)
DESKTOP_MENUBAR_CROP = 92

# Rail icon centers in WIN_LARGE coordinates, measured by pixel scan (x is rail center).
RAIL_CENTER_X = 51
RAIL_ICON_Y = {
    "chatgpt": 175,
    "todoist": 243,
    "slack": 311,
    "gmail": 379,
    "claude": 447,
    "globe": 558,
    "plus": 621,
}


# --------------------------------------------------------------------------- fonts

FONT_FILES = {
    "en": ("/System/Library/Fonts/SFNS.ttf", None),
    "zh": ("/System/Library/Fonts/Hiragino Sans GB.ttc", {"bold": 2, "regular": 0}),
    "ja": ("/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc", None),  # resolved below
}
_font_cache: dict[tuple[str, str, int], ImageFont.FreeTypeFont] = {}


def font(lang: str, weight: str, size: int) -> ImageFont.FreeTypeFont:
    key = (lang, weight, size)
    if key in _font_cache:
        return _font_cache[key]
    if lang == "en":
        fnt = ImageFont.truetype("/System/Library/Fonts/SFNS.ttf", size=size)
        fnt.set_variation_by_name("Semibold" if weight == "bold" else "Regular")
    elif lang == "zh":
        path, idx = FONT_FILES["zh"]
        fnt = ImageFont.truetype(path, size=size, index=idx[weight])
    else:  # ja
        name = "W6" if weight == "bold" else "W3"
        fnt = ImageFont.truetype(
            f"/System/Library/Fonts/ヒラギノ角ゴシック {name}.ttc", size=size, index=0
        )
    _font_cache[key] = fnt
    return fnt


# --------------------------------------------------------------------------- copy

@dataclass
class Copy:
    badge: str
    headline: list[str]
    body: list[str]
    extra: dict[str, str]


COPY: dict[str, dict[str, Copy]] = {
    "zh-Hans": {
        "hidden": Copy(
            badge="隐藏式边缘窗口",
            headline=["需要时滑出", "用完自动隐藏"],
            body=["鼠标靠近屏幕边缘，面板轻轻滑出；", "离开后自动收起，桌面始终清爽。"],
            extra={"chip_title": "贴边隐藏", "chip_sub": "鼠标靠近即滑出"},
        ),
        "apps": Copy(
            badge="多标签 Web App",
            headline=["常用 Web App", "同时待命"],
            body=["ChatGPT、Slack、Gmail、Claude…同时登录、互不打扰，", "点一下图标即刻切换，不用再开一排浏览器窗口。"],
            extra={"globe": "任意网站", "plus": "随时添加"},
        ),
        "resize": Copy(
            badge="大小随心调整",
            headline=["小窗速查", "大窗沉浸"],
            body=["随手一瞥时保持紧凑，想认真阅读就直接拉大，", "拖拽边缘，窗口大小随时改变。"],
            extra={"small": "小窗 · 顺手一瞥", "large": "大窗 · 沉浸浏览"},
        ),
        "search": Copy(
            badge="快速搜索与提问",
            headline=["边缘一滑", "马上搜索"],
            body=["不用切回浏览器；拉出面板就能搜索、提问，", "也可以继续使用常用的快捷入口。"],
            extra={"primary": "搜索、提问、输入网址", "secondary": "语音输入", "tertiary": "快捷操作"},
        ),
        "pins": Copy(
            badge="固定常用网站",
            headline=["喜欢的网站", "一直在侧边"],
            body=["把每天要看的 AI、文档、邮箱和看板固定住，", "工作时只需轻点侧边栏，不打断当前窗口。"],
            extra={"sub": "固定在侧边栏", "globe": "任意网站", "plus": "添加更多"},
        ),
    },
    "en-US": {
        "hidden": Copy(
            badge="Hide-away edge panel",
            headline=["Slides in.", "Slides away."],
            body=["Hover at the screen edge to call it out.", "It tucks itself away when you're done."],
            extra={"chip_title": "Docks at the edge", "chip_sub": "Hover to slide out"},
        ),
        "apps": Copy(
            badge="All your web apps",
            headline=["Your web apps,", "all at once."],
            body=["ChatGPT, Slack, Gmail and Claude, signed in side by side.", "Switch with one click — no browser windows to juggle."],
            extra={"globe": "Any website", "plus": "Add your own"},
        ),
        "resize": Copy(
            badge="Any size you like",
            headline=["Tiny for a peek.", "Big for focus."],
            body=["Keep it compact for quick checks, or stretch it out", "whenever you need more room. Just drag any edge."],
            extra={"small": "Compact · quick glance", "large": "Expanded · full page"},
        ),
        "search": Copy(
            badge="Fast search and prompts",
            headline=["Slide out.", "Search right away."],
            body=["No need to jump back to a browser. Open the edge panel", "to search, ask, or use quick actions in place."],
            extra={"primary": "Search, ask, or enter a URL", "secondary": "Voice input", "tertiary": "Quick actions"},
        ),
        "pins": Copy(
            badge="Pinned favorite sites",
            headline=["Your daily sites", "stay on the side."],
            body=["Keep AI, docs, mail and dashboards ready on the rail.", "One click brings each site into the same side window."],
            extra={"sub": "Pinned on the rail", "globe": "Any website", "plus": "Add more"},
        ),
    },
    "ja": {
        "hidden": Copy(
            badge="隠れるエッジパネル",
            headline=["必要なときだけ", "スッと現れる"],
            body=["画面の端にマウスを寄せるとスッと表示。", "使ったあとは自動で隠れて、画面は広々。"],
            extra={"chip_title": "端にドッキング", "chip_sub": "近づけると表示"},
        ),
        "apps": Copy(
            badge="マルチタブ Web アプリ",
            headline=["よく使うアプリを", "まとめて待機"],
            body=["ChatGPT も Slack も Gmail も、ログインしたまま同時に待機。", "アイコンをクリックするだけで即切り替え。"],
            extra={"globe": "好きなサイト", "plus": "自由に追加"},
        ),
        "resize": Copy(
            badge="サイズ自由自在",
            headline=["小さくチラ見", "大きく没入"],
            body=["サッと確認はコンパクトに、じっくり読むなら大きく。", "端をドラッグするだけで自由にリサイズ。"],
            extra={"small": "コンパクト", "large": "フルサイズ"},
        ),
        "search": Copy(
            badge="すばやく検索・質問",
            headline=["端から開いて", "すぐ検索"],
            body=["ブラウザへ戻らず、エッジパネルで検索や質問。", "よく使うアクションもその場で使えます。"],
            extra={"primary": "検索・質問・URL入力", "secondary": "音声入力", "tertiary": "クイック操作"},
        ),
        "pins": Copy(
            badge="お気に入りサイトを固定",
            headline=["毎日のサイトを", "いつも横に"],
            body=["AI、ドキュメント、メール、ダッシュボードを横に固定。", "クリックだけで同じサイドウィンドウに切り替え。"],
            extra={"sub": "サイドバーに固定", "globe": "好きなサイト", "plus": "さらに追加"},
        ),
    },
}

LANG = {"zh-Hans": "zh", "en-US": "en", "ja": "ja"}

APP_LABELS = {
    "chatgpt": "ChatGPT",
    "todoist": "Todoist",
    "slack": "Slack",
    "gmail": "Gmail",
    "claude": "Claude",
}


# --------------------------------------------------------------------------- helpers

def load(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def contain(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    scale = min(size[0] / image.width, size[1] / image.height)
    return image.resize((round(image.width * scale), round(image.height * scale)), Image.Resampling.LANCZOS)


def rounded(image: Image.Image, radius: int) -> Image.Image:
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, image.width - 1, image.height - 1), radius=radius, fill=255)
    out = Image.new("RGBA", image.size, (0, 0, 0, 0))
    out.alpha_composite(image)
    out.putalpha(mask)
    return out


def shadowed(canvas: Image.Image, image: Image.Image, xy: tuple[int, int], blur: int = 40, offset: tuple[int, int] = (0, 26), opacity: int = 64) -> None:
    pad = blur * 2
    shadow = Image.new("RGBA", (image.width + pad * 2, image.height + pad * 2), (0, 0, 0, 0))
    shadow.paste((15, 23, 42, opacity), (pad + offset[0], pad + offset[1]), image.getchannel("A"))
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(shadow, (xy[0] - pad, xy[1] - pad))
    canvas.alpha_composite(image, xy)


def text_w(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.FreeTypeFont) -> int:
    box = draw.textbbox((0, 0), text, font=fnt)
    return box[2] - box[0]


def draw_lines(draw: ImageDraw.ImageDraw, xy: tuple[int, int], lines: Iterable[str], fnt: ImageFont.FreeTypeFont, fill, gap: int) -> int:
    y = xy[1]
    for line in lines:
        draw.text((xy[0], y), line, font=fnt, fill=fill)
        y = draw.textbbox((xy[0], y), line, font=fnt)[3] + gap
    return y


def copy_block(canvas: Image.Image, lang: str, copy: Copy, x: int, y: int, headline_size: int = 116) -> int:
    """Badge pill + headline + blue accent bar + body. Returns bottom y."""
    draw = ImageDraw.Draw(canvas)
    badge_font = font(lang, "bold", 35)
    w = text_w(draw, copy.badge, badge_font)
    draw.rounded_rectangle((x, y, x + w + 68, y + 68), radius=34, fill=BLUE_SOFT)
    draw.text((x + 34, y + 13), copy.badge, font=badge_font, fill=BLUE_DARK)

    head_y = y + 138
    end = draw_lines(draw, (x, head_y), copy.headline, font(lang, "bold", headline_size), INK, 30)
    bar_y = end + 26
    draw.rounded_rectangle((x + 6, bar_y, x + 166, bar_y + 14), radius=7, fill=BLUE)
    body_y = bar_y + 74
    return draw_lines(draw, (x + 6, body_y), copy.body, font(lang, "regular", 43), MUTED, 20)


def window_image(which: str) -> Image.Image:
    if which == "large":
        return load(WIN_LARGE).crop(LARGE_BOUNDS)
    return load(WIN_COMPACT).crop(COMPACT_BOUNDS)


def base_canvas() -> Image.Image:
    return Image.new("RGBA", CANVAS, WHITE)


def card_outline(canvas: Image.Image, xy: tuple[int, int], size: tuple[int, int], radius: int) -> None:
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle((xy[0], xy[1], xy[0] + size[0] - 1, xy[1] + size[1] - 1), radius=radius, outline=CARD_LINE, width=2)


# --------------------------------------------------------------------------- image 1: hidden edge window

def image_hidden(locale: str) -> Image.Image:
    lang = LANG[locale]
    copy = COPY[locale]["hidden"]
    canvas = base_canvas()

    copy_block(canvas, lang, copy, 170, 300)

    desktop = load(DESKTOP).crop((0, DESKTOP_MENUBAR_CROP, 3836, 2156))
    card_w = 1660
    card = contain(desktop, (card_w, 10_000))
    card = rounded(card, 34)
    card_x, card_y = 1050, (CANVAS[1] - card.height) // 2
    shadowed(canvas, card, (card_x, card_y), blur=48, offset=(0, 30), opacity=70)
    card_outline(canvas, (card_x, card_y), card.size, 34)

    # Chip straddling the card's left edge, over the docked panel: "docks at the edge".
    draw = ImageDraw.Draw(canvas)
    chip_title_f = font(lang, "bold", 37)
    chip_sub_f = font(lang, "regular", 29)
    chip_w = max(text_w(draw, copy.extra["chip_title"], chip_title_f), text_w(draw, copy.extra["chip_sub"], chip_sub_f)) + 150
    chip_h = 150
    chip_x = card_x - round(chip_w * 0.55)
    chip_y = 1120
    chip = Image.new("RGBA", (chip_w, chip_h), (0, 0, 0, 0))
    ImageDraw.Draw(chip).rounded_rectangle((0, 0, chip_w - 1, chip_h - 1), radius=32, fill=(255, 255, 255, 247), outline=CARD_LINE, width=2)
    shadowed(canvas, chip, (chip_x, chip_y), blur=26, offset=(0, 12), opacity=46)
    draw = ImageDraw.Draw(canvas)
    # double chevron pointing left (slides into the edge)
    cx, cy = chip_x + 52, chip_y + chip_h // 2
    for off in (0, 26):
        draw.line((cx + 18 + off, cy - 20, cx + off, cy), fill=BLUE, width=8, joint="curve")
        draw.line((cx + off, cy, cx + 18 + off, cy + 20), fill=BLUE, width=8, joint="curve")
    draw.text((chip_x + 106, chip_y + 30), copy.extra["chip_title"], font=chip_title_f, fill=INK)
    draw.text((chip_x + 106, chip_y + 84), copy.extra["chip_sub"], font=chip_sub_f, fill=MUTED)
    return canvas


# --------------------------------------------------------------------------- image 2: multi web apps rail

def image_apps(locale: str) -> Image.Image:
    lang = LANG[locale]
    copy = COPY[locale]["apps"]
    canvas = base_canvas()

    copy_block(canvas, lang, copy, 170, 300)

    # Close-up crop: rail + ChatGPT sidebar + content edge from the sharpest capture.
    zoom = 2.35
    crop = (24, 26, 470, 760)
    hero = load(WIN_LARGE).crop(crop)
    hero = hero.resize((round(hero.width * zoom), round(hero.height * zoom)), Image.Resampling.LANCZOS)
    hero = rounded(hero, 46)
    hero_x = 1692
    hero_y = (CANVAS[1] - hero.height) // 2
    shadowed(canvas, hero, (hero_x, hero_y), blur=52, offset=(0, 30), opacity=72)
    card_outline(canvas, (hero_x, hero_y), hero.size, 46)

    # Callout labels pointing at the real app icons.
    draw = ImageDraw.Draw(canvas)
    label_font = font(lang, "bold", 40)
    icon_x = hero_x + round((RAIL_CENTER_X - crop[0]) * zoom)
    entries = list(APP_LABELS.items()) + [("globe", copy.extra["globe"]), ("plus", copy.extra["plus"])]
    for key, label in entries:
        y = hero_y + round((RAIL_ICON_Y[key] - crop[1]) * zoom)
        line_x0 = icon_x - 58
        line_x1 = 1520
        color = MUTED if key in ("globe", "plus") else INK
        draw.line((line_x1 + 14, y, line_x0, y), fill=(203, 211, 222, 255), width=3)
        draw.ellipse((line_x0 - 7, y - 7, line_x0 + 7, y + 7), fill=BLUE)
        draw.text((line_x1 - text_w(draw, label, label_font), y - 26), label, font=label_font, fill=color)
    return canvas


# --------------------------------------------------------------------------- image 3: resizable

def image_resize(locale: str) -> Image.Image:
    lang = LANG[locale]
    copy = COPY[locale]["resize"]
    canvas = base_canvas()

    copy_block(canvas, lang, copy, 170, 230)

    large = rounded(contain(window_image("large"), (10_000, 1420)), 40)
    compact = rounded(contain(window_image("compact"), (10_000, 700)), 30)

    large_x, large_y = 1470, 150
    compact_x, compact_y = 470, 940
    shadowed(canvas, large, (large_x, large_y), blur=48, offset=(0, 28), opacity=70)
    card_outline(canvas, (large_x, large_y), large.size, 40)
    shadowed(canvas, compact, (compact_x, compact_y), blur=40, offset=(0, 22), opacity=64)
    card_outline(canvas, (compact_x, compact_y), compact.size, 30)

    draw = ImageDraw.Draw(canvas)

    # Diagonal two-headed resize arrow between the two windows.
    x0, y0, x1, y1 = 1195, 1592, 1415, 1372
    draw.line((x0, y0, x1, y1), fill=BLUE, width=11)
    for tip, other in (((x0, y0), (x1, y1)), ((x1, y1), (x0, y0))):
        angle = math.atan2(tip[1] - other[1], tip[0] - other[0])
        for spread in (-0.46, 0.46):
            a = angle + math.pi + spread
            draw.line(
                (tip[0], tip[1], tip[0] + round(46 * math.cos(a)), tip[1] + round(46 * math.sin(a))),
                fill=BLUE,
                width=11,
            )

    label_font = font(lang, "bold", 36)
    for text, cx, cy in (
        (copy.extra["small"], compact_x + compact.width // 2, compact_y + compact.height + 74),
        (copy.extra["large"], large_x + large.width // 2, large_y + large.height + 74),
    ):
        w = text_w(draw, text, label_font)
        draw.rounded_rectangle((cx - w // 2 - 36, cy - 40, cx + w // 2 + 36, cy + 40), radius=40, fill=(246, 248, 252, 255), outline=CARD_LINE, width=2)
        draw.text((cx - w // 2, cy - 26), text, font=label_font, fill=INK)
    return canvas


# --------------------------------------------------------------------------- image 4: quick search

def image_search(locale: str) -> Image.Image:
    lang = LANG[locale]
    copy = COPY[locale]["search"]
    canvas = base_canvas()

    copy_block(canvas, lang, copy, 170, 255)

    compact = window_image("compact")
    panel = rounded(contain(compact, (1040, 1220)), 42)
    panel_x, panel_y = 1640, 220
    shadowed(canvas, panel, (panel_x, panel_y), blur=48, offset=(0, 28), opacity=68)
    card_outline(canvas, (panel_x, panel_y), panel.size, 42)

    # Magnify the real search/action area from the compact panel.
    search_strip = compact.crop((82, 708, 1126, 1188))
    search_strip = rounded(contain(search_strip, (1320, 520)), 44)
    strip_x, strip_y = 1030, 1070
    shadowed(canvas, search_strip, (strip_x, strip_y), blur=42, offset=(0, 24), opacity=70)
    card_outline(canvas, (strip_x, strip_y), search_strip.size, 44)

    draw = ImageDraw.Draw(canvas)
    label_font = font(lang, "bold", 34)
    labels = [
        (copy.extra["primary"], strip_x + 80, strip_y + search_strip.height + 58, BLUE),
        (copy.extra["secondary"], strip_x + 594, strip_y + search_strip.height + 58, INK),
        (copy.extra["tertiary"], strip_x + 910, strip_y + search_strip.height + 58, INK),
    ]
    for text, x, y, fill in labels:
        w = text_w(draw, text, label_font)
        draw.rounded_rectangle((x - 28, y - 34, x + w + 28, y + 34), radius=34, fill=(246, 248, 252, 255), outline=CARD_LINE, width=2)
        draw.text((x, y - 23), text, font=label_font, fill=fill)

    # A light connector points from the live panel to the enlarged search area.
    draw.line((1808, 1178, 1398, 1078), fill=(203, 211, 222, 255), width=5)
    draw.ellipse((1390, 1070, 1406, 1086), fill=BLUE)
    return canvas


# --------------------------------------------------------------------------- image 5: pinned sites

PIN_ORDER = ("chatgpt", "todoist", "slack", "gmail", "claude", "globe", "plus")


def image_pins(locale: str) -> Image.Image:
    lang = LANG[locale]
    copy = COPY[locale]["pins"]
    canvas = base_canvas()

    copy_block(canvas, lang, copy, 1530, 285)

    rail_crop_box = (24, 26, 205, 725)
    rail = load(WIN_LARGE).crop(rail_crop_box)
    rail_scale = 2.0
    rail = rail.resize((round(rail.width * rail_scale), round(rail.height * rail_scale)), Image.Resampling.LANCZOS)
    rail = rounded(rail, 58)
    rail_x, rail_y = 270, 205
    shadowed(canvas, rail, (rail_x, rail_y), blur=46, offset=(0, 28), opacity=72)
    card_outline(canvas, (rail_x, rail_y), rail.size, 58)

    draw = ImageDraw.Draw(canvas)
    card_font = font(lang, "bold", 35)
    sub_font = font(lang, "regular", 27)
    card_x = 740

    for key in PIN_ORDER:
        source_y = RAIL_ICON_Y[key]
        y = rail_y + round((source_y - rail_crop_box[1]) * rail_scale)
        if key in APP_LABELS:
            title = APP_LABELS[key]
            subtitle = copy.extra["sub"]
        else:
            title = copy.extra[key]
            subtitle = copy.extra["sub"] if key == "globe" else copy.extra["plus"]

        card_w, card_h = 430, 118
        cy = y
        card_y = cy - card_h // 2
        draw.line((rail_x + rail.width + 8, cy, card_x - 18, cy), fill=(203, 211, 222, 255), width=3)
        draw.ellipse((rail_x + rail.width + 2, cy - 7, rail_x + rail.width + 16, cy + 7), fill=BLUE)
        fill = (246, 250, 255, 255) if key == "chatgpt" else (255, 255, 255, 248)
        outline = (190, 215, 255, 255) if key == "chatgpt" else CARD_LINE
        draw.rounded_rectangle((card_x, card_y, card_x + card_w, card_y + card_h), radius=28, fill=fill, outline=outline, width=2)
        dot = BLUE if key in APP_LABELS else MUTED
        draw.ellipse((card_x + 34, card_y + 42, card_x + 62, card_y + 70), fill=dot)
        draw.text((card_x + 88, card_y + 27), title, font=card_font, fill=INK)
        draw.text((card_x + 88, card_y + 75), subtitle, font=sub_font, fill=MUTED)

    return canvas


# --------------------------------------------------------------------------- output

IMAGES = {
    "01_edge_hidden": image_hidden,
    "02_multi_webapps": image_apps,
    "03_resizable": image_resize,
    "04_quick_search": image_search,
    "05_pinned_sites": image_pins,
}


def contact_sheet(paths: list[Path], out: Path) -> None:
    thumb_w = 900
    cell_h = round(thumb_w * CANVAS[1] / CANVAS[0]) + 70
    cols = 3
    rows = (len(paths) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * (thumb_w + 30) + 30, rows * cell_h + 30), (244, 246, 250))
    draw = ImageDraw.Draw(sheet)
    for i, path in enumerate(paths):
        im = Image.open(path).convert("RGB")
        im.thumbnail((thumb_w, thumb_w), Image.Resampling.LANCZOS)
        x = 30 + (i % cols) * (thumb_w + 30)
        y = 30 + (i // cols) * cell_h
        sheet.paste(im, (x, y))
        draw.text((x + 4, y + im.height + 12), str(path.relative_to(OUT)), font=font("en", "bold", 26), fill=(58, 70, 90))
    sheet.save(out)


def main() -> None:
    all_paths: list[Path] = []
    for locale in COPY:
        out_dir = OUT / locale
        out_dir.mkdir(parents=True, exist_ok=True)
        for name, fn in IMAGES.items():
            image = fn(locale)
            assert image.size == CANVAS
            path = out_dir / f"{name}_2880x1800.png"
            image.convert("RGB").save(path)
            all_paths.append(path)
            print(path.relative_to(ROOT))
    contact_sheet(all_paths, OUT / "preview_contact_sheet.png")
    print(OUT.relative_to(ROOT) / "preview_contact_sheet.png")


if __name__ == "__main__":
    main()
