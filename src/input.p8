%import syslib

; -----------------------------------------------------------------------------
; Keyboard and mouse input state
; -----------------------------------------------------------------------------
;
; The rest of the program should not need to know which KERNAL calls produce
; input. It asks this module for the current state instead. Later we can add
; double-click timing and drag capture here without rewriting every screen.

input {
    ubyte key
    ubyte buttons
    ubyte previous_buttons
    uword mouse_x
    uword mouse_y
    byte wheel

    sub enable_mouse() {
        ; Shape 1 is the default Commander X16 pointer. mouse_config2 also reads
        ; the current display dimensions, so call this after changing modes.
        cx16.mouse_config2(1)
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
        return buttons & 1 != 0 and previous_buttons & 1 == 0
    }

    sub inside(uword x, uword y, uword width, uword height) -> bool {
        return mouse_x >= x and mouse_x < x + width and
               mouse_y >= y and mouse_y < y + height
    }
}
