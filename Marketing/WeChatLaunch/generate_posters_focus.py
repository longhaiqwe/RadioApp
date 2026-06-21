from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "RadioApp" / "assets"
ICON_ASSETS = ROOT / "RadioApp" / "Assets.xcassets"
OUT = ROOT / "Marketing" / "WeChatLaunch" / "focus"

W, H = 1080, 1440

COLORS = {
    "bg": (10, 10, 15),
    "card": (18, 18, 28),
    "cyan": (0, 217, 255),
    "magenta": (255, 0, 110),
    "purple": (131, 56, 236),
    "white": (248, 250, 255),
    "muted": (168, 181, 204),
}

FONT_BOLD = "/System/Library/Fonts/STHeiti Medium.ttc"
FONT_REG = "/System/Library/Fonts/STHeiti Light.ttc"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(FONT_BOLD if bold else FONT_REG, size)


def bg(seed: int = 1) -> Image.Image:
    # A quieter background than v1: fewer lines, no dense panels.
    img = Image.new("RGBA", (W, H), (*COLORS["bg"], 255))
    for center, radius, color, alpha in [
        ((120, 180), 520, COLORS["purple"], 95),
        ((930, 210), 500, COLORS["cyan"], 88),
        ((870, 1180), 520, COLORS["magenta"], 80),
    ]:
        layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        px = layer.load()
        cx, cy = center
        for y in range(max(0, cy - radius), min(H, cy + radius)):
            for x in range(max(0, cx - radius), min(W, cx + radius)):
                dx, dy = x - cx, y - cy
                dist = (dx * dx + dy * dy) ** 0.5
                if dist < radius:
                    a = int(alpha * ((1 - dist / radius) ** 2.2))
                    if a:
                        px[x, y] = (*color, a)
        img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(26)))

    return img


def text(
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


def pill(img: Image.Image, xy: tuple[int, int], value: str, color: tuple[int, int, int]) -> None:
    d = ImageDraw.Draw(img)
    f = font(25, True)
    bbox = d.textbbox((0, 0), value, font=f)
    w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x, y = xy
    d.rounded_rectangle(
        (x, y, x + w + 48, y + h + 26),
        radius=27,
        fill=(20, 20, 32, 170),
        outline=(*color, 190),
        width=2,
    )
    d.text((x + 24, y + 11), value, font=f, fill=COLORS["white"])


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def paste_phone(
    img: Image.Image,
    src_path: Path,
    box: tuple[int, int, int, int],
    border: tuple[int, int, int] = COLORS["cyan"],
) -> None:
    x, y, w, h = box
    src = Image.open(src_path).convert("RGBA")
    scale = min(w / src.width, h / src.height)
    nw, nh = int(src.width * scale), int(src.height * scale)
    src = src.resize((nw, nh), Image.LANCZOS)
    px, py = x + (w - nw) // 2, y + (h - nh) // 2

    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle((px, py, px + nw, py + nh), radius=56, fill=(*border, 92))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(30)))

    mask = rounded_mask((nw, nh), 54)
    img.paste(src, (px, py), mask)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((px, py, px + nw, py + nh), radius=54, outline=(*border, 170), width=3)


def paste_icon(img: Image.Image, xy: tuple[int, int], size: int) -> None:
    src = Image.open(ICON_ASSETS / "AppIcon.appiconset" / "FM.png").convert("RGBA")
    src = src.resize((size, size), Image.LANCZOS)
    x, y = xy
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle((x, y, x + size, y + size), radius=size // 4, fill=(*COLORS["magenta"], 92))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(28)))
    img.paste(src, (x, y), rounded_mask((size, size), size // 4))


def footer(img: Image.Image) -> None:
    # Focus version intentionally keeps the poster edges quiet.
    return None


def card_01() -> Image.Image:
    img = bg(1)
    paste_icon(img, (416, 165), 248)
    text(img, (72, 505), "拾音 FM", 110, bold=True)
    text(img, (76, 665), "在电台里，遇见下一首喜欢的歌。", 42, COLORS["muted"])
    paste_phone(img, ASSETS / "1-2.png", (342, 820, 396, 520), COLORS["cyan"])
    footer(img)
    return img


def card_02() -> Image.Image:
    img = bg(2)
    text(img, (72, 135), "有些歌\n是偶然听见的", 88, bold=True, spacing=12)
    text(img, (76, 375), "打开一个电台，让真实声音开始播放。", 38, COLORS["muted"])
    paste_phone(img, ASSETS / "1-1.png", (236, 520, 608, 820), COLORS["cyan"])
    footer(img)
    return img


def card_03() -> Image.Image:
    img = bg(3)
    text(img, (72, 135), "听到喜欢的歌\n点一下识别", 86, bold=True, spacing=12)
    text(img, (76, 375), "歌名、歌手、封面和歌词，尽量一次给你。", 36, COLORS["muted"])
    paste_phone(img, ASSETS / "7-5.png", (345, 530, 390, 848), COLORS["magenta"])
    footer(img)
    return img


def card_04() -> Image.Image:
    img = bg(4)
    text(img, (72, 135), "识别之后\n还能继续听", 88, bold=True, spacing=12)
    text(img, (76, 375), "跳到音乐平台，或者回到歌词和历史记录。", 36, COLORS["muted"])
    paste_phone(img, ASSETS / "5-3.png", (345, 530, 390, 848), COLORS["cyan"])
    footer(img)
    return img


def card_05() -> Image.Image:
    img = bg(5)
    paste_icon(img, (420, 185), 240)
    text(img, (72, 545), "试试拾音 FM", 92, bold=True)
    text(img, (76, 690), "一个为夜晚、工作和随机播放准备的小收音机。", 36, COLORS["muted"])

    d = ImageDraw.Draw(img)
    d.rounded_rectangle((150, 925, 930, 1068), radius=38, fill=(18, 18, 28, 198), outline=(*COLORS["cyan"], 190), width=2)
    text(img, (218, 968), "App Store 搜索「拾音 FM」", 42, bold=True)
    footer(img)
    return img


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    cards = [card_01(), card_02(), card_03(), card_04(), card_05()]
    for idx, img in enumerate(cards, 1):
        img.convert("RGB").save(OUT / f"{idx:02d}-wechat-card-focus.png", quality=95)

    preview_w = 270
    preview_h = int(H * preview_w / W)
    preview = Image.new("RGB", (preview_w * 5, preview_h), COLORS["bg"])
    for i, img in enumerate(cards):
        preview.paste(img.convert("RGB").resize((preview_w, preview_h), Image.LANCZOS), (i * preview_w, 0))
    preview.save(OUT / "wechat-cards-focus-preview.jpg", quality=92)


if __name__ == "__main__":
    main()
