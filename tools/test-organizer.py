#!/usr/bin/env python3
"""Run the compiled 65C02 organizer routines, with ROM/video/input stubs.

Requires py65. Build first with make all. This exercises actual bank binaries,
not a Python rewrite of migration or editing. It cannot validate real video,
SD failure recovery, or physical mouse timing.
"""
from pathlib import Path
from collections import deque
import re
from py65.devices.mpu65c02 import MPU

ROOT = Path(__file__).resolve().parents[1]


class Harness:
    def __init__(self, name):
        self.labels = {}
        for line in (ROOT / "build" / (name + ".vice-mon-list")).read_text().splitlines():
            parts = line.split()
            if len(parts) < 3 or parts[0] != "al":
                continue
            _, address, label = parts[:3]
            self.labels[label.lstrip(".")] = int(address, 16)
        # The monitor list omits variables assigned to zero page in the core.
        scopes = []
        for line in (ROOT / "build" / (name + ".asm")).read_text().splitlines():
            scope = re.match(r"^(\w+)\s+\.proc", line)
            variable = re.match(r"^(p8v_\w+)\s*=\s*(\d+)\s*; zp", line)
            if scope:
                scopes.append(scope[1])
            elif line.strip() == ".pend" and scopes:
                scopes.pop()
            elif variable:
                self.labels[":".join(scopes + [variable[1]])] = int(variable[2])
        self.memory = [0] * 65536
        path = ROOT / "build" / (name + ".bin")
        if path.exists():
            binary = path.read_bytes()
            load_address = 0xa000
        else:
            binary = (ROOT / "build" / (name + ".prg")).read_bytes()
            load_address = int.from_bytes(binary[:2], "little")
            binary = binary[2:]
        self.memory[load_address:load_address + len(binary)] = binary
        self.cpu = MPU(memory=self.memory)
        self.state = bytearray(65536)
        self.events = deque()
        self.text = []
        self.hooks = {}
        self.hook("p8b_state_data:p8s_read", self.read)
        self.hook("p8b_state_data:p8s_write", self.write)
        self.hook("p8b_state_data:p8s_save", lambda: None)
        self.hook("p8b_input:p8s_poll", self.poll)
        self.hook("p8b_input:p8s_left_pressed", self.click)
        for primitive in ("rect", "fillrect"):
            self.hook("p8b_gfx_lores:p8s_" + primitive, lambda: None)
        self.hook("p8b_gfx_lores:p8s_text", self.draw_text)

    def hook(self, name, action):
        if name in self.labels:
            self.hooks[self.labels[name]] = action

    def address(self, name):
        return self.labels[name]

    def value(self, name, word=False):
        address = self.address(name)
        return self.memory[address] + (self.memory[address + 1] * 256 if word else 0)

    def set(self, name, value):
        self.memory[self.address(name)] = value & 255

    def read(self):
        self.cpu.a = self.state[self.cpu.a + self.cpu.y * 256]
        # Native VPEEK returns with the loaded byte's N/Z flags.
        self.cpu.p = (self.cpu.p & ~0x82) | (0x02 if self.cpu.a == 0 else 0) | (self.cpu.a & 0x80)

    def write(self):
        address = self.value("p8b_state_data:p8s_write:p8v_address", True)
        self.state[address] = self.value("p8b_state_data:p8s_write:p8v_value")

    def poll(self):
        assert self.events, "Dialog exhausted scripted input (possible hang)"
        event = self.events.popleft()
        key, buttons, x, y, wheel = (event, 0, 0, 0, 0) if isinstance(event, int) else event
        self.set("p8b_input:p8v_previous_buttons", self.value("p8b_input:p8v_buttons"))
        for field, value in (("key", key), ("buttons", buttons), ("wheel", wheel)):
            self.set("p8b_input:p8v_" + field, value)
        for field, value in (("mouse_x", x), ("mouse_y", y)):
            address = self.address("p8b_input:p8v_" + field)
            self.memory[address:address + 2] = [value & 255, value >> 8]

    def click(self):
        self.cpu.a = int(self.value("p8b_input:p8v_buttons") & 1 != 0 and
                         self.value("p8b_input:p8v_previous_buttons") & 1 == 0)

    def draw_text(self):
        base = "p8b_gfx_lores:p8s_text:p8v_"
        x, y = self.value(base + "xx", True), self.value(base + "yy", True)
        pointer = self.value(base + "textptr", True)
        text = []
        while self.memory[pointer]:
            text.append(self.memory[pointer])
            pointer += 1
            assert len(text) < 128, "Unterminated display string"
        assert x + len(text) * 8 <= 320, (x, y, bytes(text))
        assert y + 8 <= 240
        self.text.append((x, y, bytes(text)))

    def run(self, target, events=()):
        self.events = deque(events)
        self.cpu.sp = 255
        self.cpu.stPushWord(0x1fff)
        self.cpu.pc = self.address(target) if isinstance(target, str) else target
        for _ in range(2_000_000):
            if self.cpu.pc == 0x2000:
                return self.cpu.a
            if self.cpu.pc == 0xff6e:
                arguments = self.cpu.stPopWord() + 1
                target = self.memory[arguments] + 256 * self.memory[arguments + 1]
                bank = self.memory[arguments + 2]
                assert (bank, target) == (10, 0xa006), "Unexpected bank call"
                # Disk persistence itself is outside this in-memory test.
                self.cpu.pc = arguments + 3
                continue
            if self.cpu.pc in self.hooks:
                self.hooks[self.cpu.pc]()
                self.cpu.pc = self.cpu.stPopWord() + 1
            elif self.memory[self.cpu.pc] == 0xcb:  # WAI / waitvsync
                self.cpu.pc += 1
            else:
                self.cpu.step()
        raise AssertionError("Instruction limit reached")


