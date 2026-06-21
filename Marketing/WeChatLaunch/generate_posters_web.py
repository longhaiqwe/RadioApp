from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[2]
WEB = ROOT / "Marketing" / "WeChatLaunch" / "web"
OUT = ROOT / "Marketing" / "WeChatLaunch" / "web-cards"

W, H = 1080, 1440

COLORS = {
    "bg": (10, 10, 15),
    "card": (21, 21, 32),
    "surface": (26, 26, 46),
    "cyan": (0, 217, 255),
    "magenta": (255, 0, 110),
    "purple": (131, 56, 236),
    "gold": (255, 210, 63),
    "white": (248, 250, 255),
    "muted": (166, 180, 204),
}

FONT_BOLD = "/System/Library/Fonts/STHeiti Medium.ttc"
FONT_REG = "/System/Library/Fonts/STHeiti Light.ttc"


STATIONS = [
    ("怀集音乐之声", "music", "怀", COLORS["magenta"], COLORS["purple"]),
    ("清晨音乐台", "music,pop music", "清", COLORS["cyan"], COLORS["purple"]),
    ("AsiaFM亚洲经典台", "classic hits, music", "A", COLORS["purple"], COLORS["magenta"]),
    ("华语金曲500首", "golden music", "华", COLORS["magenta"], COLORS["gold"]),
    ("CNR-3 音乐之声", "music", "C", COLORS["cyan"], COLORS["purple"]),
]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_BOLD if bold else FONT_REG, size)


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def bg(seed: int = 0) -> Image.Image:
    img = Image.new("RGBA", (W, H), (*COLORS["bg"], 255))
    glows = [
        ((110, 150), 560, COLORS["purple"], 95),
        ((930, 210), 500, COLORS["cyan"], 85),
        ((820, 1180), 560, COLORS["magenta"], 88),
    ]
    for center, radius, color, alpha in glows:
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        px = layer.load()
        cx, cy = center
        for y in range(max(0, cy - radius), min(H, cy + radius)):
            for x in range(max(0, cx - radius), min(W, cx + radius)):
                dx, dy = x - cx, y - cy
                dist = (dx * dx + dy * dy) ** 0.5
                if dist < radius:
                    a = int(alpha * ((1 - dist / radius) ** 2.15))
                    if a:
                        px[x, y] = (*color, a)
        img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(28)))
    return img


def draw_text(
    img: Image.Image,
    xy: tuple[int, int],
    value: str,
    size: int,
    color: tuple[int, int, int] = COLORS["white"],
    bold: bool = False,
    spacing: int = 12,
    alpha: int = 255,
) -> None:
    ImageDraw.Draw(img).multiline_text(
        xy,
        value,
        font=font(size, bold),
        fill=(*color, alpha),
        spacing=spacing,
    )


def paste_round(
    img: Image.Image,
    src: Image.Image,
    box: tuple[int, int, int, int],
    radius: int = 40,
    border: tuple[int, int, int] = COLORS["cyan"],
    shadow: bool = True,
) -> None:
    x, y, w, h = box
    scale = min(w / src.width, h / src.height)
    nw, nh = int(src.width * scale), int(src.height * scale)
    resized = src.resize((nw, nh), Image.LANCZOS)
    px, py = x + (w - nw) // 2, y + (h - nh) // 2
    if shadow:
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        sd = ImageDraw.Draw(layer)
        sd.rounded_rectangle((px, py, px + nw, py + nh), radius=radius, fill=(*border, 92))
        img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(28)))
    mask = rounded_mask((nw, nh), radius)
    img.paste(resized, (px, py), mask)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((px, py, px + nw, py + nh), radius=radius, outline=(*border, 170), width=3)


def cover_round(
    img: Image.Image,
    src: Image.Image,
    box: tuple[int, int, int, int],
    radius: int = 40,
    border: tuple[int, int, int] = COLORS["cyan"],
    shadow: bool = True,
) -> None:
    x, y, w, h = box
    scale = max(w / src.width, h / src.height)
    nw, nh = int(src.width * scale), int(src.height * scale)
    resized = src.resize((nw, nh), Image.LANCZOS)
    left = max(0, (nw - w) // 2)
    top = max(0, (nh - h) // 2)
    cropped = resized.crop((left, top, left + w, top + h))
    if shadow:
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        sd = ImageDraw.Draw(layer)
        sd.rounded_rectangle((x, y, x + w, y + h), radius=radius, fill=(*border, 90))
        img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(28)))
    mask = rounded_mask((w, h), radius)
    img.paste(cropped, (x, y), mask)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((x, y, x + w, y + h), radius=radius, outline=(*border, 170), width=3)


