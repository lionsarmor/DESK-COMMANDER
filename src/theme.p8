%import palette
%import state_data

; -----------------------------------------------------------------------------
; Shared DESK COMMANDER colors
; -----------------------------------------------------------------------------
;
; VERA uses palette indexes on screen. We reserve a small group beginning at
; index 32 so the application does not need to replace the familiar system
; colors used by the ROM or mouse pointer.

theme {
    const ubyte NAVY = 32
    const ubyte BLUE = 33
    const ubyte PAPER = 34
    const ubyte INK = 35
    const ubyte RED = 36
    const ubyte SOFT_BLUE = 37
    const ubyte GREEN = 38
    const ubyte GOLD = 39
    ; Fixed cursor colors remain recognizable across every theme package.
    const ubyte MOUSE_BLUE = 40
    const ubyte MOUSE_RED = 41
    const ubyte PACKAGE_COUNT = 3

    ubyte current_package

    sub save() {
        state_data.write(state_data.THEME_PACKAGE, current_package)
        state_data.save()
    }

    sub install_palette() {
        when current_package {
            0 -> install_commander_palette()
            1 -> install_amber_palette()
            2 -> install_midnight_palette()
        }
        install_mouse_colors()
    }

    sub next_package() {
        current_package++
        if current_package == PACKAGE_COUNT
            current_package = 0
        install_palette()
        save()
    }

    sub install_commander_palette() {
        ; Colors are twelve-bit RGB values: $RGB, four bits per channel.
        palette.set_color(NAVY, $013)       ; deep Commander blue
        palette.set_color(BLUE, $06a)       ; brighter blue accent
        palette.set_color(PAPER, $fff)      ; warm-neutral white
        palette.set_color(INK, $001)        ; near black
        palette.set_color(RED, $d22)        ; RODDY red
        palette.set_color(SOFT_BLUE, $6bd)  ; pale blue highlight
        palette.set_color(GREEN, $197)      ; personal calendar events
        palette.set_color(GOLD, $ec2)       ; warnings and selected tools
    }

    sub install_amber_palette() {
        ; Warm amber workstation colors with a dark brown foundation.
        palette.set_color(NAVY, $210)
        palette.set_color(BLUE, $b60)
        palette.set_color(PAPER, $fea)
        palette.set_color(INK, $210)
        palette.set_color(RED, $b22)
        palette.set_color(SOFT_BLUE, $fc8)
        palette.set_color(GREEN, $693)
        palette.set_color(GOLD, $fd2)
    }

    sub install_midnight_palette() {
        ; Cooler late-night colors with violet controls and cyan highlights.
        palette.set_color(NAVY, $001)
        palette.set_color(BLUE, $527)
        palette.set_color(PAPER, $def)
        palette.set_color(INK, $112)
        palette.set_color(RED, $e35)
        palette.set_color(SOFT_BLUE, $89d)
        palette.set_color(GREEN, $3b8)
        palette.set_color(GOLD, $fd5)
    }

    sub install_mouse_colors() {
        palette.set_color(MOUSE_BLUE, $18f)
        palette.set_color(MOUSE_RED, $f33)
    }
}