def main():
    h = Harness("organizer_extras_overlay")
    entries = ("open_note_reader", "edit_long_email", "migrate_directory_records",
               "show_contact", "show_contact_preview", "show_edit_body")
    for index, entry in enumerate(entries, 1):
        address = 0xa000 + index * 3
        assert h.memory[address] == 0x4c
        assert h.memory[address + 1] + 256 * h.memory[address + 2] == h.address(
            "p8b_organizer_extras:p8s_" + entry)
    # Validate the caller declarations too: the original regression compiled
    # successfully because extsub addresses are not checked by the linker.
    expected = {"initialize_organizer": 0xa000, "open_note_reader": 0xa003,
                "edit_long_email": 0xa006, "migrate_directory_records": 0xa009,
                "show_contact": 0xa00c, "show_contact_preview": 0xa00f,
                "show_edit_body": 0xa012}
    for source in ("desktop.p8", "notes_app.p8", "rolodex_app.p8"):
        for address, name in re.findall(
                r"extsub @bank 20 \$([0-9a-f]+) = (\w+)",
                (ROOT / "src" / source).read_text()):
            assert int(address, 16) == expected[name], (source, name, address)
    h.run(0xa000)
    emoji = Harness("comms_emoji_overlay")
    password_entry = emoji.memory[0xa013] + 256 * emoji.memory[0xa014]
    assert password_entry == emoji.address("p8b_comms_emoji:p8s_secret_dialog")
    assert "extsub @bank 17 $a012 = chat_secret_dialog()" in (
        ROOT / "src/comms_app.p8").read_text()

    # Migration must preserve all fields, flags, old records, and neighboring data.
    h.state[:] = bytes([0x55]) * 65536
    for contact in range(4):
        for offset, length in ((0, 16), (17, 16), (34, 16), (51, 19), (71, 16)):
            start = 0x6388 + contact * 88 + offset
            h.state[start:start + length + 1] = bytes([65 + contact]) * length + b"\0"
    before = bytes(h.state)
    h.run(0xa009)
    assert h.state[:0x6b00] == before[:0x6b00]
    assert h.state[0x6cd0:] == before[0x6cd0:]
    for contact in range(4):
        for old, new, length in ((0, 0, 16), (17, 17, 16), (34, 34, 16),
                                 (51, 51, 19), (71, 99, 16)):
            assert h.state[0x6b00 + contact * 116 + new:
                           0x6b00 + contact * 116 + new + length + 1] == (
                               bytes([65 + contact]) * length + b"\0")

    # Reader Enter defaults to Done; Tab+Enter explicitly chooses Edit.
    h.state[:] = bytes(65536)
    h.memory[0x770] = 1
    h.state[0x6017:0x601c] = b"TEST\0"
    h.state[0x6801:0x680f] = b"ONE\rTWO\rTHREE\0"
    before = bytes(h.state)
    assert h.run(0xa003, [0, 13, 0]) == 0
    assert h.run(0xa003, [0, 9, 13, 0]) == 1
    assert h.run(0xa003, [0, (0, 1, 85, 164, 0), 0]) == 1
    assert h.run(0xa003, [0, (0, 1, 205, 164, 0), 0]) == 0
    assert bytes(h.state) == before
    # 108 newlines must not overflow the 109-entry row index.
    h.state[0x6801:0x686e] = b"\r" * 108 + b"\0"
    h.run(0xa003, [0, 17, 17, 27, 0])
    assert h.value("p8b_organizer_extras:p8v_row_count") == 109

    # Maximum email, rejected 48th byte, cancel, cursor editing and full view.
    h.memory[0x770] = 0
    h.memory[0x771] = 1
    email = b"a" * 35 + b"@example.com"
    assert len(email) == 47
    assert h.run(0xa006, [0, *email, ord("X"), 13, 0]) == 1
    assert h.state[0x6b33:0x6b63] == email + b"\0"
    h.memory[0x771] = 0
    before = bytes(h.state)
    assert h.run(0xa006, [0, 20, 27, 0]) == 0
    assert bytes(h.state) == before
    assert h.run(0xa006, [0, 0x9d, 20, ord("Z"), 13, 0]) == 1
    assert h.state[0x6b33:0x6b63] == email[:-2] + b"Zm\0"
    h.run(0xa00c, [0, 13, 0])
    h.run(0xa00f)

    # Run the real Directory flag copier, which must not access bank-10 RAM.
    d = Harness("rolodex_overlay")
    d.run(0xa000)
    flags = bytes([1, 0, 1, 0])
    start = d.address("p8b_rolodex_app:p8v_contact_active")
    d.memory[start:start + 4] = flags
    d.run("p8b_rolodex_app:p8s_save_state")
    assert d.state[0x630d:0x6311] == flags
    d.memory[start:start + 4] = [0] * 4
    d.run("p8b_rolodex_app:p8s_restore_active")
    assert bytes(d.memory[start:start + 4]) == flags
    # Cancel restores the entire expanded card, including email and social.
    record = 0x6b00 + 2 * 116
    original = bytes(range(116))
    d.state[record:record + 116] = original
    d.cpu.a = 2
    d.run("p8b_rolodex_app:p8s_backup_record")
    d.state[record:record + 116] = bytes(116)
    d.cpu.a = 2
    d.run("p8b_rolodex_app:p8s_restore_record")
    assert d.state[record:record + 116] == original
    print("PASS: compiled entry points, migration bounds, read-only reader, scrolling,")
    print("47-character email edit/cancel/display, and contact flag save/restore")


if __name__ == "__main__":
    main()
