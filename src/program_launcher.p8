%import app_mailbox
%import diskio
%import input
%import syslib

; Validate BEFORE discarding the desktop. BASIC then chains LOAD/RUN, just
; like AUTOBOOT.X16. A partial LOAD must never return into overwritten code.
; Leave the selected directory unchanged so programs find their own assets.
program_launcher {
    ubyte[6] header
    ubyte[64] text_chunk

    ; The small editor is for text, not raw overlays/assets or partial files.
    ; Inspect without modifying anything before letting it open the original.
    sub validate_text() -> bool {
        uword total = 0
        uword count
        ubyte index
        bool valid = true
        diskio.drivenumber = 8
        app_mailbox.dos_code = 255
        if not diskio.f_open(app_mailbox.filename)
            return false
        app_mailbox.dos_code = 253
        repeat {
            count = diskio.f_read(&text_chunk, 64)
            if count == 0
                break
            total += count
            if total > 2047 {
                valid = false
                break
            }
            for index in 0 to lsb(count) - 1 {
                if text_chunk[index] < 32 and text_chunk[index] != 9 and
                   text_chunk[index] != 10 and text_chunk[index] != 13 {
                    valid = false
                    break
                }
            }
            if not valid or count < 64
                break
        }
        diskio.f_close()
        return valid
    }

    sub launch() -> bool {
        diskio.drivenumber = 8
        app_mailbox.dos_code = 255
        if not diskio.f_open(app_mailbox.filename)
            return false
        uword count = diskio.f_read(&header, 6)
        diskio.f_close()

        ; Standard X16 applications have a BASIC program / SYS stub at $0801.
        ; Raw machine code needs its own loader and documented entry address.
        app_mailbox.dos_code = 254
        if count != 6 or header[0] != 1 or header[1] != 8 or
           header[3] < 8 or header[3] >= $a0 or
           (header[3] == 8 and header[2] < 6)
            return false

        ; A filename becomes a BASIC string literal. Reject embedded quotes
        ; rather than letting a filename alter the generated LOAD statement.
        ubyte index = 0
        while app_mailbox.filename[index] != 0 {
            if app_mailbox.filename[index] == $22 or
               app_mailbox.filename[index] < 32
                return false
            index++
            if index > 50
                return false
        }

        input.disable_mouse()
        handoff()
        return true
    }

    asmsub handoff() clobbers(A, X, Y) {
        %asm {{
            ; Construct: 10 LOAD "exact selected filename",8
            ; This runs only after returning to BASIC, not on our call stack.
            lda #10
            sta $0803
            stz $0804
            lda #$93                ; BASIC LOAD token
            sta $0805
            lda #$22
            sta $0806
            ldx #0
copy_name:
            lda $0780,x
            beq end_name
            sta $0807,x
            inx
            cpx #50
            bcc copy_name
end_name:
            lda #$22
            sta $0807,x
            lda #$2c
            sta $0808,x
            lda #$38
            sta $0809,x
            stz $080a,x            ; end of line
            stz $080b,x            ; end of BASIC program
            stz $080c,x
            txa
            clc
            adc #$0b
            sta $0801              ; link to final zero word
            lda #8
            sta $0802
            txa
            clc
            adc #$0d
            sta $03e1              ; VARTAB: byte after program
            lda #8
            sta $03e2
            lda #1
            sta $df                ; TXTTAB = $0801 (X16 BASIC)
            lda #8
            sta $e0

            jsr $ffe7              ; CLALL: no app channels survive
            jsr $ff81              ; CINT: normal text screen / font
clear_keys:
            jsr $ffe4
            cmp #0
            bne clear_keys
            lda #$52               ; literal PETSCII RUN, not screen codes
            jsr $fec3
            lda #$55
            jsr $fec3
            lda #$4e
            jsr $fec3
            lda #$0d
            jsr $fec3

            ; Leave banked code before restoring BASIC's normal bank.
            ldx #runner_end-runner_start-1
copy_runner:
            lda runner_start,x
            sta $06eb,x
            dex
            bpl copy_runner
            jmp $06eb
runner_start:
            lda #1
            sta $00
            stz $01
            clc
            jmp $ff47              ; warm BASIC, never returns
runner_end:
            .cerror runner_end-runner_start > 97, "Golden-RAM runner exceeds reserved space"
            ; !notreached!
        }}
    }
}
