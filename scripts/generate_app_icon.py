#!/usr/bin/env python3
"""Generate the macOS app icon without third-party image dependencies."""

from __future__ import annotations

import math
import shutil
import struct
import subprocess
import zlib
from pathlib import Path


ROOT_DIR = Path(__file__).resolve().parents[1]
ASSETS_DIR = ROOT_DIR / "assets"
TMP_DIR = ROOT_DIR / "tmp" / "AppIcon.iconset"
PREVIEW_PATH = ASSETS_DIR / "AppIcon.png"
ICNS_PATH = ASSETS_DIR / "AppIcon.icns"


def blend_pixel(pixels: bytearray, width: int, x: int, y: int, color: tuple[int, int, int, int]) -> None:
    if x < 0 or y < 0 or x >= width:
        return
    height = len(pixels) // (width * 4)
    if y >= height:
        return

    offset = (y * width + x) * 4
    src_r, src_g, src_b, src_a = color
    if src_a == 0:
        return

    dst_r, dst_g, dst_b, dst_a = pixels[offset:offset + 4]
    src_alpha = src_a / 255.0
    dst_alpha = dst_a / 255.0
    out_alpha = src_alpha + dst_alpha * (1.0 - src_alpha)
    if out_alpha <= 0:
        return

    out_r = int((src_r * src_alpha + dst_r * dst_alpha * (1.0 - src_alpha)) / out_alpha)
    out_g = int((src_g * src_alpha + dst_g * dst_alpha * (1.0 - src_alpha)) / out_alpha)
    out_b = int((src_b * src_alpha + dst_b * dst_alpha * (1.0 - src_alpha)) / out_alpha)
    pixels[offset:offset + 4] = bytes((out_r, out_g, out_b, int(out_alpha * 255)))


def rounded_rect_contains(px: float, py: float, x: float, y: float, w: float, h: float, r: float) -> bool:
    if px < x or py < y or px > x + w or py > y + h:
        return False

    cx = min(max(px, x + r), x + w - r)
    cy = min(max(py, y + r), y + h - r)
    return (px - cx) ** 2 + (py - cy) ** 2 <= r ** 2


def lerp(a: int, b: int, t: float) -> int:
    return int(a + (b - a) * min(max(t, 0.0), 1.0))


def color_lerp(a: tuple[int, int, int, int], b: tuple[int, int, int, int], t: float) -> tuple[int, int, int, int]:
    return (
        lerp(a[0], b[0], t),
        lerp(a[1], b[1], t),
        lerp(a[2], b[2], t),
        lerp(a[3], b[3], t),
    )


def draw_rounded_rect(
    pixels: bytearray,
    size: int,
    x: float,
    y: float,
    w: float,
    h: float,
    r: float,
    color: tuple[int, int, int, int],
) -> None:
    for yy in range(max(0, int(y)), min(size, math.ceil(y + h))):
        for xx in range(max(0, int(x)), min(size, math.ceil(x + w))):
            if rounded_rect_contains(xx + 0.5, yy + 0.5, x, y, w, h, r):
                blend_pixel(pixels, size, xx, yy, color)


def draw_gradient_rounded_rect(
    pixels: bytearray,
    size: int,
    x: float,
    y: float,
    w: float,
    h: float,
    r: float,
    start: tuple[int, int, int, int],
    end: tuple[int, int, int, int],
) -> None:
    for yy in range(max(0, int(y)), min(size, math.ceil(y + h))):
        for xx in range(max(0, int(x)), min(size, math.ceil(x + w))):
            if rounded_rect_contains(xx + 0.5, yy + 0.5, x, y, w, h, r):
                t = ((xx - x) / max(w, 1)) * 0.58 + ((yy - y) / max(h, 1)) * 0.42
                blend_pixel(pixels, size, xx, yy, color_lerp(start, end, t))


