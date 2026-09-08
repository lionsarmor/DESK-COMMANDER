%import app_mailbox
%import diskio
%import input
%import syslib

; -----------------------------------------------------------------------------
; External PRG launcher
; -----------------------------------------------------------------------------
;
; This code starts in bank 14, but an external PRG is allowed to occupy banked
; RAM too. The final KERNAL handoff therefore runs from a tiny copied routine in
; Golden RAM ($06EB), which cannot be overwritten by a normal $0801 PRG load.

program_launcher {
    sub launch() -> bool {
        input.disable_mouse()

        if not run_from_golden_ram() {
            input.enable_mouse()
            return false
        }
        return true
    }

    asmsub run_from_golden_ram() clobbers(X, Y) -> bool @A {
        %asm {{
            ; Copy the position-independent runner below the BASIC program
            ; area. The runner may safely continue after LOAD has replaced
            ; Desk Commander and any portion of bank 14.
            ldx  #runner_end-runner_start-1
copy_runner:
            lda  runner_start,x
            sta  $06eb,x
            dex
            bpl  copy_runner
            jsr  $06eb
            rts

runner_start:
            ; Determine the selected filename length in the fixed mailbox.
            ldx  #0
name_length:
            lda  $0780,x
            beq  have_length
            inx
            cpx  #51
            bcc  name_length
have_length:
            txa
            ldx  #<$0780
            ldy  #>$0780
            jsr  $ffbd             ; SETNAM

            lda  #1
            ldx  #8
            ldy  #1                ; use the PRG's two-byte load address
            jsr  $ffba             ; SETLFS
            lda  #0
            ldx  #0
            ldy  #0
            jsr  $ffd5             ; LOAD
            bcs  load_failed

            ; LOAD returns the byte after the program in X/Y. Publish that end
            ; to BASIC's VARTAB pointer before asking it to RUN. RUN performs
            ; CLR itself and rebuilds the later array/string pointers.
            stx  $03e1            ; BASIC VARTAB (X16, not C64 $2D)
            sty  $03e2

            jsr  $ffe7             ; CLALL
clear_keys:
            jsr  $ffe4             ; GETIN
            cmp  #0
            bne  clear_keys

            ; RUN starts either BASIC or the normal SYS stub. Four bytes fit
            ; comfortably in the X16 keyboard queue.
            ; Use explicit PETSCII bytes here. Prog8's assembly character
            ; literals use the source-file encoding and turn uppercase text
            ; into high-bit screen codes, which BASIC cannot execute.
            lda  #$52             ; R
            jsr  $fec3
            lda  #$55             ; U
            jsr  $fec3
            lda  #$4e             ; N
            jsr  $fec3
            lda  #$0d
            jsr  $fec3

            clc                     ; documented warm BASIC entry
            jmp  $ff47

load_failed:
            lda  #0
            rts
runner_end:
            .cerror runner_end-runner_start > 97, "Golden-RAM runner exceeds reserved space"
            ; !notreached!
        }}
    }
}
