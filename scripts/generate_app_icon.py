#!/usr/bin/env python3
"""Generate and package the macOS app icon assets."""

from __future__ import annotations

import shutil
import subprocess
import json
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
ASSETS_DIR = ROOT_DIR / "assets"
RESOURCE_ICON_DIR = ROOT_DIR / "Sources" / "PodcastTranscriptStudioCore" / "Resources" / "AppIcons"
TMP_DIR = ROOT_DIR / "tmp"
DRAW_DIR = TMP_DIR / "generated-app-icons"
ICONSET_DIR = TMP_DIR / "AppIcon.iconset"
ICON_COMPOSER_APP = Path("/Applications/Xcode.app/Contents/Applications/Icon Composer.app")
ICTOOL = ICON_COMPOSER_APP / "Contents" / "Executables" / "ictool"

CANVAS_SIZE = 1024
FINAL_ICON_SCALE = 0.80

BLACK_ASSET = ASSETS_DIR / "AppIcon-black.png"
WHITE_ASSET = ASSETS_DIR / "AppIcon-white.png"
PREVIEW_ASSET = ASSETS_DIR / "AppIcon.png"
ICNS_ASSET = ASSETS_DIR / "AppIcon.icns"
BLACK_COMPOSER_DOC = ASSETS_DIR / "AppIcon-black.icon"
WHITE_COMPOSER_DOC = ASSETS_DIR / "AppIcon-white.icon"
BLACK_RESOURCE = RESOURCE_ICON_DIR / "AppIconDark.png"
WHITE_RESOURCE = RESOURCE_ICON_DIR / "AppIconLight.png"


def require_tool(name: str) -> None:
    if not shutil.which(name):
        raise SystemExit(f"{name} is required.")


def require_path(path: Path) -> None:
    if not path.exists():
        raise SystemExit(f"{path} is required.")


def run(args: list[str]) -> None:
    subprocess.run(args, check=True)


def palette(variant: str) -> dict[str, str]:
    if variant == "black":
        return {
            "composer_fill": "extended-srgb:0.95500,0.97000,0.99500,1.00000",
            "text": "#171C25",
            "primary": "#1C222C",
            "muted": "#8E98A7",
            "accent": "#777BFF",
            "accent_soft": "#BFC2FF",
            "accent_edge": "#EEF0FF",
            "stroke": "#FFFFFF",
            "shadow": "#000000",
        }

    return {
        "composer_fill": "extended-srgb:0.04500,0.05000,0.06200,1.00000",
        "text": "#F5F7FC",
        "primary": "#F2F5FA",
        "muted": "#C9D0DA",
        "accent": "#8588FF",
        "accent_soft": "#C8CBFF",
        "accent_edge": "#F3F4FF",
        "stroke": "#080B12",
        "shadow": "#000000",
    }


def foreground_svg(variant: str) -> str:
    colors = palette(variant)
    text_stroke_opacity = "0.36" if variant == "black" else "0.30"

    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS_SIZE}" height="{CANVAS_SIZE}" viewBox="0 0 {CANVAS_SIZE} {CANVAS_SIZE}">
  <g transform="translate(512 512) scale(0.82) translate(-512 -512)">
    <g fill="none" stroke-linecap="round" stroke-width="30">
      <line x1="150" y1="356" x2="150" y2="430" stroke="{colors['accent_soft']}"/>
      <line x1="205" y1="324" x2="205" y2="462" stroke="{colors['primary']}"/>
      <line x1="260" y1="282" x2="260" y2="504" stroke="{colors['primary']}"/>
      <line x1="315" y1="232" x2="315" y2="554" stroke="{colors['accent']}"/>
      <line x1="370" y1="282" x2="370" y2="504" stroke="{colors['primary']}"/>
      <line x1="425" y1="324" x2="425" y2="462" stroke="{colors['primary']}"/>
      <line x1="480" y1="356" x2="480" y2="430" stroke="{colors['accent_soft']}"/>
    </g>

    <g fill="none" stroke-linecap="round" stroke-width="32">
      <line x1="641" y1="302" x2="695" y2="302" stroke="{colors['accent']}"/>
      <line x1="758" y1="302" x2="888" y2="302" stroke="{colors['primary']}"/>
      <line x1="641" y1="396" x2="695" y2="396" stroke="{colors['accent']}"/>
      <line x1="758" y1="396" x2="888" y2="396" stroke="{colors['primary']}"/>
      <line x1="641" y1="490" x2="695" y2="490" stroke="{colors['accent']}"/>
      <line x1="758" y1="490" x2="888" y2="490" stroke="{colors['primary']}"/>
    </g>

    <g fill="{colors['muted']}" opacity="0.72">
      <rect x="572" y="286" width="22" height="22" rx="11"/>
      <rect x="572" y="380" width="22" height="22" rx="11"/>
      <rect x="572" y="474" width="22" height="22" rx="11"/>
    </g>

    <text x="512" y="824" text-anchor="middle"
      font-family="Arial Black, Helvetica Neue, Helvetica, Arial, sans-serif"
      font-size="266" font-weight="900" letter-spacing="0"
      stroke="{colors['stroke']}" stroke-width="5" stroke-opacity="{text_stroke_opacity}"
      paint-order="stroke fill" fill="{colors['text']}">PTS</text>
    <rect x="456" y="356" width="112" height="112" rx="28" fill="{colors['accent']}" opacity="0.94"/>
    <rect x="463" y="363" width="98" height="98" rx="24" fill="none" stroke="{colors['accent_edge']}" stroke-width="4" opacity="0.48"/>
    <path d="M484 378 C501 366 533 367 548 389" fill="none" stroke="#FFFFFF" stroke-width="7" stroke-linecap="round" opacity="0.18"/>
  </g>
