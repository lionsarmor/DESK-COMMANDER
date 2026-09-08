#!/usr/bin/env python3
"""Exercise the actual launcher in the r49 emulator with disposable HostFS files.

No SD card or user files are touched. Requires make all and the bundled tools.
The fixtures enter bank 14 exactly as Files does, then check BASIC's output.
"""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ASSEMBLER = ROOT / ".tools/bin/64tass"
EMULATOR = ROOT / ".tools/x16emu/x16emu"


def assemble(folder, name, source):
    path = folder / (name + ".asm")
    path.write_text(source)
    subprocess.run([str(ASSEMBLER), "--cbm-prg", "-o", str(folder / name),
                    str(path)], check=True, capture_output=True)


def exercise(folder, name, expected):
    # The overlay is raw; attach an address header for this fixture's LOAD.
    (folder / "LAUNCH.BIN").write_bytes(
        b"\x00\xa0" + (ROOT / "build/program_launcher_overlay.bin").read_bytes())
    assemble(folder, "HARNESS.PRG", f'''
*=$0801
.word basic_end
.word 10
.byte $9e
.text "2061"
.byte 0
basic_end: .word 0
*=$080d
lda #14
sta $00
lda #10
ldx #<overlay
ldy #>overlay
jsr $ffbd
lda #1
ldx #8
ldy #1
jsr $ffba
lda #0
jsr $ffd5
bcs failed
jsr $a000
ldx #0
copy:
lda selected,x
sta $0780,x
inx
cmp #0
bne copy
jsr $a003
failed:
ldx #0
print:
lda failure,x
beq finished
jsr $ffd2
inx
bne print
finished: jmp finished
overlay: .text "LAUNCH.BIN"
selected: .text "{name}"
.byte 0
failure: .text "RETURNED SAFELY"
.byte 13,0
''')
    env = dict(os.environ, SDL_VIDEODRIVER="dummy", SDL_AUDIODRIVER="dummy")
    command = [str(EMULATOR), "-rom", str(ROOT / ".tools/x16emu/rom.bin"),
               "-ram", "512", "-fsroot", str(folder), "-startin", str(folder),
               "-prg", str(folder / "HARNESS.PRG"), "-run", "-echo", "-warp"]
    try:
        result = subprocess.run(command, cwd=folder, env=env, capture_output=True,
                                timeout=5)
        output = result.stdout + result.stderr
    except subprocess.TimeoutExpired as error:
        output = (error.stdout or b"") + (error.stderr or b"")
    assert expected.encode() in output, (name, output.decode(errors="replace"))
    print("PASS:", name, "->", expected)


def main():
    with tempfile.TemporaryDirectory(prefix="desk-launch-test-") as temporary:
        folder = Path(temporary)
        assemble(folder, "BASIC.PRG", '''
*=$0801
.word end
.word 10
.byte $99,$22
.text "BASIC LAUNCH PASSED"
.byte $22,0
end: .word 0
''')
        assemble(folder, "AUTOBOOT.X16", '''
*=$0801
.word end
.word 10
.byte $93,$22
.text "BASIC.PRG"
.byte $22,0
end: .word 0
''')
        assemble(folder, "MACHINE.PRG", '''
*=$0801
.word end
.word 10
.byte $9e
.text "2061"
.byte 0
end: .word 0
*=$080d
ldx #0
loop:
lda message,x
beq done
jsr $ffd2
inx
bne loop
done: rts
message: .text "SYS LAUNCH PASSED"
.byte 13,0
''')
        (folder / "INVALID.PRG").write_bytes(b"not a program")
        exercise(folder, "BASIC.PRG", "BASIC LAUNCH PASSED")
        exercise(folder, "MACHINE.PRG", "SYS LAUNCH PASSED")
        exercise(folder, "AUTOBOOT.X16", "BASIC LAUNCH PASSED")
        exercise(folder, "INVALID.PRG", "RETURNED SAFELY")
        exercise(folder, "MISSING.PRG", "RETURNED SAFELY")


if __name__ == "__main__":
    main()
