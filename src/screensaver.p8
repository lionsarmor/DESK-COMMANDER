%import gfx_lores
%import input
%import syslib
%import theme
%import fridge_art

; Deep Space: parallax stars and a shiny, quietly drifting refrigerator.
; Sprite 1 owns the fridge. Moving its coordinates never erases the artwork
; or punches holes in the stars. VRAM $19000-$197FF is separate from the
; cursor ($13000), editor ($14000), saved state ($16000) and Comms ($17000).
screensaver {
    const ubyte STAR_COUNT = 44
    uword[STAR_COUNT] star_x
    ubyte[STAR_COUNT] star_y
    ubyte[STAR_COUNT] star_speed
    ubyte frame
    ubyte drift_frame
    uword fridge_x
    ubyte fridge_y
    bool moving_right
    bool moving_down

    sub prepare_fridge() {
        cx16.vpoke(1, $fc0e, 0)     ; hide sprite 1 during upload
        uword address
        for address in $9000 to $97ff
            cx16.vpoke(1, address, 0)
        ubyte index
        for index in 0 to len(fridge_art.rectangles) - 1 step 5 {
            ubyte y
            ubyte x
            for y in 0 to fridge_art.rectangles[index + 3] - 1 {
                for x in 0 to fridge_art.rectangles[index + 2] - 1 {
                    address = $9000 +
                        (fridge_art.rectangles[index + 1] as uword + y) * 32 +
                        fridge_art.rectangles[index] + x
                    cx16.vpoke(1, address, fridge_art.rectangles[index + 4])
                }
            }
        }
        ; $19000 / 32 = $0C80. 8bpp sprite, 32 wide by 64 high.
        cx16.vpoke(1, $fc08, $80)
        cx16.vpoke(1, $fc09, $8c)
        cx16.vpoke(1, $fc0f, $e0)
        position_fridge()
        cx16.vpoke(1, $fc0e, $0c)
    }

    sub position_fridge() {
        cx16.vpoke(1, $fc0a, lsb(fridge_x))
        cx16.vpoke(1, $fc0b, msb(fridge_x))
        cx16.vpoke(1, $fc0c, fridge_y)
        cx16.vpoke(1, $fc0d, 0)
    }

    sub initialize_stars() {
        ubyte index
        for index in 0 to STAR_COUNT - 1 {
            star_x[index] = ((index as uword) * 67 + 19) % 320
            star_y[index] = lsb(((index as uword) * 43 + 31) % 232) + 4
            star_speed[index] = index % 3 + 1
        }
        frame = 0
        drift_frame = 0
        fridge_x = 242
        fridge_y = 83
        moving_right = true
        moving_down = true
    }

    sub draw_star(ubyte index, ubyte color) {
        gfx_lores.fillrect(star_x[index], star_y[index], star_speed[index], 1, color)
        if star_speed[index] == 3
            gfx_lores.fillrect(star_x[index] + 1, star_y[index] - 1, 1, 3, color)
    }

    sub star_color(ubyte index) -> ubyte {
        when star_speed[index] {
            1 -> return theme.SOFT_BLUE
            2 -> return theme.PAPER
            else -> return theme.GOLD
        }
    }

    sub move_fridge() {
        if moving_right {
            fridge_x++
            if fridge_x >= 266
                moving_right = false
        } else {
            fridge_x--
            if fridge_x <= 218
                moving_right = true
        }
        if moving_down {
            fridge_y++
            if fridge_y >= 108
                moving_down = false
        } else {
            fridge_y--
            if fridge_y <= 66
                moving_down = true
        }
        position_fridge()
    }

    sub animate_stars() {
        ubyte index
        for index in 0 to STAR_COUNT - 1 {
            draw_star(index, 0)
            if star_x[index] <= star_speed[index] {
                star_x[index] = 316
                ; Wrap before adding, avoiding 8-bit overflow to y=0 and
                ; a cross-shaped star drawing above the framebuffer.
                if star_y[index] >= 189
                    star_y[index] -= 185
                else
                    star_y[index] += 47
            } else
                star_x[index] -= star_speed[index]
            draw_star(index, star_color(index))
        }
    }

    sub open() {
        gfx_lores.eor_mode = false
        initialize_stars()
        input.enable_mouse()
        cx16.vpoke_mask(1, $fc06, $f3, 0)
        gfx_lores.clear_screen(0)
        prepare_fridge()
        ubyte index
        for index in 0 to STAR_COUNT - 1
            draw_star(index, star_color(index))

        bool finished = false
        bool mouse_exit_armed = input.buttons == 0
        do {
            sys.waitvsync()
            input.poll()
            if input.key != 0
                finished = true
            if mouse_exit_armed {
                if input.buttons != 0
                    finished = true
            } else if input.buttons == 0
                mouse_exit_armed = true

            frame++
            if frame == 2 {
                frame = 0
                animate_stars()
            }
            drift_frame++
            if drift_frame == 8 {
                drift_frame = 0
                move_fridge()
            }
        } until finished

        cx16.vpoke(1, $fc0e, 0)     ; never leave a fridge over another app
        input.key = 0
    }
}
