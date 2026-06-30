#!/usr/bin/env python3
"""Preview-only: extrai o stack arredondado do v2 e coloca em fundo full-bleed iOS."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
V2 = ROOT / "assets" / "icon" / "v2_refinado"
OUT = ROOT / "assets" / "icon" / "v3_preview"
SIZE = 1024
TARGET_W = 820


def lerp(a: int, b: int, t: float) -> int:
    return int(a + (b - a) * t)


def hex_rgb(h: str) -> tuple[int, int, int]:
    h = h.lstrip("#")
    return int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def gradient_bg(top: str, mid: str, bottom: str) -> Image.Image:
    t_c, m_c, b_c = hex_rgb(top), hex_rgb(mid), hex_rgb(bottom)
    img = Image.new("RGB", (SIZE, SIZE))
    px = img.load()
    for y in range(SIZE):
        t = y / (SIZE - 1)
        if t < 0.55:
            k = t / 0.55
            rgb = tuple(lerp(t_c[i], m_c[i], k) for i in range(3))
        else:
            k = (t - 0.55) / 0.45
            rgb = tuple(lerp(m_c[i], b_c[i], k) for i in range(3))
        for x in range(SIZE):
            px[x, y] = rgb
    lift = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(lift).ellipse((-80, -80, SIZE + 80, SIZE + 80), fill=38)
    lift = lift.filter(ImageFilter.GaussianBlur(90))
    return Image.composite(img, Image.new("RGB", (SIZE, SIZE), bottom), lift)


def extract_stack(v2_path: Path) -> Image.Image:
    im = Image.open(v2_path).convert("RGBA")
    minx = miny = SIZE
    maxx = maxy = 0
    px = im.load()
    for y in range(SIZE):
        for x in range(SIZE):
            r, g, b, _ = px[x, y]
            if max(r, g, b) > 55:
                minx, miny = min(minx, x), min(miny, y)
                maxx, maxy = max(maxx, x), max(maxy, y)
    stack = im.crop((minx, miny, maxx + 1, maxy + 1))
    # Preto externo → transparente
    data = stack.load()
    for y in range(stack.height):
        for x in range(stack.width):
            r, g, b, a = data[x, y]
            if r < 20 and g < 20 and b < 20:
                data[x, y] = (0, 0, 0, 0)
    return stack


def premium_glow() -> Image.Image:
    g = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(g).rectangle((0, 0, SIZE, SIZE // 2), fill=(255, 255, 255, 20))
    return g.filter(ImageFilter.GaussianBlur(16))


VARIANTS = {
    "grafite_claro": ("#2C2C2E", "#242426", "#1C1C1E"),
    "azul_nevoa": ("#343D4A", "#2A323D", "#1C222B"),
    "azul_oceano": ("#2A3F5C", "#1E3048", "#142436"),
    "branco_cinza": ("#F0F0F2", "#E8E8EC", "#DCDCE0"),
    "preto_grafite": ("#242426", "#1C1C1E", "#121214"),
}


def build_preview(name: str, bg: tuple[str, str, str]) -> None:
    src = V2 / f"{name}_1024_flat.png"
    if not src.exists():
        src = V2 / f"{name}_1024.png"
    stack = extract_stack(src)
    ratio = TARGET_W / stack.width
    th = int(stack.height * ratio)
    stack = stack.resize((TARGET_W, th), Image.Resampling.LANCZOS)

    canvas = gradient_bg(*bg).convert("RGBA")
    x = (SIZE - TARGET_W) // 2
    y = (SIZE - th) // 2 - 28
    canvas.alpha_composite(stack, (x, y))
    canvas.alpha_composite(premium_glow())

    out_rgb = Image.new("RGB", (SIZE, SIZE), bg[1])
    out_rgb.paste(canvas, mask=canvas.split()[3])
    out_rgb.save(OUT / f"{name}_1024.png", "PNG", optimize=True)
    for s, suf in ((60, "60px"), (180, "180px")):
        out_rgb.resize((s, s), Image.Resampling.LANCZOS).save(OUT / f"{name}_{suf}.png")
    print(f"OK {name}")


def build_sheet() -> None:
    names = list(VARIANTS)
    tiles = [Image.open(OUT / f"{n}_180px.png") for n in names]
    w, h = tiles[0].size
    sheet = Image.new("RGB", (w * len(tiles) + 48, h + 48), "#141416")
    for i, t in enumerate(tiles):
        sheet.paste(t, (24 + i * (w + 6), 24))
    sheet.save(OUT / "all_variants_180px.png")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, bg in VARIANTS.items():
        build_preview(name, bg)
    build_sheet()
    print(f"Previews em {OUT} — app continua no v2.")


if __name__ == "__main__":
    main()
