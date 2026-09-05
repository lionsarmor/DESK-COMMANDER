%import palette

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

    sub install_palette() {
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
}
