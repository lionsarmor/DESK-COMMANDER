%import comms_data
%import gfx_lores
%import input
%import strings
%import theme

; Five simple face sprites for Desk Comms. Artwork lives in a separate code
; bank so it cannot crowd networking or chat controls; colors still come only
; from the normal shared Comms theme.
comms_emoji {
    const ubyte FACE_GRIN = $47
    const ubyte FACE_WINK = $57
    const ubyte FACE_FROWN = $46
    const ubyte FACE_ANGRY = $41
    ubyte[25] secret_text
    ubyte[25] masked_text

    sub draw_secret_field() {
        ubyte index = 0
        while secret_text[index] != 0 and index < 24 {
            masked_text[index] = '*'
            index++
        }
        masked_text[index] = 0
        gfx_lores.fillrect(61, 111, 198, 24, theme.INK)
        gfx_lores.fillrect(64, 114, 192, 18, theme.PAPER)
        gfx_lores.text(69, 120, theme.INK, masked_text)
    }

    sub secret_dialog() -> bool {
        bool done = false
        bool accepted = false
        secret_text[0] = 0
        prepare_draw()
        gfx_lores.fillrect(47, 77, 226, 95, theme.INK)
        gfx_lores.fillrect(44, 74, 226, 95, theme.PAPER)
        gfx_lores.rect(44, 74, 226, 95, theme.INK)
        gfx_lores.fillrect(45, 75, 224, 22, theme.BLUE)
        gfx_lores.text(52, 82, theme.PAPER, iso:"PASSWORD (8-24 CHARS)")
        draw_secret_field()
        gfx_lores.fillrect(78, 143, 67, 19, theme.BLUE)
        gfx_lores.text(99, 149, theme.PAPER, iso:"OK")
        gfx_lores.fillrect(165, 143, 67, 19, theme.RED)
        gfx_lores.text(181, 149, theme.PAPER, iso:"CANCEL")
        do {
            sys.waitvsync()
            input.poll()
            ubyte length = strings.length(secret_text)
            ubyte typed = input.key
            if typed >= $c1 and typed <= $da
                typed -= $80
            if input.key == $14 and length > 0 {
                secret_text[length - 1] = 0
                draw_secret_field()
            } else if input.key == $0d and length >= 8 {
                accepted = true
                done = true
            } else if typed >= 32 and typed <= 126 and length < 24 {
                secret_text[length] = typed
                secret_text[length + 1] = 0
                draw_secret_field()
            }
            if input.left_pressed() {
                if input.inside(78, 143, 67, 19) and length >= 8 {
                    accepted = true
                    done = true
                } else if input.inside(165, 143, 67, 19)
                    done = true
            }
        } until done or input.key == $1b
        input.key = 0
        if accepted
            comms_data.set_secret(secret_text)
        return accepted
    }

    sub prepare_draw() {
        ; This file is compiled as a banked library, so its BSS is not cleared
        ; by the main program's startup code. gfx_lores.eor_mode therefore held
        ; whatever byte happened to be in bank 17 on real hardware. A non-zero
        ; value makes every requested color XOR with the pixel already onscreen
        ; (yellow became red, black became pale blue, and so on). Always choose
        ; normal replacement drawing before entering this overlay.
        gfx_lores.eor_mode = false
    }

    sub small_face(uword x, ubyte y, ubyte face) {
        ; A simple 11x11 round face: black silhouette, then a yellow/red inset.
        gfx_lores.fillrect(x - 2, y - 5, 5, 1, theme.INK)
        gfx_lores.fillrect(x - 4, y - 4, 9, 1, theme.INK)
        gfx_lores.fillrect(x - 5, y - 3, 11, 7, theme.INK)
        gfx_lores.fillrect(x - 4, y + 4, 9, 1, theme.INK)
        gfx_lores.fillrect(x - 2, y + 5, 5, 1, theme.INK)
        ubyte face_color = theme.GOLD
        if face == FACE_ANGRY face_color = theme.RED
        gfx_lores.fillrect(x - 2, y - 4, 5, 1, face_color)
        gfx_lores.fillrect(x - 3, y - 3, 7, 1, face_color)
        gfx_lores.fillrect(x - 4, y - 2, 9, 5, face_color)
        gfx_lores.fillrect(x - 3, y + 3, 7, 1, face_color)
        gfx_lores.fillrect(x - 2, y + 4, 5, 1, face_color)

        if face == FACE_ANGRY {
            gfx_lores.fillrect(x - 3, y - 2, 1, 1, theme.INK)
            gfx_lores.fillrect(x - 2, y - 1, 1, 1, theme.INK)
            gfx_lores.fillrect(x + 3, y - 2, 1, 1, theme.INK)
            gfx_lores.fillrect(x + 2, y - 1, 1, 1, theme.INK)
        } else if face == FACE_WINK {
            gfx_lores.fillrect(x - 3, y - 1, 3, 1, theme.INK)
            gfx_lores.fillrect(x + 2, y - 1, 1, 1, theme.INK)
        } else {
            gfx_lores.fillrect(x - 2, y - 1, 1, 1, theme.INK)
            gfx_lores.fillrect(x + 2, y - 1, 1, 1, theme.INK)
        }

        if face == FACE_GRIN {
            gfx_lores.fillrect(x - 3, y + 1, 7, 2, theme.INK)
        } else if face == FACE_FROWN or face == FACE_ANGRY {
            gfx_lores.fillrect(x - 1, y + 1, 3, 1, theme.INK)
            gfx_lores.fillrect(x - 2, y + 2, 1, 1, theme.INK)
            gfx_lores.fillrect(x + 2, y + 2, 1, 1, theme.INK)
        } else {
            gfx_lores.fillrect(x - 2, y + 1, 1, 1, theme.INK)
            gfx_lores.fillrect(x + 2, y + 1, 1, 1, theme.INK)
            gfx_lores.fillrect(x - 1, y + 2, 3, 1, theme.INK)
        }
    }

    sub big_face(uword x, ubyte y, ubyte face) {
        ; Exact 2x enlargement of small_face for the picker and compose key.
        gfx_lores.fillrect(x - 4, y - 10, 10, 2, theme.INK)
        gfx_lores.fillrect(x - 8, y - 8, 18, 2, theme.INK)
        gfx_lores.fillrect(x - 10, y - 6, 22, 14, theme.INK)
        gfx_lores.fillrect(x - 8, y + 8, 18, 2, theme.INK)
        gfx_lores.fillrect(x - 4, y + 10, 10, 2, theme.INK)
        ubyte face_color = theme.GOLD
        if face == FACE_ANGRY face_color = theme.RED
        gfx_lores.fillrect(x - 4, y - 8, 10, 2, face_color)
        gfx_lores.fillrect(x - 6, y - 6, 14, 2, face_color)
        gfx_lores.fillrect(x - 8, y - 4, 18, 10, face_color)
        gfx_lores.fillrect(x - 6, y + 6, 14, 2, face_color)
        gfx_lores.fillrect(x - 4, y + 8, 10, 2, face_color)

        if face == FACE_ANGRY {
            gfx_lores.fillrect(x - 6, y - 4, 2, 2, theme.INK)
            gfx_lores.fillrect(x - 4, y - 2, 2, 2, theme.INK)
            gfx_lores.fillrect(x + 6, y - 4, 2, 2, theme.INK)
            gfx_lores.fillrect(x + 4, y - 2, 2, 2, theme.INK)
        } else if face == FACE_WINK {
            gfx_lores.fillrect(x - 6, y - 2, 6, 2, theme.INK)
            gfx_lores.fillrect(x + 4, y - 2, 2, 2, theme.INK)
        } else {
            gfx_lores.fillrect(x - 4, y - 2, 2, 2, theme.INK)
            gfx_lores.fillrect(x + 4, y - 2, 2, 2, theme.INK)
        }

        if face == FACE_GRIN {
            gfx_lores.fillrect(x - 6, y + 2, 14, 4, theme.INK)
        } else if face == FACE_FROWN or face == FACE_ANGRY {
            gfx_lores.fillrect(x - 2, y + 2, 6, 2, theme.INK)
            gfx_lores.fillrect(x - 4, y + 4, 2, 2, theme.INK)
            gfx_lores.fillrect(x + 4, y + 4, 2, 2, theme.INK)
        } else {
            gfx_lores.fillrect(x - 4, y + 2, 2, 2, theme.INK)
            gfx_lores.fillrect(x + 4, y + 2, 2, 2, theme.INK)
            gfx_lores.fillrect(x - 2, y + 4, 6, 2, theme.INK)
        }
    }

    sub draw_small() {
        prepare_draw()
        small_face(comms_data.face_x(), comms_data.face_y(), comms_data.face_kind())
    }

    sub draw_big() {
        prepare_draw()
        big_face(comms_data.face_x(), comms_data.face_y(), comms_data.face_kind())
    }

    sub draw_picker() {
        prepare_draw()
        gfx_lores.fillrect(51, 107, 220, 84, theme.INK)
        gfx_lores.fillrect(47, 103, 220, 84, theme.PAPER)
        gfx_lores.rect(47, 103, 220, 84, theme.INK)
        gfx_lores.fillrect(48, 104, 218, 23, theme.BLUE)
        gfx_lores.text(58, 112, theme.PAPER, iso:"PICK A FACE")
        gfx_lores.fillrect(245, 108, 16, 14, theme.RED)
        gfx_lores.text(250, 112, theme.PAPER, iso:"X")
        ubyte item
        for item in 0 to 4 {
            uword left = 55 + (item as uword) * 42
            gfx_lores.fillrect(left, 136, 38, 42, theme.SOFT_BLUE)
            gfx_lores.rect(left, 136, 38, 42, theme.INK)
        }
        big_face(74, 157, $53)
        big_face(116, 157, FACE_FROWN)
        big_face(158, 157, FACE_WINK)
        big_face(200, 157, FACE_ANGRY)
        big_face(242, 157, FACE_GRIN)
    }

    sub draw_conversation_button() {
        prepare_draw()
        ; Square control containing a square chat-window glyph.
        gfx_lores.fillrect(4, 41, 21, 21, theme.NAVY)
        gfx_lores.rect(4, 41, 21, 21, theme.INK)
        gfx_lores.fillrect(8, 45, 13, 12, theme.PAPER)
        gfx_lores.rect(8, 45, 13, 12, theme.INK)
        gfx_lores.horizontal_line(9, 48, 11, theme.INK)
        gfx_lores.fillrect(10, 51, 4, 1, theme.INK)
        gfx_lores.fillrect(10, 54, 8, 1, theme.INK)
    }

    sub draw_invalid_ip() {
        prepare_draw()
        gfx_lores.fillrect(45, 75, 224, 22, theme.RED)
        gfx_lores.text(52, 82, theme.PAPER, iso:"INVALID IP ADDRESS")
    }
}
