%import gfx_lores
%import input
%import syslib
%import theme

; -----------------------------------------------------------------------------
; DESK COMMANDER Deep Space screensaver
; -----------------------------------------------------------------------------
;
; Bank 18 owns only the full-screen animation. Compact desktop card artwork
; lives in desktop_extras so this bank has room for the cartoony fighter.

screensaver {
    const ubyte STAR_COUNT = 44
    const ubyte LASER_COUNT = 3
    const ubyte SPACE_BLACK = 0

    uword[STAR_COUNT] star_x
    ubyte[STAR_COUNT] star_y
    ubyte[STAR_COUNT] star_speed
    uword[LASER_COUNT] laser_x
    ubyte[LASER_COUNT] laser_y
    ubyte frame
    ubyte fighter_y
    uword orb_x
    ubyte orb_y
    bool orb_moving_down

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
        fighter_y = 120
        orb_x = 276
        orb_y = 76
        orb_moving_down = true
        laser_x[0] = 105
        laser_x[1] = 161
        laser_x[2] = 217
        laser_y[0] = fighter_y - 20
        laser_y[1] = fighter_y
        laser_y[2] = fighter_y + 20
    }

    sub draw_star(ubyte index, ubyte color) {
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

    sub erase_chase() {
        ubyte index
        gfx_lores.fillrect(12, fighter_y - 28, 99, 57, SPACE_BLACK)
        gfx_lores.fillrect(orb_x - 14, orb_y - 14, 29, 29, SPACE_BLACK)
        for index in 0 to LASER_COUNT - 1
            gfx_lores.fillrect(laser_x[index], laser_y[index] - 1,
                               13, 4, SPACE_BLACK)
    }

    sub draw_split_wing(uword outer_x, ubyte outer_y,
                        uword inner_x, ubyte inner_y) {
        ; Five black strokes under three white strokes create a crisp comic
        ; outline without needing large sprite artwork in this nearly-full bank.
        gfx_lores.line(outer_x, outer_y - 2, inner_x, inner_y - 2, theme.INK)
        gfx_lores.line(outer_x, outer_y - 1, inner_x, inner_y - 1, theme.INK)
        gfx_lores.line(outer_x, outer_y, inner_x, inner_y, theme.INK)
        gfx_lores.line(outer_x, outer_y + 1, inner_x, inner_y + 1, theme.INK)
        gfx_lores.line(outer_x, outer_y + 2, inner_x, inner_y + 2, theme.INK)
        gfx_lores.line(outer_x, outer_y - 1, inner_x, inner_y - 1, theme.PAPER)
        gfx_lores.line(outer_x, outer_y, inner_x, inner_y, theme.PAPER)
        gfx_lores.line(outer_x, outer_y + 1, inner_x, inner_y + 1, theme.PAPER)
    }

    sub draw_engine(uword x, ubyte y) {
        gfx_lores.disc(x, y, 5, theme.INK)
        gfx_lores.disc(x, y, 3, theme.RED)
        gfx_lores.fillrect(x - 1, y - 1, 3, 3, theme.GOLD)
    }

    sub draw_fighter() {
        ; An original, extra-cartoony salute to the classic split-wing space
        ; fighter: an unmistakable X silhouette without copying a film model.
        draw_split_wing(24, fighter_y - 24, 60, fighter_y - 3)
        draw_split_wing(24, fighter_y + 24, 60, fighter_y + 3)
        draw_split_wing(78, fighter_y - 22, 57, fighter_y - 3)
        draw_split_wing(78, fighter_y + 22, 57, fighter_y + 3)

        ; Four oversized engines make the silhouette readable and playful.
        draw_engine(27, fighter_y - 22)
        draw_engine(27, fighter_y + 22)
        draw_engine(78, fighter_y - 20)
        draw_engine(78, fighter_y + 20)

        ; Black outlined fuselage, tapered nose, exhaust, and red squadron band.
        gfx_lores.fillrect(31, fighter_y - 8, 64, 17, theme.INK)
        gfx_lores.fillrect(93, fighter_y - 5, 9, 11, theme.INK)
        gfx_lores.fillrect(101, fighter_y - 2, 7, 5, theme.INK)
        gfx_lores.fillrect(34, fighter_y - 6, 59, 13, theme.PAPER)
        gfx_lores.fillrect(91, fighter_y - 3, 13, 7, theme.PAPER)
        gfx_lores.fillrect(102, fighter_y - 1, 5, 3, theme.PAPER)
        gfx_lores.fillrect(17, fighter_y - 4, 18, 9, theme.GOLD)
        gfx_lores.fillrect(17, fighter_y - 2, 12, 5, theme.RED)
        gfx_lores.fillrect(43, fighter_y + 3, 45, 3, theme.RED)

        ; Bubble canopy with a bright glass glint.
        gfx_lores.disc(67, fighter_y - 3, 7, theme.INK)
        gfx_lores.disc(67, fighter_y - 3, 5, theme.BLUE)
        gfx_lores.fillrect(64, fighter_y - 6, 3, 2, theme.SOFT_BLUE)

        ; Long black cannons on the two forward wing tips.
        gfx_lores.fillrect(78, fighter_y - 23, 27, 2, theme.INK)
        gfx_lores.fillrect(78, fighter_y + 22, 27, 2, theme.INK)
    }

    sub draw_orb() {
        ; Black rim, green energy, and an offset glint keep the moving target
        ; bold and cartoony instead of looking like another star.
        gfx_lores.disc(orb_x, orb_y, 13, theme.INK)
        gfx_lores.disc(orb_x, orb_y, 10, theme.GREEN)
        gfx_lores.disc(orb_x - 3, orb_y - 3, 5, theme.SOFT_BLUE)
    }

    sub draw_lasers() {
        ubyte index
        for index in 0 to LASER_COUNT - 1 {
            gfx_lores.fillrect(laser_x[index], laser_y[index], 11, 2,
                               theme.RED)
            gfx_lores.fillrect(laser_x[index] + 7, laser_y[index], 5, 1,
                               theme.GOLD)
            gfx_lores.fillrect(laser_x[index] + 10, laser_y[index], 3, 1,
                               theme.PAPER)
        }
    }

    sub draw_space_scene() {
        ubyte index
        gfx_lores.clear_screen(SPACE_BLACK)
        for index in 0 to STAR_COUNT - 1
            draw_star(index, star_color(index))
        draw_fighter()
        draw_orb()
        draw_lasers()
    }

    sub animate_chase() {
        ubyte index

        if orb_x > 218
            orb_x--
        else
            orb_x = 306

        if orb_moving_down {
            orb_y++
            if orb_y >= 190
                orb_moving_down = false
        } else {
            orb_y--
            if orb_y <= 48
                orb_moving_down = true
        }

        ; The ship eases toward the orb instead of teleporting after it.
        if fighter_y + 2 < orb_y
            fighter_y++
        else if fighter_y > orb_y + 2
            fighter_y--

        for index in 0 to LASER_COUNT - 1 {
            laser_x[index] += 6
            if laser_x[index] + 13 >= orb_x {
                laser_x[index] = 102
                laser_y[index] = fighter_y + index * 20 - 20
            }
        }
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
                erase_chase()
                animate_stars()
                animate_chase()
                draw_fighter()
                draw_orb()
                draw_lasers()
            }
        } until finished

        ; Consume the exit key. The desktop also reseeds the physical mouse
        ; state, preventing the click that exits from opening another app.
        input.key = 0
    }
}
