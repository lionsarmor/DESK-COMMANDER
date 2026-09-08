; DESK COMMANDER root-directory shortcut for Commander X16 BASIC.
;
; Install this tokenized BASIC PRG as /DESKCMD.PRG on the SD card. From the
; BASIC prompt, the ROM's DOS wedge can then load and run it with:
;
;     ^DESKCMD.PRG
;
; The first line changes into the application's runtime directory. The second
; line chains into AUTOBOOT.X16, whose BASIC stub starts the Prog8 program.

* = $0801

        .word line_20
        .word 10
        .byte $9f                 ; OPEN
        .text "15,8,15,"
        .byte $22
        .text "CD:/DESKCMD"
        .byte $22, $3a, $a0       ; : CLOSE
        .text "15"
        .byte 0

line_20:
        .word program_end
        .word 20
        .byte $93                 ; LOAD
        .byte $22
        .text "AUTOBOOT.X16"
        .byte $22
        .text ",8,1"
        .byte 0

program_end:
        .word 0
