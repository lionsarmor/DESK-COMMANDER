#!/usr/bin/env python3
"""Compiled palette/cursor/saver checks. Requires make all and py65.

Writes /tmp/desk-style-preview.png from actual generated sprite pixels for
visual inspection. This is a test artifact, not a replacement art asset.
"""
from pathlib import Path
import runpy
import struct
import zlib

Harness = runpy.run_path(str(Path(__file__).with_name("test-organizer.py")))["Harness"]
h = Harness("main")
colors = {}
def palette():
    base = "p8b_palette:p8s_set_color:p8v_"
    colors[h.value(base + "index")] = h.value(base + "color", True)
h.hook("p8b_palette:p8s_set_color", palette)
fixed = None
for package in range(5):
    h.set("p8b_theme:p8v_current_package", package)
    h.run("p8b_theme:p8s_install_palette")
    current = {i: colors[i] for i in range(40, 50)}
    if fixed is None:
        fixed = current
    assert current == fixed, "A theme changed chat or cursor colors"
    assert colors[34] != colors[35]
h.set("p8b_theme:p8v_current_package", 255)
h.run("p8b_theme:p8s_install_palette")
assert h.value("p8b_theme:p8v_current_package") == 0
for package in range(5):
    h.set("p8b_theme:p8v_current_package", package)
    h.run("p8b_theme:p8s_next_package")
    assert h.state[0x600c] == (package + 1) % 5

cursors = []
for preset in range(5):
    h.set("p8b_input:p8v_mouse_preset", preset)
    pixels = []
    size = 8 if preset == 0 else 16
    for y in range(16):
        for x in range(16):
            if x >= size or y >= size:
                pixels.append(0)
                continue
            h.set("p8b_input:p8s_cursor_pixel:p8v_x", x)
            h.set("p8b_input:p8s_cursor_pixel:p8v_y", y)
            h.cpu.a, h.cpu.y = x, y
            pixels.append(h.run("p8b_input:p8s_cursor_pixel"))
    assert any(pixels)
    cursors.append(pixels)
assert set(cursors[3]) == {0, 48, 49}
assert set(cursors[4]) == {0, 48, 49}
assert cursors[4][7 * 16 + 7] == 48
h.hook("p8b_input:p8s_apply_mouse_preset", lambda: None)
for preset in range(5):
    h.set("p8b_input:p8v_mouse_preset", preset)
    h.run("p8b_input:p8s_next_mouse_preset")
    assert h.state[0x600e] == (preset + 1) % 5

h = Harness("screensaver_overlay")
vram = bytearray(0x20000)
writes = []
def poke():
    address = h.cpu.a * 65536 + h.memory[2] + h.memory[3] * 256
    vram[address] = h.cpu.y
    writes.append(address)
h.hook("cx16:vpoke", poke)
h.run("p8b_screensaver:p8s_initialize_stars")
h.run("p8b_screensaver:p8s_prepare_fridge")
assert vram[0x1fc08:0x1fc0a] == b"\x80\x8c"
assert vram[0x1fc0f] == 0xe0
assert set(vram[0x19000:0x19800]) == {0, 1, 12, 14, 15, 16}
sprite = bytes(vram[0x19000:0x19800])
writes.clear()
for _ in range(500):
    h.run("p8b_screensaver:p8s_move_fridge")
    assert 218 <= h.value("p8b_screensaver:p8v_fridge_x", True) <= 266
    assert 66 <= h.value("p8b_screensaver:p8v_fridge_y") <= 108
assert set(writes) == set(range(0x1fc0a, 0x1fc0e))
assert vram[0x19000:0x19800] == sprite
h.hook("p8b_input:p8s_enable_mouse", lambda: None)
h.hook("p8b_gfx_lores:p8s_clear_screen", lambda: None)
h.run("p8b_screensaver:p8s_open", [27])
assert vram[0x1fc0e] == 0 and h.value("p8b_input:p8v_key") == 0
h.set("p8b_input:p8v_buttons", 1)
h.run("p8b_screensaver:p8s_open", [(0, 1, 0, 0, 0), (0, 0, 0, 0, 0), (0, 1, 0, 0, 0)])
assert vram[0x1fc0e] == 0 and not h.events

# Preview with system colors and the exact compiled cursor/sprite bitmaps.
rgb = {0: (25, 32, 46), 1: (255, 255, 255), 12: (119, 119, 119),
       14: (0, 136, 255), 15: (187, 187, 187), 16: (0, 0, 0)}
for i, value in colors.items():
    rgb[i] = tuple(((value >> shift) & 15) * 17 for shift in (8, 4, 0))
width, height = 112, 60
canvas = [0] * (width * height)
for y in range(36):
    for x in range(24):
        canvas[(y + 2) * width + x + 44] = sprite[y * 32 + x]
for p, pixels in enumerate(cursors):
    for y in range(16):
        for x in range(16):
            canvas[(y + 42) * width + p * 22 + x + 3] = pixels[y * 16 + x]
scale = 6
raw = bytearray()
for y in range(height):
    row = b"".join(bytes(rgb.get(canvas[y * width + x], (255, 0, 255))) * scale
                   for x in range(width))
    for _ in range(scale):
        raw.extend(b"\0" + row)
def chunk(name, data):
    return struct.pack(">I", len(data)) + name + data + struct.pack(">I", zlib.crc32(name + data))
png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", width * scale, height * scale, 8, 2, 0, 0, 0))
png += chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")
Path("/tmp/desk-style-preview.png").write_bytes(png)
print("PASS: five stable palettes, saved theme/cursor cycles, cursor pixels,")
print("fridge bounds, 500 drift steps without image rewrites, and key/mouse exit")
