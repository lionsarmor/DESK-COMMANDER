; Commander X16 AUTOBOOT.X16 loader for DESK COMMANDER.
;
; BOOT loads and runs this small tokenized BASIC program. Its LOAD statement
; then chains into the real Prog8 executable in the same directory. This is
; the same two-stage pattern used by applications in the official X16 SD-card
; collection and avoids launching the large machine-language file directly
; from another graphical application.

* = $0801

        .word program_end
        .word 10
        .byte $93                 ; BASIC LOAD token
        .byte $22
        .text "DCMAIN.PRG"
        .byte $22
        .byte 0

program_end:
        .word 0
