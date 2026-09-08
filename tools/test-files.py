#!/usr/bin/env python3
"""Compiled 65C02 file routing, text preflight and long-name regression tests.

Requires py65 and make all. Disk reads are stubbed; see test-file-launch.py
for the separate real-ROM/emulator launch test.
"""
from pathlib import Path
import runpy

Harness = runpy.run_path(str(Path(__file__).with_name("test-organizer.py")))["Harness"]


def string_at(h, address):
    end = address
    while h.memory[end]:
        end += 1
    return bytes(h.memory[address:end])


h = Harness("file_manager_overlay")
for filename, expected in (("GAME.PRG", 1), ("game.prg", 1), ("AUTOBOOT.X16", 1),
                           ("autoboot.x16", 1), ("README.TXT", 0),
                           ("ZZFILEMAN.BIN", 0), ("GAME.PRG.BAK", 0), ("x", 0)):
    h.memory[0x780:0x780 + len(filename) + 1] = filename.encode() + b"\0"
    h.cpu.a, h.cpu.y = 0x80, 7
    assert h.run("p8b_file_manager:p8s_filename_is_program") == expected

for contents, expected in ((b"", 1), (b"line\r\nnext\tline", 1),
                           (b"a" * 2047, 1), (b"a" * 2048, 0),
                           (b"a" * 4096, 0), (b"binary\0data", 0),
                           (b"\x01\x08SYS", 0)):
    h = Harness("program_launcher_overlay")
    pending = bytearray(contents)
    def read():
        address = h.value("diskio:f_read:bufferpointer", True)
        count = h.value("diskio:f_read:num_bytes", True)
        chunk = pending[:count]
        del pending[:count]
        h.memory[address:address + len(chunk)] = chunk
        h.cpu.a, h.cpu.y = len(chunk) & 255, len(chunk) >> 8
    h.hook("diskio:f_open", lambda: setattr(h.cpu, "a", 1))
    h.hook("diskio:f_read", read)
    h.hook("diskio:f_close", lambda: None)
    assert h.run("p8b_program_launcher:p8s_validate_text") == expected, len(contents)

# Editing a long existing filename must not silently chop it down to 24 bytes.
h = Harness("file_ops_overlay")
name = b"A" * 46 + b".TXT"
edit = h.address("p8b_file_ops:p8v_edit_text")
h.memory[edit:edit + 51] = name + b"\0"
h.run("p8b_file_ops:p8s_draw_field")
assert string_at(h, edit) == name
assert h.text[-1][2] == name[-24:]

# A full rename command needs 104 bytes, not the disk library's 51-byte scratch.
h.memory[0x780:0x7b3] = name + b"\0"
destination = b"B" * 46 + b".TXT"
h.memory[0x7b3:0x7e6] = destination + b"\0"
commands = []
h.hook("diskio:send_command", lambda: commands.append(
    string_at(h, h.cpu.a + 256 * h.cpu.y)))
h.cpu.a, h.cpu.y = 0xb3, 7
h.run("p8b_file_ops:p8s_rename_command")
assert commands == [b"R:" + destination + b"=" + name]
for prefix in (b"MD:", b"RD:", b"CD:", b"S:"):
    h.memory[0x700:0x700 + len(prefix) + 1] = prefix + b"\0"
    for field, pointer in (("prefix", 0x700), ("name", 0x780)):
        address = h.address("p8b_file_ops:p8s_name_command:p8v_" + field)
        h.memory[address:address + 2] = [pointer & 255, pointer >> 8]
    h.run("p8b_file_ops:p8s_name_command")
    assert commands[-1] == prefix + name

# Overwrite prefix plus 50-byte filename plus terminator requires 53 bytes.
h = Harness("text_editor_overlay")
h.memory[0x780:0x7b3] = name + b"\0"
h.cpu.a, h.cpu.y = 0x80, 7
h.run("p8b_text_editor:p8s_make_save_name")
assert string_at(h, h.address("p8b_text_editor:p8v_name_buffer")) == b"@:" + name
print("PASS: suffix routing, empty/2047-byte text, oversized/binary rejection,")
print("50-character names, bounded DOS commands, and exact overwrite filename")