def draw_rounded_rect_stroke(
    pixels: bytearray,
    size: int,
    x: float,
    y: float,
    w: float,
    h: float,
    r: float,
    stroke_width: float,
    color: tuple[int, int, int, int],
) -> None:
    inner_x = x + stroke_width
    inner_y = y + stroke_width
    inner_w = w - stroke_width * 2
    inner_h = h - stroke_width * 2
    inner_r = max(0, r - stroke_width)

    for yy in range(max(0, int(y)), min(size, math.ceil(y + h))):
        for xx in range(max(0, int(x)), min(size, math.ceil(x + w))):
            outer = rounded_rect_contains(xx + 0.5, yy + 0.5, x, y, w, h, r)
            inner = rounded_rect_contains(xx + 0.5, yy + 0.5, inner_x, inner_y, inner_w, inner_h, inner_r)
            if outer and not inner:
                blend_pixel(pixels, size, xx, yy, color)


def draw_circle(pixels: bytearray, size: int, cx: float, cy: float, radius: float, color: tuple[int, int, int, int]) -> None:
    r2 = radius * radius
    for yy in range(max(0, int(cy - radius)), min(size, math.ceil(cy + radius))):
        for xx in range(max(0, int(cx - radius)), min(size, math.ceil(cx + radius))):
            if (xx + 0.5 - cx) ** 2 + (yy + 0.5 - cy) ** 2 <= r2:
                blend_pixel(pixels, size, xx, yy, color)


def draw_line(
    pixels: bytearray,
    size: int,
    x1: float,
    y1: float,
    x2: float,
    y2: float,
    width: float,
    color: tuple[int, int, int, int],
) -> None:
    radius = width / 2.0
    min_x = max(0, int(min(x1, x2) - radius - 1))
    max_x = min(size, math.ceil(max(x1, x2) + radius + 1))
    min_y = max(0, int(min(y1, y2) - radius - 1))
    max_y = min(size, math.ceil(max(y1, y2) + radius + 1))
    dx = x2 - x1
    dy = y2 - y1
    length_squared = dx * dx + dy * dy

    for yy in range(min_y, max_y):
        for xx in range(min_x, max_x):
            px = xx + 0.5
            py = yy + 0.5
            if length_squared == 0:
                distance = math.hypot(px - x1, py - y1)
            else:
                t = ((px - x1) * dx + (py - y1) * dy) / length_squared
                t = min(max(t, 0.0), 1.0)
                projection_x = x1 + t * dx
                projection_y = y1 + t * dy
                distance = math.hypot(px - projection_x, py - projection_y)
            if distance <= radius:
                blend_pixel(pixels, size, xx, yy, color)


