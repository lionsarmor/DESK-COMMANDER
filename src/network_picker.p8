%import gfx_lores
%import network_mailbox
%import theme

; -----------------------------------------------------------------------------
; Network Setup visual helper (bank 13)
; -----------------------------------------------------------------------------
;
; Bank 7 is nearly full with the UART and ZiModem protocol. This helper owns
; the frequently redrawn SSID panel and the icon toolbar. Selection changes
; therefore repaint one small dirty region instead of flashing the whole app.

network_picker {
    const ubyte VISIBLE_ROWS = 5
    ubyte[33] line_buffer

    sub draw_list() {
        ; This rectangle is the only dirty region while scrolling SSIDs.
        gfx_lores.fillrect(14, 104, 292, 105, theme.NAVY)

        ubyte row
        for row in 0 to VISIBLE_ROWS - 1 {
            ubyte entry = network_mailbox.scroll + row
            ubyte y = 108 + row * 19
            if entry < network_mailbox.count {
                ubyte ink = theme.PAPER
                if entry == network_mailbox.selected {
                    gfx_lores.fillrect(18, y, 278, 18, theme.SOFT_BLUE)
                    ink = theme.NAVY
                }

                ubyte index = 0
                while index < 32 and
                      network_mailbox.character(entry, index) != 0 {
                    line_buffer[index] = network_mailbox.character(entry, index)
                    index++
                }
                line_buffer[index] = 0
                gfx_lores.text(23, y + 5, ink, line_buffer)
            }
        }

        ; A compact track makes it obvious that more than five results exist.
        if network_mailbox.count > VISIBLE_ROWS {
            gfx_lores.rect(300, 108, 5, 95, theme.BLUE)
            gfx_lores.fillrect(301, 110 + network_mailbox.scroll * 12,
                               3, 25, theme.SOFT_BLUE)
        }
    }

    sub button(uword x, ubyte width, ubyte face) {
        ; Every tool uses the same compact raised-button construction. The
        ; two-pixel shadow, bright top edge, and dark lower edge read clearly
        ; on a CRT without wasting precious vertical space.
        gfx_lores.fillrect(x + 2, 217, width, 19, theme.INK)
        gfx_lores.fillrect(x, 214, width, 19, face)
        gfx_lores.rect(x, 214, width, 19, theme.INK)
        gfx_lores.horizontal_line(x + 2, 216, width - 4, theme.PAPER)
        gfx_lores.horizontal_line(x + 2, 230, width - 4, theme.NAVY)
    }

    sub draw_controls() {
        ; Detect: a detailed expansion card with controller, edge contacts,
        ; and a green activity lamp.
        button(4, 50, theme.BLUE)
        gfx_lores.fillrect(14, 218, 28, 10, theme.PAPER)
        gfx_lores.rect(14, 218, 28, 10, theme.INK)
        gfx_lores.fillrect(18, 221, 11, 4, theme.NAVY)
        gfx_lores.rect(18, 221, 11, 4, theme.INK)
        gfx_lores.disc(36, 223, 2, theme.GREEN)
        gfx_lores.fillrect(18, 228, 3, 3, theme.GOLD)
        gfx_lores.fillrect(24, 228, 3, 3, theme.GOLD)
        gfx_lores.fillrect(30, 228, 3, 3, theme.GOLD)
        gfx_lores.fillrect(36, 228, 3, 3, theme.GOLD)

        ; Scan: thick nested radio waves and a bright receiver point.
        button(57, 40, theme.GOLD)
        gfx_lores.line(64, 221, 76, 217, theme.INK)
        gfx_lores.line(76, 217, 89, 221, theme.INK)
        gfx_lores.line(65, 222, 76, 219, theme.PAPER)
        gfx_lores.line(76, 219, 88, 222, theme.PAPER)
        gfx_lores.line(69, 225, 76, 222, theme.INK)
        gfx_lores.line(76, 222, 84, 225, theme.INK)
        gfx_lores.disc(76, 228, 2, theme.GREEN)

        ; Join: a broad arrow docking into a outlined network port.
        button(100, 40, theme.GREEN)
        gfx_lores.fillrect(108, 222, 17, 4, theme.PAPER)
        gfx_lores.line(120, 218, 128, 224, theme.PAPER)
        gfx_lores.line(128, 224, 120, 230, theme.PAPER)
        gfx_lores.rect(130, 218, 5, 12, theme.INK)
        gfx_lores.fillrect(132, 221, 3, 6, theme.SOFT_BLUE)

        ; Status: a tiny live monitor with a green heartbeat trace.
        button(143, 50, theme.SOFT_BLUE)
        gfx_lores.fillrect(154, 217, 28, 11, theme.NAVY)
        gfx_lores.rect(154, 217, 28, 11, theme.INK)
        gfx_lores.line(158, 224, 163, 224, theme.GREEN)
        gfx_lores.line(163, 224, 166, 220, theme.GREEN)
        gfx_lores.line(166, 220, 170, 226, theme.GREEN)
        gfx_lores.line(170, 226, 177, 221, theme.GREEN)
        gfx_lores.fillrect(166, 228, 5, 3, theme.NAVY)

        ; Disconnect: a clean power glyph, instantly recognizable at size.
        button(196, 50, theme.RED)
        gfx_lores.disc(221, 224, 8, theme.PAPER)
        gfx_lores.disc(221, 224, 5, theme.RED)
        gfx_lores.fillrect(217, 215, 9, 8, theme.RED)
        gfx_lores.fillrect(220, 217, 3, 8, theme.PAPER)

        ; Close: double-stroked X with a red underlay for a polished badge.
        button(249, 50, theme.INK)
        gfx_lores.line(266, 218, 282, 230, theme.RED)
        gfx_lores.line(282, 218, 266, 230, theme.RED)
        gfx_lores.line(267, 218, 281, 229, theme.PAPER)
        gfx_lores.line(281, 218, 267, 229, theme.PAPER)
    }
}
