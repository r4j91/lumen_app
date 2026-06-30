#!/usr/bin/env python3
"""Flatten v3 icon PNGs to opaque RGB (required for iOS)."""
from pathlib import Path
from PIL import Image

V3 = Path(__file__).resolve().parents[1] / "assets" / "icon" / "v3"

for png in V3.glob("*_1024*.png"):
    im = Image.open(png).convert("RGBA")
    bg = Image.new("RGB", im.size, im.getpixel((0, 0))[:3])
    bg.paste(im, mask=im.split()[3])
    bg.save(png, "PNG")
    print(f"RGB {png.name}")