def draw_design(size: int) -> bytearray:
    pixels = bytearray(size * size * 4)
    u = size / 1024.0

    draw_gradient_rounded_rect(
        pixels,
        size,
        74 * u,
        74 * u,
        876 * u,
        876 * u,
        214 * u,
        (22, 23, 29, 255),
        (70, 72, 78, 255),
    )
    draw_rounded_rect(pixels, size, 112 * u, 112 * u, 800 * u, 800 * u, 178 * u, (255, 255, 255, 22))
    draw_rounded_rect_stroke(pixels, size, 74 * u, 74 * u, 876 * u, 876 * u, 214 * u, 10 * u, (255, 255, 255, 46))
    draw_rounded_rect_stroke(pixels, size, 118 * u, 118 * u, 788 * u, 788 * u, 170 * u, 4 * u, (255, 255, 255, 28))

    draw_circle(pixels, size, 338 * u, 336 * u, 220 * u, (45, 245, 132, 28))
    draw_circle(pixels, size, 690 * u, 690 * u, 200 * u, (255, 255, 255, 15))

    # Transcript document.
    draw_rounded_rect(pixels, size, 458 * u, 274 * u, 344 * u, 480 * u, 58 * u, (238, 240, 236, 226))
    draw_rounded_rect_stroke(pixels, size, 458 * u, 274 * u, 344 * u, 480 * u, 58 * u, 6 * u, (255, 255, 255, 72))
    draw_line(pixels, size, 546 * u, 402 * u, 718 * u, 402 * u, 22 * u, (46, 49, 54, 188))
    draw_line(pixels, size, 546 * u, 478 * u, 720 * u, 478 * u, 22 * u, (46, 49, 54, 156))
    draw_line(pixels, size, 546 * u, 554 * u, 680 * u, 554 * u, 22 * u, (46, 49, 54, 130))
    draw_line(pixels, size, 548 * u, 632 * u, 720 * u, 632 * u, 20 * u, (46, 49, 54, 116))
    draw_circle(pixels, size, 512 * u, 402 * u, 13 * u, (42, 229, 121, 232))
    draw_circle(pixels, size, 512 * u, 478 * u, 13 * u, (42, 229, 121, 190))
    draw_circle(pixels, size, 512 * u, 554 * u, 13 * u, (42, 229, 121, 150))

    # Voice waveform.
    waveform_x = [246, 286, 326, 366, 406]
    waveform_height = [160, 250, 324, 250, 160]
    for index, x in enumerate(waveform_x):
        height = waveform_height[index] * u
        draw_line(
            pixels,
            size,
            x * u,
            514 * u - height / 2,
            x * u,
            514 * u + height / 2,
            34 * u,
            (42, 229, 121, 238),
        )
    draw_line(pixels, size, 204 * u, 462 * u, 204 * u, 566 * u, 20 * u, (238, 240, 236, 190))
    draw_line(pixels, size, 448 * u, 462 * u, 448 * u, 566 * u, 20 * u, (238, 240, 236, 190))

    # Subtle check mark for completed transcripts.
    draw_line(pixels, size, 606 * u, 728 * u, 656 * u, 776 * u, 28 * u, (42, 229, 121, 232))
    draw_line(pixels, size, 656 * u, 776 * u, 754 * u, 672 * u, 28 * u, (42, 229, 121, 232))

    return pixels


def downsample_box(pixels: bytearray, input_size: int, output_size: int) -> bytearray:
    if input_size == output_size:
        return pixels

    scale = input_size // output_size
    output = bytearray(output_size * output_size * 4)
    divisor = scale * scale

    for y in range(output_size):
        for x in range(output_size):
            total = [0, 0, 0, 0]
            for yy in range(y * scale, (y + 1) * scale):
                row = yy * input_size * 4
                for xx in range(x * scale, (x + 1) * scale):
                    offset = row + xx * 4
                    total[0] += pixels[offset]
                    total[1] += pixels[offset + 1]
                    total[2] += pixels[offset + 2]
                    total[3] += pixels[offset + 3]

            out_offset = (y * output_size + x) * 4
            output[out_offset:out_offset + 4] = bytes(value // divisor for value in total)

    return output


def write_png(path: Path, width: int, height: int, pixels: bytearray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)
        raw.extend(pixels[y * stride:(y + 1) * stride])

    def chunk(name: bytes, payload: bytes) -> bytes:
        return (
            struct.pack(">I", len(payload))
            + name
            + payload
            + struct.pack(">I", zlib.crc32(name + payload) & 0xFFFFFFFF)
        )

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), level=9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


def main() -> None:
    if not shutil.which("iconutil"):
        raise SystemExit("iconutil is required on macOS.")

    ASSETS_DIR.mkdir(parents=True, exist_ok=True)
    if TMP_DIR.exists():
        shutil.rmtree(TMP_DIR)
    TMP_DIR.mkdir(parents=True, exist_ok=True)

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

    mipmaps: dict[int, bytearray] = {}
    current_size = 2048
    current_pixels = draw_design(current_size)
    while current_size > 16:
        next_size = current_size // 2
        current_pixels = downsample_box(current_pixels, current_size, next_size)
        current_size = next_size
        mipmaps[current_size] = current_pixels

    for filename, size in entries:
        write_png(TMP_DIR / filename, size, size, mipmaps[size])
    write_png(PREVIEW_PATH, 1024, 1024, mipmaps[1024])

    subprocess.run(
        ["iconutil", "-c", "icns", str(TMP_DIR), "-o", str(ICNS_PATH)],
        check=True,
    )
    print(f"wrote {PREVIEW_PATH}")
    print(f"wrote {ICNS_PATH}")


if __name__ == "__main__":
    main()
