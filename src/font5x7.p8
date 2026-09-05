%import gfx_lores
%import strings

; -----------------------------------------------------------------------------
; Tiny scalable 5-by-7 title font
; -----------------------------------------------------------------------------
;
; The X16 ROM font is ideal for ordinary labels. A splash title needs more
; presence, so this deliberately small renderer enlarges five-column letters
; with filled rectangles. It is data-driven and can be reused by future screens.

font5x7 {
    ; Five vertical columns for each uppercase letter A-Z. Bit zero is the top
    ; pixel and bit six is the bottom pixel. Keeping all glyphs in one table is
    ; simpler than twenty-six nearly identical drawing routines.
    ubyte[130] GLYPHS = [
        $7e,$11,$11,$11,$7e,  ; A
        $7f,$49,$49,$49,$36,  ; B
        $3e,$41,$41,$41,$22,  ; C
        $7f,$41,$41,$22,$1c,  ; D
        $7f,$49,$49,$49,$41,  ; E
        $7f,$09,$09,$09,$01,  ; F
        $3e,$41,$49,$49,$7a,  ; G
        $7f,$08,$08,$08,$7f,  ; H
        $00,$41,$7f,$41,$00,  ; I
        $20,$40,$41,$3f,$01,  ; J
        $7f,$08,$14,$22,$41,  ; K
        $7f,$40,$40,$40,$40,  ; L
        $7f,$02,$0c,$02,$7f,  ; M
        $7f,$04,$08,$10,$7f,  ; N
        $3e,$41,$41,$41,$3e,  ; O
        $7f,$09,$09,$09,$06,  ; P
        $3e,$41,$51,$21,$5e,  ; Q
        $7f,$09,$19,$29,$46,  ; R
        $46,$49,$49,$49,$31,  ; S
        $01,$01,$7f,$01,$01,  ; T
        $3f,$40,$40,$40,$3f,  ; U
        $1f,$20,$40,$20,$1f,  ; V
        $3f,$40,$38,$40,$3f,  ; W
        $63,$14,$08,$14,$63,  ; X
        $07,$08,$70,$08,$07,  ; Y
        $61,$51,$49,$45,$43   ; Z
    ]

    sub draw_text(uword x, ubyte y, ubyte scale, ubyte color, str text) {
        ubyte index
        ubyte column
        ubyte row
        ubyte letter
        ubyte column_bits
        ubyte bit_mask
        ubyte glyph_offset

        for index in 0 to strings.length(text)-1 {
            letter = text[index]

            if letter == ' ' {
                ; A space is narrower than a normal glyph.
                x += scale * 4
            } else if letter >= 65 and letter <= 90 {
                ; The title strings use ISO encoding. Uppercase A-Z are byte
                ; values 65-90 in ISO, while an unqualified Prog8 character
                ; literal would use PETSCII. Numeric bounds make that explicit.
                glyph_offset = (letter - 65) * 5

                for column in 0 to 4 {
                    column_bits = GLYPHS[glyph_offset + column]
                    bit_mask = 1

                    for row in 0 to 6 {
                        if column_bits & bit_mask != 0 {
                            gfx_lores.fillrect(
                                x + column * scale,
                                y + row * scale,
                                scale,
                                scale,
                                color
                            )
                        }
                        bit_mask <<= 1
                    }
                }

                ; Five columns for the glyph and one blank column after it.
                x += scale * 6
            }
        }
    }
}
