from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "RadioApp" / "assets"
ICON_ASSETS = ROOT / "RadioApp" / "Assets.xcassets"
OUT = ROOT / "Marketing" / "WeChatLaunch"

W, H = 1080, 1440

COLORS = {
    "bg": (10, 10, 15),
    "card": (21, 21, 32),
    "surface": (26, 26, 46),
    "cyan": (0, 217, 255),
    "magenta": (255, 0, 110),
    "purple": (131, 56, 236),
    "mint": (0, 245, 212),
    "gold": (255, 210, 63),
    "white": (246, 250, 255),
    "muted": (164, 181, 204),
}

FONT_BOLD = "/System/Library/Fonts/STHeiti Medium.ttc"
FONT_REG = "/System/Library/Fonts/STHeiti Light.ttc"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    path = FONT_BOLD if bold else FONT_REG
    return ImageFont.truetype(path, size)


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def radial_glow(
    base: Image.Image,
    center: tuple[int, int],
    radius: int,
    color: tuple[int, int, int],
    max_alpha: int,
) -> None:
    glow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    px = glow.load()
    cx, cy = center
    r2 = radius * radius
    for y in range(max(0, cy - radius), min(H, cy + radius)):
        for x in range(max(0, cx - radius), min(W, cx + radius)):
            dx, dy = x - cx, y - cy
            d2 = dx * dx + dy * dy
            if d2 < r2:
                t = 1 - math.sqrt(d2) / radius
                a = int(max_alpha * (t**1.8))
                if a > 0:
                    px[x, y] = (*color, a)
    base.alpha_composite(glow.filter(ImageFilter.GaussianBlur(18)))


def make_background(seed: int) -> Image.Image:
    random.seed(seed)
    base = Image.new("RGBA", (W, H), (*COLORS["bg"], 255))

    radial_glow(base, (130, 250), 520, COLORS["purple"], 115)
    radial_glow(base, (925, 180), 430, COLORS["cyan"], 105)
    radial_glow(base, (930, 1150), 560, COLORS["magenta"], 95)
    radial_glow(base, (190, 1250), 470, COLORS["mint"], 45)

    grid = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(grid)
    for x in range(-H, W + H, 96):
        gd.line((x, 0, x + H, H), fill=(0, 217, 255, 12), width=1)
    for y in range(120, H, 120):
        gd.line((0, y, W, y), fill=(255, 255, 255, 7), width=1)
    base.alpha_composite(grid)

    noise = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    np = noise.load()
    for _ in range(42000):
        x = random.randrange(W)
        y = random.randrange(H)
        v = random.randrange(180, 256)
        np[x, y] = (v, v, v, random.randrange(5, 14))
    base.alpha_composite(noise)
    return base


def draw_text(
    img: Image.Image,
    xy: tuple[int, int],
    text: str,
    size: int,
    color: tuple[int, int, int] = COLORS["white"],
    bold: bool = False,
    spacing: int = 10,
    alpha: int = 255,
) -> None:
    d = ImageDraw.Draw(img)
    d.multiline_text(
        xy,
        text,
        font=font(size, bold),
        fill=(*color, alpha),
        spacing=spacing,
    )


def draw_pill(
    img: Image.Image,
    xy: tuple[int, int],
    text: str,
    fill: tuple[int, int, int],
    stroke: tuple[int, int, int] | None = None,
    text_color: tuple[int, int, int] = COLORS["white"],
) -> None:
    d = ImageDraw.Draw(img)
    f = font(26, True)
    bbox = d.textbbox((0, 0), text, font=f)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x, y = xy
    pad_x, pad_y = 24, 13
    rect = (x, y, x + tw + pad_x * 2, y + th + pad_y * 2)
    d.rounded_rectangle(rect, radius=26, fill=(*fill, 54), outline=(*stroke, 150) if stroke else None, width=2)
    d.text((x + pad_x, y + pad_y - 2), text, font=f, fill=text_color)


def glass_panel(
    img: Image.Image,
    box: tuple[int, int, int, int],
    glow: tuple[int, int, int] = COLORS["cyan"],
    radius: int = 34,
    alpha: int = 146,
) -> None:
    x1, y1, x2, y2 = box
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((x1 - 5, y1 - 5, x2 + 5, y2 + 5), radius=radius + 5, fill=(*glow, 42))
    shadow = shadow.filter(ImageFilter.GaussianBlur(24))
    img.alpha_composite(shadow)

    d = ImageDraw.Draw(img)
    d.rounded_rectangle(box, radius=radius, fill=(*COLORS["card"], alpha), outline=(*glow, 120), width=2)


