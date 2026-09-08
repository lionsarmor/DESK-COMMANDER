%import gfx_lores
%import input
%import syslib
%import theme

; -----------------------------------------------------------------------------
; DESK COMMANDER Deep Space screensaver
; -----------------------------------------------------------------------------
;
; Bank 18 owns only the full-screen animation. Compact desktop card artwork
; lives in desktop_extras so this bank stays small and easy to maintain.

screensaver {
    const ubyte STAR_COUNT = 44
    const ubyte SPACE_BLACK = 0

    uword[STAR_COUNT] star_x
    ubyte[STAR_COUNT] star_y
    ubyte[STAR_COUNT] star_speed
    ubyte frame
    uword orb_x
    ubyte orb_y

    sub prepare_graphics() {
        ; A loadable library does not run the main PRG's BSS initializer. Always
        ; force ordinary replacement drawing so random bank RAM can never turn
        ; colors into the XOR/inverted palette effect fixed in the emoji bank.
        gfx_lores.eor_mode = false
    }

    sub initialize_stars() {
        ubyte index
        for index in 0 to STAR_COUNT - 1 {
            star_x[index] = ((index as uword) * 67 + 19) % 320
            star_y[index] = lsb(((index as uword) * 43 + 31) % 232) + 4
            star_speed[index] = index % 3 + 1
        }
        frame = 0
        orb_x = 258
        orb_y = 96
    }

    sub star_crosses_orb(ubyte index) -> bool {
        ; Keep the animated star layer away from the orb. The orb is painted
        ; once and never erased, which eliminates visible erase/redraw flashes.
        return star_x[index] >= orb_x - 16 and
               star_x[index] <= orb_x + 16 and
               star_y[index] >= orb_y - 16 and
               star_y[index] <= orb_y + 16
    }

    sub draw_star(ubyte index, ubyte color) {
        if star_crosses_orb(index)
            return
        gfx_lores.fillrect(star_x[index], star_y[index],
                           star_speed[index], 1, color)
        if star_speed[index] == 3
            gfx_lores.fillrect(star_x[index] + 1, star_y[index] - 1,
                               1, 3, color)
    }

    sub star_color(ubyte index) -> ubyte {
        when star_speed[index] {
            1 -> return theme.SOFT_BLUE
            2 -> return theme.PAPER
            else -> return theme.GOLD
        }
    }

    sub draw_orb() {
        ; Black rim, green energy, and an offset glint keep the moving target
        ; bold and cartoony instead of looking like another star.
        gfx_lores.disc(orb_x, orb_y, 13, theme.INK)
        gfx_lores.disc(orb_x, orb_y, 10, theme.GREEN)
        gfx_lores.disc(orb_x - 3, orb_y - 3, 5, theme.SOFT_BLUE)
    }

    sub draw_space_scene() {
        ubyte index
        gfx_lores.clear_screen(SPACE_BLACK)
        for index in 0 to STAR_COUNT - 1
            draw_star(index, star_color(index))
        draw_orb()
    }

    sub animate_stars() {
        ubyte index
        for index in 0 to STAR_COUNT - 1 {
            draw_star(index, SPACE_BLACK)

            if star_x[index] <= star_speed[index] {
                star_x[index] = 316
                star_y[index] += 47
                if star_y[index] > 235
                    star_y[index] -= 232
            } else
                star_x[index] -= star_speed[index]

            draw_star(index, star_color(index))
        }
    }

    sub open() {
        prepare_graphics()
        initialize_stars()

        ; Keep mouse tracking alive for exit clicks, but hide sprite zero while
        ; the saver is active. desktop.show() restores the chosen pointer.
        input.enable_mouse()
        cx16.vpoke_mask(1, $fc06, $f3, 0)
        draw_space_scene()

        bool finished = false
        do {
            sys.waitvsync()
            input.poll()

            if input.key != 0 or input.buttons != 0
                finished = true

            frame++
            if frame == 2 {
                frame = 0
                animate_stars()
            }
        } until finished

        ; Consume the exit key. The desktop also reseeds the physical mouse
        ; state, preventing the click that exits from opening another app.
        input.key = 0
    }
}
