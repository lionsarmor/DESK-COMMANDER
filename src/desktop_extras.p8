%import gfx_lores
%import market_data
%import theme
%import fridge_art

; -----------------------------------------------------------------------------
; Compact desktop Market Watch and Screensaver cards
; -----------------------------------------------------------------------------
;
; These small dashboard drawings live in conventional program RAM. Keeping
; them separate from the full-screen animation leaves bank 18 free for richer
; moving artwork.

desktop_extras {
    ubyte[6] market_symbol
    ubyte[12] market_price
    ubyte[11] market_change

    sub draw_market_watch() {
        ubyte row
        ubyte stock
        ubyte first_stock = market_data.current_page() * 3
        ubyte color

        gfx_lores.eor_mode = false
        gfx_lores.fillrect(53, 153, 163, 55, theme.PAPER)
        gfx_lores.text(58, 156, theme.BLUE, iso:"SYM")
        gfx_lores.text(103, 156, theme.BLUE, iso:"LAST")
        gfx_lores.text(164, 156, theme.BLUE, iso:"MOVE")
        draw_market_refresh_button(false)

        if market_data.count() == 0 {
            gfx_lores.text(60, 180, theme.INK, iso:"OPEN TO ADD STOCKS")
            return
        }

        for row in 0 to 2 {
            stock = first_stock + row
            if stock < market_data.count() {
                market_data.copy_symbol(stock, market_symbol)
                market_data.copy_price(stock, market_price)
                market_data.copy_change(stock, market_change)
                color = theme.SOFT_BLUE
                if market_data.state(stock) == market_data.STATE_FRESH {
                    color = theme.GREEN
                    if market_change[0] == '-'
                        color = theme.RED
                }
                gfx_lores.text(58, 168 + row * 13, theme.INK, market_symbol)
                gfx_lores.text(101, 168 + row * 13, theme.INK, market_price)
                gfx_lores.text(164, 168 + row * 13, color, market_change)
            }
        }
    }

    sub draw_market_refresh_button(bool busy) {
        ubyte face = theme.GOLD
        if busy
            face = theme.RED

        gfx_lores.fillrect(195, 141, 18, 11, face)
        gfx_lores.rect(195, 141, 18, 11, theme.INK)
        gfx_lores.line(200, 144, 205, 143, theme.INK)
        gfx_lores.line(205, 143, 209, 146, theme.INK)
        gfx_lores.line(209, 146, 207, 149, theme.INK)
        gfx_lores.line(207, 149, 201, 149, theme.INK)
        gfx_lores.fillrect(198, 143, 3, 3, theme.INK)
        gfx_lores.fillrect(207, 147, 3, 3, theme.INK)
    }

    sub draw_launcher(bool active) {
        ubyte heading = theme.BLUE
        if active
            heading = theme.RED

        gfx_lores.fillrect(223, 141, 86, 70, theme.INK)
        gfx_lores.fillrect(221, 139, 86, 70, theme.PAPER)
        gfx_lores.rect(221, 139, 86, 70, theme.INK)
        gfx_lores.fillrect(222, 140, 84, 13, heading)
        gfx_lores.text(241, 142, theme.PAPER, iso:"SAVER")
        gfx_lores.fillrect(225, 156, 78, 48, 0)
        gfx_lores.fillrect(232, 162, 2, 2, theme.PAPER)
        gfx_lores.fillrect(247, 169, 1, 1, theme.GOLD)
        gfx_lores.fillrect(286, 162, 2, 2, theme.SOFT_BLUE)
        gfx_lores.fillrect(294, 181, 1, 1, theme.PAPER)

        ; Preview the exact same chrome refrigerator used by the saver.
        ubyte index
        for index in 0 to len(fridge_art.rectangles) - 1 step 5 {
            gfx_lores.fillrect(258 + fridge_art.rectangles[index] as uword,
                160 + fridge_art.rectangles[index + 1],
                fridge_art.rectangles[index + 2], fridge_art.rectangles[index + 3],
                fridge_art.rectangles[index + 4])
        }
    }
}
