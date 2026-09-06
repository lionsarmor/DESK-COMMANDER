%import syslib
%import preferences
%import state_data
%import theme

; -----------------------------------------------------------------------------
; Keyboard and mouse input state
; -----------------------------------------------------------------------------
;
; The rest of the program should not need to know which KERNAL calls produce
; input. It asks this module for the current state instead. Later we can add
; double-click timing and drag capture here without rewriting every screen.

input {
    const ubyte MOUSE_PRESET_COUNT = 3

    ; Canonical 16x16 pointer planes. Each row uses two bytes, left to right.
    ; MASK says which pixels are visible. FACE separates the colored center
    ; from the black outline. The small cursor uses the upper-left 8x8 portion.
    ubyte[32] pointer_face = [
        $c0,$00, $a0,$00, $90,$00, $88,$00,
        $84,$00, $82,$00, $81,$00, $80,$80,
        $80,$40, $83,$e0, $92,$00, $a9,$00,
        $c9,$00, $84,$80, $04,$80, $03,$80
    ]
    ubyte[32] pointer_mask = [
        $c0,$00, $e0,$00, $f0,$00, $f8,$00,
        $fc,$00, $fe,$00, $ff,$00, $ff,$80,
        $ff,$c0, $ff,$e0, $fe,$00, $ef,$00,
        $cf,$00, $87,$80, $07,$80, $03,$80
    ]
    ubyte[8] pixel_bits = [$80,$40,$20,$10,$08,$04,$02,$01]

    ; A purpose-built 8x8 arrow. Cropping the large pointer produced only a
    ; triangle; these two planes include a proper diagonal stem.
    ubyte[8] small_mask = [$80,$c0,$e0,$f0,$f8,$f8,$f0,$30]
    ubyte[8] small_face = [$00,$00,$40,$60,$70,$40,$20,$00]

    ubyte key
    ubyte buttons
    ubyte previous_buttons
    uword mouse_x
    uword mouse_y
    byte wheel
    ubyte mouse_preset

    sub save_preferences() {
        state_data.write(state_data.MOUSE_PRESET, mouse_preset)
        state_data.save()
    }

    sub enable_mouse() {
        ; Shape 1 is the default Commander X16 pointer. mouse_config2 also reads
        ; the current display dimensions, so call this after changing modes.
        cx16.mouse_config2(1)
        apply_mouse_preset()
        ; Emulator auto-run and the BASIC RUN command can leave a Return in the
        ; keyboard queue. Discard it so it cannot skip the splash screen.
        cbm.kbdbuf_clear()

        ; Seed both button states from the real device. If the emulator or user
        ; is already holding a button while the screen opens, that held button
        ; is not mistaken for a brand-new click.
        buttons, mouse_x, mouse_y, wheel = cx16.mouse_pos()
        previous_buttons = buttons
        key = 0
    }

    sub disable_mouse() {
        cx16.mouse_config2(0)
    }

    sub next_mouse_preset() {
        mouse_preset++
        if mouse_preset == MOUSE_PRESET_COUNT
            mouse_preset = 0
        apply_mouse_preset()
        save_preferences()
    }

    sub apply_mouse_preset() {
        ; Hide sprite 0 while changing it. Mouse tracking stays enabled and
        ; the pointer position does not jump back to the center of the screen.
        cx16.vpoke_mask(1, $fc06, $f3, 0)

        ; The KERNAL cursor is an eight-bit sprite at VRAM $1:3000.
        cx16.vpoke_mask(1, $fc01, $7f, $80)

        ; The compact blue preset really is 8x8. The other two are 16x16.
        ubyte sprite_size = 16
        if mouse_preset == 0 {
            sprite_size = 8
            cx16.vpoke(1, $fc07, $00)
        } else
            cx16.vpoke(1, $fc07, $50)

        ubyte y
        for y in 0 to sprite_size - 1 {
            ubyte x
            for x in 0 to sprite_size - 1 {
                ; Sprite rows are tightly packed. An 8x8 cursor advances by
                ; eight bytes; a 16x16 cursor advances by sixteen.
                uword address = $3000 + (y as uword) * sprite_size + x
                cx16.vpoke(1, address, cursor_pixel(x, y))
            }
        }

        ; Put sprite 0 back in front of both display layers only after every
        ; pixel is ready. This prevents half-written cursor flashes.
        cx16.vpoke_mask(1, $fc06, $f3, $0c)
    }

    sub cursor_pixel(ubyte x, ubyte y) -> ubyte {
        ubyte pixel_bit = pixel_bits[x % 8]
        ubyte mask_byte
        ubyte face_byte

        if mouse_preset == 0 {
            mask_byte = small_mask[y]
            face_byte = small_face[y]
        } else {
            ubyte source_byte = y * 2 + x / 8
            mask_byte = pointer_mask[source_byte]
            face_byte = pointer_face[source_byte]
        }

        if mask_byte & pixel_bit == 0
            return 0

        ; Midnight uses a light outside edge so every pointer remains visible
        ; over the dark theme. The colored face stays blue, red, or black.
        if face_byte & pixel_bit == 0 {
            if theme.current_package == 2
                return theme.PAPER
            return 16
        }
        if mouse_preset == 0
            return theme.MOUSE_BLUE
        if mouse_preset == 2
            return 16
        return theme.MOUSE_RED
    }

    sub poll() {
        previous_buttons = buttons

        ; GETIN returns zero when the keyboard buffer is empty. We ignore its
        ; carry result here and keep the character byte.
        void, key = cbm.GETIN()

        ; mouse_pos returns buttons, X, Y, and wheel movement as four values.
        buttons, mouse_x, mouse_y, wheel = cx16.mouse_pos()
    }

    sub left_pressed() -> bool {
        ; True for one frame when the left button changes from up to down.
        bool pressed = buttons & 1 != 0 and previous_buttons & 1 == 0

        if pressed
            preferences.play_click()
        return pressed
    }

    sub inside(uword x, uword y, uword width, uword height) -> bool {
        return mouse_x >= x and mouse_x < x + width and
               mouse_y >= y and mouse_y < y + height
    }
}
