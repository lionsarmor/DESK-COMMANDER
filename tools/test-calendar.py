#!/usr/bin/env python3
"""Compiled-code calendar text and dashboard hit tests; needs py65 and make all."""
import runpy
import re
from pathlib import Path

Harness = runpy.run_path(str(Path(__file__).with_name("test-organizer.py")))["Harness"]
h = Harness("main")
prefix = "p8b_calendar_app:"
assembly = (Path(__file__).resolve().parents[1] / "build/main.asm").read_text()
for field in ("current_month", "current_year", "selected_day", "first_weekday"):
    match = re.search(r"p8v_" + field + r"\s*=\s*(\d+)\s*; zp", assembly)
    if match:
        h.labels[prefix + "p8v_" + field] = int(match[1])
h.set(prefix + "p8v_current_month", 9)
year = h.address(prefix + "p8v_current_year")
h.memory[year:year + 2] = [2026 & 255, 2026 >> 8]
h.set(prefix + "p8v_first_weekday", 2)
for slot in range(24):
    for field, value in (("event_months", 9), ("event_days", slot + 1),
                         ("event_types", 1)):
        h.memory[h.address(prefix + "p8v_" + field) + slot] = value
    h.memory[h.address(prefix + "p8v_event_years_lsb") + slot] = 2026 & 255
    h.memory[h.address(prefix + "p8v_event_years_msb") + slot] = 2026 >> 8

# Existing 19-character titles remain readable with a zeroed extension.
# Fill all 24 events to the new limit and check every byte outside text fields.
before = bytes(h.state)
changed = set()
for slot in range(24):
    old = 0x60a0 + 126 + slot * 20
    extra = 0x6cd0 + slot * 29
    h.state[old:old + 20] = b"O" * 19 + b"\0"
    h.cpu.a = slot
    assert h.run(prefix + "p8s_event_title_length") == 19
    h.set(prefix + "p8v_selected_day", slot + 1)
    for _ in range(28):
        h.cpu.a = ord("N")
        h.run(prefix + "p8s_edit_event_title")
    saved = bytes(h.state)
    h.cpu.a = ord("X")
    h.run(prefix + "p8s_edit_event_title")
    assert bytes(h.state) == saved, "48th character must not modify state"
    h.cpu.a = slot
    assert h.run(prefix + "p8s_event_title_length") == 47
    assert h.state[old:old + 20] == b"O" * 19 + b"\0"
    assert h.state[extra:extra + 29] == b"N" * 28 + b"\0"
    h.text.clear()
    h.cpu.a = slot
    h.run(prefix + "p8s_draw_event_title")
    assert b"".join(text for _, _, text in h.text) == b"O" * 19 + b"N" * 28
    assert all(77 <= x and x + len(text) * 8 <= 254 and 81 <= y <= 107
               for x, y, text in h.text)
    changed.update(range(old, old + 20))
    changed.update(range(extra, extra + 29))
assert all(h.state[i] == before[i] for i in range(65536) if i not in changed)

# Match all 24 highlighted rectangles, including columns beyond x=255.
def point(x, y):
    for field, value in (("mouse_x", x), ("mouse_y", y)):
        address = h.address("p8b_input:p8v_" + field)
        h.memory[address:address + 2] = [value & 255, value >> 8]
    return h.run("p8b_desktop:p8s_glance_event_at_pointer")

for day in range(1, 25):
    slot = 2 + day - 1
    assert point(174 + (slot % 7) * 19, 67 + (slot // 7) * 9) == day
assert point(174, 46) == 0  # month heading
assert point(173, 66) == 0  # leading empty date
slot = 2 + 25 - 1
assert point(174 + (slot % 7) * 19, 67 + (slot // 7) * 9) == 0
print("PASS: 24 preserved titles, 47-character limit, wrapped text bounds,")
print("isolated storage, and all highlighted dashboard date hitboxes")
