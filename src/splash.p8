%import gfx_lores
%import appmeta
%import font5x7
%import input
%import theme

; -----------------------------------------------------------------------------
; DESK COMMANDER splash screen
; -----------------------------------------------------------------------------

splash {
    sub show() {
        gfx_lores.graphics_mode()
        gfx_lores.text_charset(1)  ; ISO font: source text appears as expected
        theme.install_palette()
        gfx_lores.clear_screen(theme.NAVY)

        ; A simple top accent gives the screen a little X16 color without
        ; competing with the title.
        gfx_lores.fillrect(0, 0, 320, 5, theme.BLUE)
        gfx_lores.fillrect(0, 5, 320, 1, theme.SOFT_BLUE)

        ; Treat the name as one complete logo instead of two floating lines.
        ; The framed badge, offset type, and red edge accents deliberately nod
        ; to late-eighties productivity software and computer packaging.
        draw_title_logo()

        ; Branding can return here once the final RODDY reference is ready.
        ; For now, keep the splash clean and let the application title lead.
        gfx_lores.text(76, 160, theme.SOFT_BLUE, iso:"FOR THE COMMANDER X16")
        gfx_lores.text(88, 174, theme.PAPER, appmeta.CREATOR)
        gfx_lores.text(80, 186, theme.PAPER, appmeta.COPYRIGHT)
        gfx_lores.text(56, 204, theme.SOFT_BLUE, appmeta.VERSION)
        gfx_lores.text(72, 230, theme.PAPER, iso:"PRESS ANY KEY OR CLICK")

        ; Turn on the pointer only after the graphics mode is configured.
        input.enable_mouse()
    }

    sub draw_title_logo() {
        ; Deep offset shadow: four pixels down and right from the main badge.
        gfx_lores.fillrect(35, 31, 254, 101, theme.INK)

        ; Main blue badge with a crisp double-line frame.
        gfx_lores.fillrect(31, 27, 254, 101, theme.BLUE)
        gfx_lores.rect(31, 27, 254, 101, theme.PAPER)
        gfx_lores.rect(34, 30, 248, 95, theme.NAVY)

        ; Small corner blocks give the frame a piece of hardware character.
        gfx_lores.fillrect(39, 35, 5, 5, theme.RED)
        gfx_lores.fillrect(272, 35, 5, 5, theme.RED)

        ; DESK uses its own compact block lettering. Four-pixel units produce
        ; smaller steps and fuller strokes than enlarging the general 5x7 font.
        draw_desk_wordmark(113, 48, theme.INK)

        ; Offset face passes turn each four-pixel segment into an effective
        ; five-pixel stroke without squeezing the spaces between letters.
        draw_desk_wordmark(108, 43, theme.PAPER)
        draw_desk_wordmark(109, 43, theme.PAPER)
        draw_desk_wordmark(108, 44, theme.PAPER)
        draw_desk_wordmark(109, 44, theme.PAPER)

        ; COMMANDER sits in its own dark nameplate. A red offset pass peeks
        ; from beneath the white face and ties the logo into the UI accent.
        gfx_lores.fillrect(60, 81, 200, 32, theme.INK)
        gfx_lores.rect(60, 81, 200, 32, theme.PAPER)
        font5x7.draw_text(81, 88, 3, theme.RED, iso:"COMMANDER")
        font5x7.draw_text(79, 86, 3, theme.PAPER, iso:"COMMANDER")

        ; Twin rails finish the lockup and keep the large badge from feeling
        ; like an ordinary dialog box.
        gfx_lores.fillrect(45, 118, 83, 3, theme.RED)
        gfx_lores.fillrect(192, 118, 83, 3, theme.RED)
        gfx_lores.fillrect(132, 118, 56, 3, theme.PAPER)
    }

    sub draw_desk_wordmark(uword x, ubyte y, ubyte color) {
        ; D -- solid square spine with the stepped bowl from the reference.
        ; The right edge moves outward through the middle, then steps inward
        ; again before meeting the bottom stroke.
        gfx_lores.fillrect(x, y, 4, 28, color)
        gfx_lores.fillrect(x, y, 16, 4, color)
        gfx_lores.fillrect(x + 16, y + 4, 4, 4, color)
        gfx_lores.fillrect(x + 20, y + 8, 4, 12, color)
        gfx_lores.fillrect(x + 16, y + 20, 4, 4, color)
        gfx_lores.fillrect(x, y + 24, 16, 4, color)

        ; E
        x += 28
        gfx_lores.fillrect(x, y, 4, 28, color)
        gfx_lores.fillrect(x + 4, y, 16, 4, color)
        gfx_lores.fillrect(x + 4, y + 12, 13, 4, color)
        gfx_lores.fillrect(x + 4, y + 24, 16, 4, color)

        ; S
        x += 28
        gfx_lores.fillrect(x, y, 20, 4, color)
        gfx_lores.fillrect(x, y + 4, 4, 12, color)
        gfx_lores.fillrect(x, y + 12, 20, 4, color)
        gfx_lores.fillrect(x + 16, y + 16, 4, 8, color)
        gfx_lores.fillrect(x, y + 24, 20, 4, color)

        ; K -- stepped diagonals echo the supplied reference at X16 resolution.
        x += 28
        gfx_lores.fillrect(x, y, 4, 28, color)
        gfx_lores.fillrect(x + 16, y, 4, 8, color)
        gfx_lores.fillrect(x + 12, y + 8, 4, 4, color)
        gfx_lores.fillrect(x + 8, y + 12, 4, 4, color)
        gfx_lores.fillrect(x + 12, y + 16, 4, 4, color)
        gfx_lores.fillrect(x + 16, y + 20, 4, 8, color)
    }

    sub wait_for_continue() {
        ; Wait for a fresh key or left click. Vsync keeps this loop polite and
        ; gives us the same frame rhythm the future desktop will use.
        do {
            sys.waitvsync()
            input.poll()
        } until input.key != 0 or input.left_pressed()
    }
}