</svg>
"""


def render_foreground(variant: str, output: Path) -> None:
    DRAW_DIR.mkdir(parents=True, exist_ok=True)
    svg_path = DRAW_DIR / f"AppIconForeground-{variant}.svg"
    svg_path.write_text(foreground_svg(variant), encoding="utf-8")
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


def write_composer_document(variant: str, foreground: Path, document: Path) -> None:
    colors = palette(variant)
    if document.exists():
        shutil.rmtree(document)

    asset_dir = document / "Assets"
    asset_dir.mkdir(parents=True, exist_ok=True)
    image_name = f"PTSForeground-{variant}.png"
    shutil.copyfile(foreground, asset_dir / image_name)

    document_data = {
        "fill": {
            "automatic-gradient": colors["composer_fill"],
        },
        "groups": [
            {
                "layers": [
                    {
                        "image-name": image_name,
                        "name": "PTS Foreground",
                    }
                ],
                "shadow": {
                    "kind": "neutral",
                    "opacity": 0,
                },
                "translucency": {
                    "enabled": False,
                    "value": 0,
                },
            }
        ],
        "supported-platforms": {
            "circles": [
                "watchOS",
            ],
            "squares": "shared",
        },
    }
    (document / "icon.json").write_text(
        json.dumps(document_data, indent=2),
        encoding="utf-8",
    )


def pad_icon_to_canvas(source: Path, output: Path) -> None:
    scaled_size = round(CANVAS_SIZE * FINAL_ICON_SCALE)
    run([
        "magick",
        str(source),
        "-resize",
        f"{scaled_size}x{scaled_size}",
        "-background",
        "none",
        "-gravity",
        "center",
        "-extent",
        f"{CANVAS_SIZE}x{CANVAS_SIZE}",
        str(output),
    ])


def export_composer_image(document: Path, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    composer_output = DRAW_DIR / f"{output.stem}-composer.png"
    run([
        str(ICTOOL),
        str(document),
        "--export-image",
        "--output-file",
        str(composer_output),
        "--platform",
        "macOS",
        "--rendition",
        "Default",
        "--width",
        str(CANVAS_SIZE),
        "--height",
        str(CANVAS_SIZE),
        "--scale",
        "1",
    ])
    pad_icon_to_canvas(composer_output, output)


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
    require_path(ICTOOL)

    black_foreground = DRAW_DIR / "PTSForeground-black.png"
    white_foreground = DRAW_DIR / "PTSForeground-white.png"
    render_foreground("black", black_foreground)
    render_foreground("white", white_foreground)

    write_composer_document("black", black_foreground, BLACK_COMPOSER_DOC)
    write_composer_document("white", white_foreground, WHITE_COMPOSER_DOC)
    export_composer_image(BLACK_COMPOSER_DOC, BLACK_ASSET)
    export_composer_image(WHITE_COMPOSER_DOC, WHITE_ASSET)
    shutil.copyfile(WHITE_ASSET, PREVIEW_ASSET)

    RESOURCE_ICON_DIR.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(BLACK_ASSET, BLACK_RESOURCE)
    shutil.copyfile(WHITE_ASSET, WHITE_RESOURCE)

    build_iconset(PREVIEW_ASSET)
    run(["iconutil", "-c", "icns", str(ICONSET_DIR), "-o", str(ICNS_ASSET)])

    print(f"wrote {PREVIEW_ASSET}")
    print(f"wrote {ICNS_ASSET}")
    print(f"wrote {BLACK_COMPOSER_DOC}")
    print(f"wrote {WHITE_COMPOSER_DOC}")
    print(f"wrote {BLACK_RESOURCE}")
    print(f"wrote {WHITE_RESOURCE}")


if __name__ == "__main__":
    main()