def paste_rounded(
    img: Image.Image,
    src_path: Path,
    box: tuple[int, int, int, int],
    radius: int = 54,
    shadow_color: tuple[int, int, int] = COLORS["magenta"],
    border_color: tuple[int, int, int] = COLORS["cyan"],
    fit: str = "contain",
) -> None:
    x, y, w, h = box
    src = Image.open(src_path).convert("RGBA")
    if fit == "cover":
        scale = max(w / src.width, h / src.height)
    else:
        scale = min(w / src.width, h / src.height)
    nw, nh = int(src.width * scale), int(src.height * scale)
    src = src.resize((nw, nh), Image.LANCZOS)
    if fit == "cover":
        left = max(0, (nw - w) // 2)
        top = max(0, (nh - h) // 2)
        src = src.crop((left, top, left + w, top + h))
    else:
        canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        canvas.alpha_composite(src, ((w - nw) // 2, (h - nh) // 2))
        src = canvas

    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((x, y, x + w, y + h), radius=radius, fill=(*shadow_color, 115))
    shadow = shadow.filter(ImageFilter.GaussianBlur(34))
    img.alpha_composite(shadow)

    mask = rounded_mask((w, h), radius)
    img.paste(src, (x, y), mask)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((x, y, x + w, y + h), radius=radius, outline=(*border_color, 130), width=3)


def paste_icon(img: Image.Image, src_path: Path, center: tuple[int, int], size: int, radius: int = 30) -> None:
    icon = Image.open(src_path).convert("RGBA")
    icon.thumbnail((size, size), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    canvas.alpha_composite(icon, ((size - icon.width) // 2, (size - icon.height) // 2))
    x, y = center[0] - size // 2, center[1] - size // 2
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((x, y, x + size, y + size), radius=radius, fill=(0, 217, 255, 56))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(18)))
    mask = rounded_mask((size, size), radius)
    img.paste(canvas, (x, y), mask)


def footer_mark(img: Image.Image, page: str) -> None:
    d = ImageDraw.Draw(img)
    d.text((72, H - 82), "拾音 FM", font=font(25, True), fill=(*COLORS["muted"], 210))
    d.text((W - 150, H - 82), page, font=font(25, True), fill=(255, 255, 255, 125))


def card_01() -> Image.Image:
    img = make_background(1)
    paste_rounded(img, ASSETS / "1-2.png", (570, 372, 390, 845), radius=54)
    paste_icon(img, ICON_ASSETS / "AppIcon.appiconset" / "FM.png", (144, 124), 84, radius=22)
    draw_pill(img, (206, 90), "电台 · 识曲 · 歌词", COLORS["surface"], COLORS["cyan"])
    draw_text(img, (72, 220), "在全球电台里\n遇见下一首喜欢的歌", 76, bold=True, spacing=16)
    draw_text(img, (76, 440), "打开一个陌生电台，\n听见正在发生的声音。\n喜欢的歌，下一秒\n就能被捡起来。", 31, COLORS["muted"], spacing=12)
    glass_panel(img, (72, 1030, 502, 1192), COLORS["magenta"], radius=30, alpha=118)
    draw_text(img, (104, 1062), "不是算法推荐", 34, bold=True)
    draw_text(img, (104, 1124), "而是从真实电台里\n随机撞见一首歌", 28, COLORS["muted"], spacing=10)
    footer_mark(img, "01")
    return img


def card_02() -> Image.Image:
    img = make_background(2)
    paste_rounded(img, ASSETS / "1-1.png", (92, 506, 420, 910), radius=52, shadow_color=COLORS["cyan"])
    paste_rounded(img, ASSETS / "7-3.png", (570, 570, 380, 826), radius=50, shadow_color=COLORS["purple"], border_color=COLORS["magenta"])
    draw_pill(img, (72, 82), "发现频道", COLORS["surface"], COLORS["magenta"])
    draw_text(img, (72, 180), "有些歌，不是搜到的\n是偶然听见的", 72, bold=True, spacing=16)
    draw_text(img, (76, 365), "从首页挑一个电台，按下播放。\n让真实电台，替你打开\n一个新的音乐房间。", 31, COLORS["muted"], spacing=12)
    glass_panel(img, (610, 230, 946, 364), COLORS["cyan"], radius=28, alpha=120)
    draw_text(img, (642, 258), "收藏喜欢的频道", 30, bold=True)
    draw_text(img, (642, 310), "下一次，直接回到那段声音。", 24, COLORS["muted"])
    footer_mark(img, "02")
    return img


def card_03() -> Image.Image:
    img = make_background(3)
    paste_rounded(img, ASSETS / "7-5.png", (565, 382, 380, 824), radius=54, shadow_color=COLORS["magenta"])
    draw_pill(img, (72, 84), "音乐识别", COLORS["surface"], COLORS["cyan"])
    draw_text(img, (72, 186), "边听电台\n边识别歌曲", 82, bold=True, spacing=14)
    draw_text(img, (76, 410), "听到喜欢的旋律，\n直接在播放器里识别。\n歌名、歌手、封面和歌词，\n尽量一次给你。", 30, COLORS["muted"], spacing=12)
    glass_panel(img, (84, 640, 458, 852), COLORS["cyan"], radius=30, alpha=132)
    draw_text(img, (120, 678), "一键识别", 40, COLORS["white"], bold=True)
    draw_text(img, (120, 748), "不用退出电台\n也不用手忙脚乱\n打开别的 App", 27, COLORS["muted"], spacing=10)
    draw_pill(img, (118, 906), "Shazam + 中文歌增强", COLORS["surface"], COLORS["magenta"])
    footer_mark(img, "03")
    return img


def card_04() -> Image.Image:
    img = make_background(4)
    draw_pill(img, (72, 82), "继续听", COLORS["surface"], COLORS["magenta"])
    draw_text(img, (72, 180), "识别之后\n还能继续听", 82, bold=True, spacing=14)
    draw_text(img, (76, 405), "跳到 Apple Music、QQ 音乐、网易云。\n也可以回到歌词和历史记录，把好歌留住。", 32, COLORS["muted"], spacing=15)

    paste_rounded(img, ASSETS / "5-5.png", (86, 555, 350, 758), radius=46, shadow_color=COLORS["cyan"])
    paste_rounded(img, ASSETS / "7-6.png", (650, 602, 340, 736), radius=46, shadow_color=COLORS["purple"], border_color=COLORS["magenta"])
    paste_rounded(img, ASSETS / "5-3.png", (355, 474, 390, 845), radius=52, shadow_color=COLORS["magenta"])

    glass_panel(img, (143, 1180, 936, 1300), COLORS["cyan"], radius=36, alpha=152)
    icon_y = 1240
    paste_icon(img, ICON_ASSETS / "AppleMusicLogo.imageset" / "AM.png", (255, icon_y), 72, radius=18)
    paste_icon(img, ICON_ASSETS / "QQMusicLogo.imageset" / "qq.png", (405, icon_y), 72, radius=18)
    paste_icon(img, ICON_ASSETS / "NetEaseLogo.imageset" / "WY.png", (555, icon_y), 72, radius=18)
    draw_text(img, (650, 1212), "音乐平台 / 歌词 / 历史", 30, COLORS["white"], bold=True)
    draw_text(img, (650, 1260), "从偶遇，到收藏。", 24, COLORS["muted"])
    footer_mark(img, "04")
    return img


def card_05() -> Image.Image:
    img = make_background(5)
    paste_icon(img, ICON_ASSETS / "AppIcon.appiconset" / "FM.png", (170, 145), 112, radius=28)
    draw_pill(img, (254, 102), "独立 App", COLORS["surface"], COLORS["cyan"])
    draw_text(img, (72, 235), "如果你也喜欢\n在电台里\n发现歌", 74, bold=True, spacing=14)
    draw_text(img, (76, 542), "试试拾音 FM。\n一个为夜晚、工作和随机播放\n准备的小收音机。", 31, COLORS["muted"], spacing=13)

    paste_rounded(img, ASSETS / "7-2.png", (630, 362, 330, 716), radius=48, shadow_color=COLORS["magenta"], border_color=COLORS["cyan"])
    glass_panel(img, (86, 720, 570, 1090), COLORS["magenta"], radius=40, alpha=150)
    draw_text(img, (126, 770), "拾音 FM", 58, COLORS["white"], bold=True)
    draw_text(img, (130, 858), "互联网电台\n音乐识别\n同步歌词\n历史收藏", 34, COLORS["muted"], spacing=18)

    glass_panel(img, (146, 1138, 935, 1288), COLORS["cyan"], radius=34, alpha=146)
    draw_text(img, (192, 1174), "App Store 搜索「拾音 FM」", 38, COLORS["white"], bold=True)
    draw_text(img, (194, 1234), "也可以替换这里为下载二维码或测试链接", 25, COLORS["muted"])
    footer_mark(img, "05")
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    cards = [card_01(), card_02(), card_03(), card_04(), card_05()]
    for idx, img in enumerate(cards, start=1):
        img.convert("RGB").save(OUT / f"{idx:02d}-wechat-card.png", quality=95)

    preview_w = 270
    preview_h = int(H * preview_w / W)
    sheet = Image.new("RGB", (preview_w * 5, preview_h), COLORS["bg"])
    for i, img in enumerate(cards):
        thumb = img.convert("RGB").resize((preview_w, preview_h), Image.LANCZOS)
        sheet.paste(thumb, (i * preview_w, 0))
    sheet.save(OUT / "wechat-cards-preview.jpg", quality=92)


if __name__ == "__main__":
    main()
