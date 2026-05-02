#!/usr/bin/env python3
"""Generate and package the macOS app icon assets."""

from __future__ import annotations

import shutil
import subprocess
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
ASSETS_DIR = ROOT_DIR / "assets"
RESOURCE_ICON_DIR = ROOT_DIR / "Sources" / "PodcastTranscriptStudioCore" / "Resources" / "AppIcons"
TMP_DIR = ROOT_DIR / "tmp"
DRAW_DIR = TMP_DIR / "generated-app-icons"
ICONSET_DIR = TMP_DIR / "AppIcon.iconset"

CANVAS_SIZE = 1024

DARK_ASSET = ASSETS_DIR / "AppIcon-black.png"
LIGHT_ASSET = ASSETS_DIR / "AppIcon-white.png"
PREVIEW_ASSET = ASSETS_DIR / "AppIcon.png"
ICNS_ASSET = ASSETS_DIR / "AppIcon.icns"
DARK_RESOURCE = RESOURCE_ICON_DIR / "AppIconDark.png"
LIGHT_RESOURCE = RESOURCE_ICON_DIR / "AppIconLight.png"


def require_tool(name: str) -> None:
    if not shutil.which(name):
        raise SystemExit(f"{name} is required.")


def run(args: list[str]) -> None:
    subprocess.run(args, check=True)


def palette(variant: str) -> dict[str, str]:
    if variant == "light":
        return {
            "tile_top": "#F6F7F5",
            "tile_bottom": "#DCE1E4",
            "inner": "#FFFFFF",
            "text": "#181C22",
            "primary": "#1E242B",
            "muted": "#58616C",
            "accent": "#38D889",
            "accent_soft": "#74E6AB",
        }

    return {
        "tile_top": "#1A1F27",
        "tile_bottom": "#0F1319",
        "inner": "#2D3541",
        "text": "#F6F7F5",
        "primary": "#F6F7F5",
        "muted": "#C9D0D6",
        "accent": "#63E5A2",
        "accent_soft": "#82F0B6",
    }


def icon_svg(variant: str) -> str:
    colors = palette(variant)
    inner_opacity = "0.30" if variant == "light" else "0.22"
    glow_opacity = "0.28" if variant == "light" else "0.20"
    text_shadow = "0.18" if variant == "light" else "0.32"

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS_SIZE}" height="{CANVAS_SIZE}" viewBox="0 0 {CANVAS_SIZE} {CANVAS_SIZE}">
  <defs>
    <linearGradient id="tile" x1="160" y1="96" x2="864" y2="928" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="{colors['tile_top']}"/>
      <stop offset="1" stop-color="{colors['tile_bottom']}"/>
    </linearGradient>
    <radialGradient id="accentGlow" cx="0" cy="0" r="1" gradientUnits="userSpaceOnUse" gradientTransform="translate(305 306) rotate(46) scale(330 250)">
      <stop offset="0" stop-color="{colors['accent']}" stop-opacity="{glow_opacity}"/>
      <stop offset="1" stop-color="{colors['accent']}" stop-opacity="0"/>
    </radialGradient>
    <filter id="glyphShadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="14" stdDeviation="18" flood-color="#000000" flood-opacity="{text_shadow}"/>
    </filter>
  </defs>

  <rect x="72" y="72" width="880" height="880" rx="204" fill="url(#tile)"/>
  <rect x="104" y="104" width="816" height="816" rx="178" fill="{colors['inner']}" opacity="{inner_opacity}"/>
  <rect x="72" y="72" width="880" height="880" rx="204" fill="url(#accentGlow)"/>

  <g filter="url(#glyphShadow)">
    <g fill="none" stroke-linecap="round" stroke-width="28">
      <line x1="150" y1="356" x2="150" y2="430" stroke="{colors['accent_soft']}"/>
      <line x1="205" y1="324" x2="205" y2="462" stroke="{colors['primary']}"/>
      <line x1="260" y1="282" x2="260" y2="504" stroke="{colors['primary']}"/>
      <line x1="315" y1="232" x2="315" y2="554" stroke="{colors['accent']}"/>
      <line x1="370" y1="282" x2="370" y2="504" stroke="{colors['primary']}"/>
      <line x1="425" y1="324" x2="425" y2="462" stroke="{colors['primary']}"/>
      <line x1="480" y1="356" x2="480" y2="430" stroke="{colors['accent_soft']}"/>
    </g>

    <g fill="none" stroke-linecap="round" stroke-width="31">
      <line x1="641" y1="302" x2="695" y2="302" stroke="{colors['accent']}"/>
      <line x1="758" y1="302" x2="888" y2="302" stroke="{colors['primary']}"/>
      <line x1="641" y1="396" x2="695" y2="396" stroke="{colors['accent']}"/>
      <line x1="758" y1="396" x2="888" y2="396" stroke="{colors['primary']}"/>
      <line x1="641" y1="490" x2="695" y2="490" stroke="{colors['accent']}"/>
      <line x1="758" y1="490" x2="888" y2="490" stroke="{colors['primary']}"/>
    </g>

    <g fill="{colors['muted']}" opacity="0.78">
      <rect x="572" y="286" width="22" height="22" rx="11"/>
      <rect x="572" y="380" width="22" height="22" rx="11"/>
      <rect x="572" y="474" width="22" height="22" rx="11"/>
    </g>

    <text x="512" y="826" text-anchor="middle"
      font-family="Arial Black, Helvetica Neue, Helvetica, Arial, sans-serif"
      font-size="266" font-weight="900" letter-spacing="0"
      fill="{colors['text']}">PTS</text>
  </g>
</svg>
"""


def render_icon(variant: str, output: Path) -> None:
    DRAW_DIR.mkdir(parents=True, exist_ok=True)
    svg_path = DRAW_DIR / f"AppIcon-{variant}.svg"
    svg_path.write_text(icon_svg(variant), encoding="utf-8")
    output.parent.mkdir(parents=True, exist_ok=True)
    run([
        "magick",
        "-background",
        "none",
        str(svg_path),
        "-alpha",
        "on",
        str(output),
    ])


def build_iconset(source: Path) -> None:
    if ICONSET_DIR.exists():
        shutil.rmtree(ICONSET_DIR)
    ICONSET_DIR.mkdir(parents=True, exist_ok=True)

    entries = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]

    for filename, size in entries:
        run([
            "magick",
            str(source),
            "-resize",
            f"{size}x{size}",
            str(ICONSET_DIR / filename),
        ])


def main() -> None:
    require_tool("magick")
    require_tool("iconutil")

    render_icon("dark", DARK_ASSET)
    render_icon("light", LIGHT_ASSET)
    shutil.copyfile(DARK_ASSET, PREVIEW_ASSET)

    RESOURCE_ICON_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(DARK_ASSET, DARK_RESOURCE)
    shutil.copyfile(LIGHT_ASSET, LIGHT_RESOURCE)

    build_iconset(PREVIEW_ASSET)
    run(["iconutil", "-c", "icns", str(ICONSET_DIR), "-o", str(ICNS_ASSET)])

    print(f"wrote {PREVIEW_ASSET}")
    print(f"wrote {ICNS_ASSET}")
    print(f"wrote {DARK_RESOURCE}")
    print(f"wrote {LIGHT_RESOURCE}")


if __name__ == "__main__":
    main()
