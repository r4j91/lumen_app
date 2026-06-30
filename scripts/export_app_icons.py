#!/usr/bin/env python3
"""Generate iOS-correct Stacked app icons (v3)."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "assets" / "icon" / "v3"
MASTER_SVG = OUT_DIR / "stacked_icon_master.svg"
SIZE = 1024
CX, CY = 512, 500
SYMBOL_SCALE = 0.92


@dataclass(frozen=True)
class Palette:
    name: str
    bg_top: str
    bg_mid: str
    bg_bottom: str
    surface_lift: str
    layer_front_top: str
    layer_front_bottom: str
    layer_mid_top: str
    layer_mid_bottom: str
    layer_back_top: str
    layer_back_bottom: str
    edge_front: str
    edge_mid: str
    edge_back: str


PALETTES: dict[str, Palette] = {
    "grafite_claro": Palette(
        "grafite_claro", "#2C2C2E", "#242426", "#1C1C1E", "#3A3A3C",
        "#F2F3F5", "#D8D8DC", "#AEAEB2", "#8E8E93", "#636366", "#48484A",
        "#C7C7CC", "#6C6C70", "#3A3A3C",
    ),
    "azul_nevoa": Palette(
        "azul_nevoa", "#343D4A", "#2A323D", "#1C222B", "#455062",
        "#F0F4F8", "#D4DCE6", "#9AABB8", "#7A8E9E", "#5A6D7E", "#3E4F5E",
        "#B8C8D4", "#5E7284", "#2E3A48",
    ),
    "azul_oceano": Palette(
        "azul_oceano", "#2A3F5C", "#1E3048", "#142436", "#3A5278",
        "#F2F6FA", "#C8DAEA", "#6B9FD4", "#4A7FB8", "#3A6598", "#2A4E78",
        "#A8C8E8", "#3A6A9A", "#1E3A58",
    ),
    "branco_cinza": Palette(
        "branco_cinza", "#F0F0F2", "#E8E8EC", "#DCDCE0", "#FFFFFF",
        "#3A3A3C", "#2C2C2E", "#636366", "#48484A", "#8E8E93", "#6C6C70",
        "#1C1C1E", "#3A3A3C", "#48484A",
    ),
    "preto_grafite": Palette(
        "preto_grafite", "#242426", "#1C1C1E", "#121214", "#2E2E30",
        "#F2F3F5", "#C8C8CC", "#8E8E93", "#636366", "#48484A", "#363638",
        "#AEAEB2", "#48484A", "#2C2C2E",
    ),
}

BASE_LAYERS = [
    [(512, 268), (792, 430), (512, 592), (232, 430)],
    [(512, 358), (774, 512), (512, 666), (294, 512)],
    [(512, 448), (756, 594), (512, 712), (312, 584)],
]


def scale_point(x: float, y: float) -> tuple[float, float]:
    return CX + (x - CX) * SYMBOL_SCALE, CY + (y - CY) * SYMBOL_SCALE


def pts_str(points: list[tuple[float, float]]) -> str:
    return " ".join(f"{x:.1f},{y:.1f}" for x, y in points)


def side_face(top: list[tuple[float, float]], depth: float) -> str:
    tr, br, bl, bc = top[1], (top[1][0], top[1][1] + depth), (top[2][0], top[2][1] + depth), top[2]
    return f"M {tr[0]:.1f},{tr[1]:.1f} L {br[0]:.1f},{br[1]:.1f} L {bl[0]:.1f},{bl[1]:.1f} L {bc[0]:.1f},{bc[1]:.1f} Z"


def build_svg(palette: Palette, style: str) -> str:
    assert style in ("flat", "premium")
    layers = [[scale_point(x, y) for x, y in pts] for pts in BASE_LAYERS]
    front, mid, back = layers
    shadow_blur = "16" if style == "flat" else "22"
    shadow_op = "0.26" if style == "flat" else "0.34"
    premium = (
        '\n  <rect x="0" y="0" width="1024" height="500" fill="url(#topGlow)"/>'
        if style == "premium"
        else ""
    )

    return f"""<svg width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bgGrad" x1="20%" y1="0%" x2="80%" y2="100%">
      <stop offset="0%" stop-color="{palette.bg_top}"/>
      <stop offset="55%" stop-color="{palette.bg_mid}"/>
      <stop offset="100%" stop-color="{palette.bg_bottom}"/>
    </linearGradient>
    <radialGradient id="surfaceLift" cx="40%" cy="28%" r="72%">
      <stop offset="0%" stop-color="{palette.surface_lift}" stop-opacity="0.28"/>
      <stop offset="100%" stop-color="{palette.surface_lift}" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="topGlow" x1="50%" y1="0%" x2="50%" y2="100%">
      <stop offset="0%" stop-color="#FFFFFF" stop-opacity="0.10"/>
      <stop offset="100%" stop-color="#FFFFFF" stop-opacity="0"/>
    </linearGradient>
    <linearGradient id="gradFront" x1="18%" y1="0%" x2="82%" y2="100%">
      <stop offset="0%" stop-color="{palette.layer_front_top}"/>
      <stop offset="100%" stop-color="{palette.layer_front_bottom}"/>
    </linearGradient>
    <linearGradient id="gradMid" x1="18%" y1="0%" x2="82%" y2="100%">
      <stop offset="0%" stop-color="{palette.layer_mid_top}"/>
      <stop offset="100%" stop-color="{palette.layer_mid_bottom}"/>
    </linearGradient>
    <linearGradient id="gradBack" x1="18%" y1="0%" x2="82%" y2="100%">
      <stop offset="0%" stop-color="{palette.layer_back_top}"/>
      <stop offset="100%" stop-color="{palette.layer_back_bottom}"/>
    </linearGradient>
    <filter id="layerShadow" x="-70%" y="-70%" width="240%" height="240%">
      <feDropShadow dx="0" dy="10" stdDeviation="{shadow_blur}" flood-color="#000000" flood-opacity="{shadow_op}"/>
    </filter>
  </defs>
  <rect width="{SIZE}" height="{SIZE}" fill="url(#bgGrad)"/>
  <rect width="{SIZE}" height="{SIZE}" fill="url(#surfaceLift)"/>
{premium}
  <g filter="url(#layerShadow)">
    <g><polygon points="{pts_str(back)}" fill="url(#gradBack)"/><path d="{side_face(back, 8)}" fill="{palette.edge_back}" opacity="0.88"/></g>
    <g><polygon points="{pts_str(mid)}" fill="url(#gradMid)"/><path d="{side_face(mid, 9)}" fill="{palette.edge_mid}" opacity="0.92"/></g>
    <g><polygon points="{pts_str(front)}" fill="url(#gradFront)"/><path d="{side_face(front, 10)}" fill="{palette.edge_front}" opacity="0.95"/></g>
  </g>
</svg>"""


def export_all() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    MASTER_SVG.write_text(build_svg(PALETTES["grafite_claro"], "premium"), encoding="utf-8")
    for name, palette in PALETTES.items():
        for style in ("flat", "premium"):
            (OUT_DIR / f"{name}_{style}.svg").write_text(build_svg(palette, style), encoding="utf-8")
    print("SVGs written. Run rasterize + flatten.")


if __name__ == "__main__":
    export_all()