def icon_image(size: int) -> Image.Image:
    icon = Image.open(WEB / "icon.png").convert("RGBA")
    return icon.resize((size, size), Image.LANCZOS)


def draw_browser_bar(d: ImageDraw.ImageDraw, w: int, s: int, url: str = "www.shiyinfm.cn") -> None:
    d.rounded_rectangle((18 * s, 16 * s, (w - 18) * s, 58 * s), radius=20 * s, fill=(20, 20, 30, 235), outline=(255, 255, 255, 24), width=1 * s)
    d.ellipse((34 * s, 29 * s, 44 * s, 39 * s), fill=COLORS["cyan"])
    d.text((56 * s, 27 * s), url, font=font(15 * s, True), fill=(235, 245, 255, 220))


def gradient_tile(size: int, text_value: str, c1: tuple[int, int, int], c2: tuple[int, int, int]) -> Image.Image:
    tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = tile.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (size * 2)
            px[x, y] = tuple(int(c1[i] * (1 - t) + c2[i] * t) for i in range(3)) + (255,)
    d = ImageDraw.Draw(tile)
    d.rounded_rectangle((0, 0, size, size), radius=size // 4, outline=(255, 255, 255, 30), width=max(1, size // 32))
    d.text((size // 2, size // 2), text_value, font=font(size // 3, True), anchor="mm", fill=COLORS["white"])
    return tile


def station_card(d: ImageDraw.ImageDraw, img: Image.Image, x: int, y: int, w: int, s: int, station: tuple[str, str, str, tuple[int, int, int], tuple[int, int, int]], active: bool = False) -> None:
    name, tags, initial, c1, c2 = station
    border = (*COLORS["cyan"], 120) if active else (255, 255, 255, 28)
    d.rounded_rectangle((x, y, x + w, y + 86 * s), radius=18 * s, fill=(21, 21, 32, 194), outline=border, width=1 * s)
    tile = gradient_tile(54 * s, initial, c1, c2)
    img.alpha_composite(tile, (x + 14 * s, y + 16 * s))
    d.text((x + 82 * s, y + 24 * s), name, font=font(17 * s, True), fill=COLORS["white"])
    d.text((x + 82 * s, y + 52 * s), tags, font=font(12 * s), fill=COLORS["cyan"])
    heart = "♥" if active else "♡"
    d.text((x + w - 42 * s, y + 31 * s), heart, font=font(22 * s, True), fill=COLORS["magenta"] if active else (230, 240, 255, 150))


def web_mobile(mode: str = "home") -> Image.Image:
    s = 2
    w, h = 390, 844
    img = Image.new("RGBA", (w * s, h * s), (*COLORS["bg"], 255))
    d = ImageDraw.Draw(img)

    # Background glow
    for cx, cy, r, color, alpha in [(30, -70, 280, COLORS["purple"], 90), (340, 620, 300, COLORS["cyan"], 60), (330, 120, 220, COLORS["magenta"], 45)]:
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        ld.ellipse(((cx - r) * s, (cy - r) * s, (cx + r) * s, (cy + r) * s), fill=(*color, alpha))
        img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(55 * s)))

    draw_browser_bar(d, w, s)
    d.text((18 * s, 88 * s), "发现", font=font(44 * s, True), fill=COLORS["white"])
    d.text((20 * s, 137 * s), "探索全球电台", font=font(15 * s, True), fill=COLORS["cyan"])
    d.ellipse((330 * s, 88 * s, 374 * s, 132 * s), fill=COLORS["magenta"])
    d.text((352 * s, 110 * s), "↝", font=font(25 * s, True), anchor="mm", fill=COLORS["white"])

    d.rounded_rectangle((18 * s, 166 * s, 372 * s, 230 * s), radius=18 * s, fill=(21, 21, 32, 188), outline=(*COLORS["cyan"], 90), width=1 * s)
    d.text((34 * s, 183 * s), "是缘分让我们偶遇，从「清晨音乐台」开始吧", font=font(13 * s, True), fill=(245, 250, 255, 230))
    d.text((34 * s, 207 * s), "希望你能遇到心仪的歌曲～", font=font(13 * s, True), fill=(245, 250, 255, 190))

    search_value = "音乐" if mode == "search" else "搜索电台、风格、地区..."
    d.rounded_rectangle((18 * s, 250 * s, 372 * s, 304 * s), radius=18 * s, fill=(21, 21, 32, 190), outline=(255, 255, 255, 32), width=1 * s)
    d.text((42 * s, 268 * s), search_value, font=font(15 * s, True), fill=(245, 250, 255, 220 if mode == "search" else 115))

    section_title = "搜索结果" if mode == "search" else "推荐电台"
    d.text((18 * s, 343 * s), section_title, font=font(22 * s, True), fill=COLORS["white"])
    d.text((18 * s, 373 * s), "打开浏览器即可播放。" if mode == "home" else "按名称、风格或地区找到电台。", font=font(13 * s), fill=(245, 250, 255, 130))

    y = 412 * s
    for idx, station in enumerate(STATIONS[:5]):
        station_card(d, img, 18 * s, y + idx * 98 * s, 354 * s, s, station, active=(idx == 1 or mode == "play"))

    if mode == "play":
        d.rounded_rectangle((18 * s, 690 * s, 372 * s, 816 * s), radius=24 * s, fill=(16, 16, 26, 238), outline=(*COLORS["cyan"], 110), width=1 * s)
        d.text((42 * s, 718 * s), "清晨音乐台", font=font(19 * s, True), fill=COLORS["white"])
        d.text((42 * s, 747 * s), "正在播放", font=font(13 * s, True), fill=COLORS["cyan"])
        d.ellipse((176 * s, 724 * s, 236 * s, 784 * s), fill=COLORS["magenta"])
        d.text((206 * s, 754 * s), "Ⅱ", font=font(26 * s, True), anchor="mm", fill=COLORS["white"])
        d.rounded_rectangle((42 * s, 792 * s, 348 * s, 820 * s), radius=14 * s, fill=(0, 217, 255, 24), outline=(*COLORS["cyan"], 90), width=1 * s)
        d.text((195 * s, 800 * s), "播放电台后识别歌曲", font=font(13 * s, True), anchor="ma", fill=COLORS["white"])

    return img.resize((390, 844), Image.LANCZOS)


def web_desktop() -> Image.Image:
    w, h = 1180, 760
    s = 1
    img = Image.new("RGBA", (w, h), (*COLORS["bg"], 255))
    d = ImageDraw.Draw(img)
    for cx, cy, r, color, alpha in [(50, -40, 420, COLORS["purple"], 90), (1030, 0, 380, COLORS["cyan"], 70), (980, 700, 450, COLORS["magenta"], 70)]:
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        ld.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(*color, alpha))
        img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(55)))
    draw_browser_bar(d, w, s, "https://www.shiyinfm.cn")
    d.text((64, 112), "发现", font=font(76, True), fill=COLORS["white"])
    d.text((68, 196), "探索全球电台", font=font(24, True), fill=COLORS["cyan"])
    d.ellipse((1040, 106, 1110, 176), fill=COLORS["magenta"])
    d.text((1075, 141), "↝", font=font(39, True), anchor="mm", fill=COLORS["white"])
    d.rounded_rectangle((64, 250, 1116, 340), radius=26, fill=(21, 21, 32, 188), outline=(*COLORS["cyan"], 80), width=1)
    d.text((96, 281), "是缘分让我们偶遇，从「清晨音乐台」开始吧，希望你能遇到心仪的歌曲～", font=font(24, True), fill=(245, 250, 255, 220))
    d.rounded_rectangle((64, 370, 1116, 440), radius=22, fill=(21, 21, 32, 190), outline=(255, 255, 255, 32), width=1)
    d.text((100, 393), "搜索电台、风格、地区...", font=font(22, True), fill=(245, 250, 255, 120))
    d.text((64, 500), "推荐电台", font=font(32, True), fill=COLORS["white"])
    for i, station in enumerate(STATIONS[:5]):
        x = 64 + (i % 3) * 350
        y = 546 + (i // 3) * 104
        station_card(d, img, x, y, 318, 1, station, active=(i == 1))
    return img


def web_search_desktop() -> Image.Image:
    w, h = 1180, 760
    img = Image.new("RGBA", (w, h), (*COLORS["bg"], 255))
    d = ImageDraw.Draw(img)
    for cx, cy, r, color, alpha in [(70, -20, 420, COLORS["purple"], 88), (1040, 100, 360, COLORS["cyan"], 75), (900, 680, 430, COLORS["magenta"], 76)]:
        layer = Image.new("RGBA", img.size, (0, 0, 0, 0))
        ld = ImageDraw.Draw(layer)
        ld.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(*color, alpha))
        img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(55)))
    draw_browser_bar(d, w, 1, "https://www.shiyinfm.cn")
    d.text((64, 112), "搜索", font=font(76, True), fill=COLORS["white"])
    d.text((68, 196), "按风格、地区、名称找到电台", font=font(24, True), fill=COLORS["cyan"])

    d.rounded_rectangle((64, 260, 1116, 340), radius=24, fill=(21, 21, 32, 205), outline=(*COLORS["magenta"], 90), width=1)
    d.text((102, 290), "音乐", font=font(28, True), fill=COLORS["white"])
    d.rounded_rectangle((990, 276, 1070, 324), radius=24, fill=COLORS["magenta"])
    d.text((1030, 299), "搜索", font=font(20, True), anchor="mm", fill=COLORS["white"])

    d.text((64, 410), "搜索结果", font=font(32, True), fill=COLORS["white"])
    d.text((64, 454), "网页里直接筛选，不用安装客户端。", font=font(20), fill=(245, 250, 255, 135))
    for i, station in enumerate(STATIONS[:5]):
        x = 64 + (i % 2) * 520
        y = 505 + (i // 2) * 104
        station_card(d, img, x, y, 478, 1, station, active=(i == 1))
    return img


def card_01() -> Image.Image:
    img = bg(1)
    img.alpha_composite(icon_image(150), (76, 110))
    draw_text(img, (72, 335), "打开浏览器\n就能听电台", 88, bold=True, spacing=12)
    draw_text(img, (76, 575), "不用安装 App，直接访问 shiyinfm.cn。", 38, COLORS["muted"])
    paste_round(img, web_desktop(), (90, 760, 900, 520), radius=34, border=COLORS["cyan"])
    return img


def card_02() -> Image.Image:
    img = bg(2)
    draw_text(img, (72, 125), "有些歌\n是偶然听见的", 88, bold=True, spacing=12)
    draw_text(img, (76, 365), "打开一个电台，让真实声音开始播放。", 38, COLORS["muted"])
    paste_round(img, web_mobile("home"), (330, 520, 420, 820), radius=44, border=COLORS["cyan"])
    return img


def card_03() -> Image.Image:
    img = bg(3)
    draw_text(img, (72, 125), "想听什么\n直接搜索", 86, bold=True, spacing=12)
    draw_text(img, (76, 365), "在网页里直接搜索，不用安装客户端。", 38, COLORS["muted"])
    paste_round(img, web_search_desktop(), (90, 700, 900, 580), radius=34, border=COLORS["magenta"])
    return img


def card_04() -> Image.Image:
    img = bg(4)
    draw_text(img, (72, 125), "听到喜欢的歌\n就识别出来", 86, bold=True, spacing=12)
    draw_text(img, (76, 365), "歌名、歌手、歌词和音乐平台入口，尽量一次给你。", 36, COLORS["muted"])
    recognition = Image.open(WEB / "recognition-song.jpg").convert("RGBA")
    paste_round(img, recognition, (330, 485, 420, 865), radius=44, border=COLORS["cyan"])
    return img


def card_05() -> Image.Image:
    img = bg(5)
    img.alpha_composite(icon_image(220), (430, 160))
    draw_text(img, (72, 500), "现在就试试", 92, bold=True)
    draw_text(img, (76, 650), "浏览器打开：", 37, COLORS["muted"])
    draw_text(img, (76, 718), "www.shiyinfm.cn", 58, COLORS["white"], bold=True)
    qr_path = WEB / "shiyinfm-qr.png"
    if qr_path.exists():
        qr = Image.open(qr_path).convert("RGBA")
        d = ImageDraw.Draw(img)
        d.rounded_rectangle((350, 900, 730, 1280), radius=44, fill=(255, 255, 255, 245))
        img.alpha_composite(qr.resize((312, 312), Image.LANCZOS), (384, 934))
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    cards = [card_01(), card_02(), card_03(), card_04(), card_05()]
    for idx, card in enumerate(cards, 1):
        card.convert("RGB").save(OUT / f"{idx:02d}-wechat-card-web.png", quality=95)

    preview_w = 270
    preview_h = int(H * preview_w / W)
    preview = Image.new("RGB", (preview_w * 5, preview_h), COLORS["bg"])
    for i, card in enumerate(cards):
        preview.paste(card.convert("RGB").resize((preview_w, preview_h), Image.LANCZOS), (i * preview_w, 0))
    preview.save(OUT / "wechat-cards-web-preview.jpg", quality=92)


if __name__ == "__main__":
    main()
