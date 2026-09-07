%import gfx_lores
%import input
%import market_data
%import strings
%import syslib
%import theme

; -----------------------------------------------------------------------------
; DESK COMMANDER Market Watch
; -----------------------------------------------------------------------------
;
; The watchlist is useful offline and caches the most recent quote in VERA RAM.
; Stocks use Finnhub's compact quote endpoint. Gold, silver, and Bitcoin use
; Gold API's public current-price endpoint and require no key. The optional
; Finnhub key is masked in the UI and saved with app state.

market_app {
    const ubyte VISIBLE_ROWS = 7

    ; Bank 9 owns HTTPS/UART work so this interface stays comfortably inside
    ; bank 8. The desktop loads both halves before opening Market Watch.
    extsub @bank 9 $a000 = initialize_market_fetch() clobbers(A, X, Y)
    extsub @bank 9 $a006 = refresh_market_group() clobbers(A, X, Y)

    ubyte selected
    ubyte scroll_offset
    ubyte[6] symbol
    ubyte[49] api_key
    ubyte[36] line_buffer
    ubyte[36] status_text

    sub draw_button(uword x, ubyte width, str label) {
        gfx_lores.fillrect(x + 1, 218, width, 17, theme.INK)
        gfx_lores.fillrect(x, 216, width, 17, theme.PAPER)
        gfx_lores.rect(x, 216, width, 17, theme.BLUE)
        gfx_lores.text(x + 4, 221, theme.INK, label)
    }

    sub copy_status(str message) {
        ubyte index = 0
        while message[index] != 0 and index < 34 {
            status_text[index] = message[index]
            index++
        }
        status_text[index] = 0
    }

    sub draw_status() {
        gfx_lores.fillrect(11, 195, 298, 15, theme.NAVY)
        gfx_lores.text(16, 199, theme.PAPER, status_text)
    }

    sub draw_rows() {
        ubyte row
        ubyte stock
        ubyte y
        ubyte face
        ubyte ink

        ; Start below the column labels. The previous y=52 clear rectangle
        ; erased their lower pixels and made the first stock look corrupted.
        gfx_lores.fillrect(10, 60, 300, 130, theme.PAPER)
        if market_data.count() == 0 {
            gfx_lores.text(24, 76, theme.BLUE, iso:"YOUR WATCHLIST IS EMPTY")
            gfx_lores.text(24, 94, theme.INK, iso:"CHOOSE ADD TO ENTER A SYMBOL")
            return
        }

        for row in 0 to VISIBLE_ROWS - 1 {
            stock = scroll_offset + row
            y = 64 + row * 18
            if stock < market_data.count() {
                face = theme.PAPER
                ink = theme.INK
                if stock == selected {
                    face = theme.SOFT_BLUE
                    ink = theme.NAVY
                }
                gfx_lores.fillrect(16, y, 288, 16, face)
                market_data.copy_symbol(stock, line_buffer)
                gfx_lores.text(22, y + 4, ink, line_buffer)
                market_data.copy_price(stock, line_buffer)
                gfx_lores.text(112, y + 4, ink, line_buffer)
                market_data.copy_change(stock, line_buffer)
                if market_data.state(stock) == market_data.STATE_FRESH {
                    if line_buffer[0] == '-'
                        gfx_lores.text(218, y + 4, theme.RED, line_buffer)
                    else
                        gfx_lores.text(218, y + 4, theme.GREEN, line_buffer)
                } else if stock == selected
                    gfx_lores.text(218, y + 4, theme.NAVY, line_buffer)
                else
                    gfx_lores.text(218, y + 4, theme.SOFT_BLUE, line_buffer)
            }
        }
    }

    sub draw_window() {
        gfx_lores.fillrect(0, 18, 320, 222, theme.PAPER)
        gfx_lores.fillrect(0, 18, 320, 27, theme.BLUE)
        gfx_lores.text(8, 25, theme.PAPER, iso:"MARKET WATCH // USD")
        gfx_lores.disc(300, 31, 4, theme.GREEN)
        gfx_lores.text(22, 47, theme.BLUE, iso:"ASSET")
        gfx_lores.text(112, 47, theme.BLUE, iso:"USD PRICE")
        gfx_lores.text(218, 47, theme.BLUE, iso:"MOVE")
        draw_rows()
        draw_status()
        draw_button(5, 41, iso:"ADD")
        draw_button(50, 55, iso:"REMOVE")
        draw_button(109, 66, iso:"REFRESH")
        ; Short labels stay comfortably inside their physical X16 hit boxes.
        draw_button(179, 72, iso:"KEY")
        draw_button(255, 58, iso:"DONE")
    }

    sub valid_symbol_key(ubyte key) -> bool {
        return (key >= $41 and key <= $5a) or
               (key >= $c1 and key <= $da) or
               (key >= '0' and key <= '9') or key == '.' or key == '-'
    }

    sub draw_entry_field(str value, bool hidden) {
        ubyte length = strings.length(value)
        ubyte visible_length = length
        ubyte index

        ; Match Network Setup exactly: a three-pixel dark frame, a calm paper
        ; field, and text centered vertically inside its seventeen-pixel face.
        gfx_lores.fillrect(44, 111, 232, 23, theme.INK)
        gfx_lores.fillrect(47, 114, 226, 17, theme.PAPER)
        if hidden {
            ; Long API keys remain fully stored, but only the number of mask
            ; glyphs that fit the field are rendered.
            if visible_length > 27
                visible_length = 27
            if visible_length > 0 {
                for index in 0 to visible_length - 1
                    line_buffer[index] = '*'
            }
            line_buffer[visible_length] = 0
            gfx_lores.text(52, 118, theme.INK, line_buffer)
        } else
            gfx_lores.text(52, 118, theme.INK, value)
    }

    sub ask_text(str title, str value, ubyte maximum, bool hidden,
                 bool symbol_only) -> bool {
        bool accepted = false
        bool done = false
        ubyte length
        bool redraw_field = true

        value[0] = 0
        gfx_lores.fillrect(35, 72, 250, 104, theme.INK)
        gfx_lores.fillrect(32, 69, 250, 104, theme.PAPER)
        gfx_lores.rect(32, 69, 250, 104, theme.INK)
        gfx_lores.fillrect(33, 70, 248, 18, theme.BLUE)
        gfx_lores.text(42, 75, theme.PAPER, title)
        gfx_lores.text(55, 148, theme.BLUE, iso:"ENTER OK   ESC CANCEL")

        do {
            ; Repaint only after edits so hardware never exposes a half-drawn
            ; field on every frame.
            if redraw_field {
                draw_entry_field(value, hidden)
                redraw_field = false
            }

            sys.waitvsync()
            input.poll()
            length = strings.length(value)
            if input.key == $14 {
                if length > 0 {
                    value[length - 1] = 0
                    redraw_field = true
                }
            } else if length < maximum and
                      ((symbol_only and valid_symbol_key(input.key)) or
                       (not symbol_only and
                        ((input.key >= 32 and input.key <= 126) or
                         (input.key >= $c1 and input.key <= $da)))) {
                ubyte character = input.key
                ; Convert GETIN's PETSCII letter ranges into ISO. Symbols are
                ; always uppercase. In API keys, ordinary letters are lower
                ; case and Shift produces upper case, preserving key case.
                if symbol_only {
                    if character >= $c1 and character <= $da
                        character -= $80
                } else {
                    if character >= $c1 and character <= $da
                        character -= $80
                    else if character >= $41 and character <= $5a
                        character += 32
                }
                value[length] = character
                value[length + 1] = 0
                redraw_field = true
            } else if input.key == $0d and length > 0 {
                accepted = true
                done = true
            }
        } until done or input.key == $1b

        input.key = 0
        return accepted
    }

    sub add_symbol() {
        if not ask_text(iso:"ADD STOCK SYMBOL", symbol, 5, false, true)
            return
        if market_data.contains(symbol) {
            copy_status(iso:"THAT SYMBOL IS ALREADY LISTED")
            return
        }
        if market_data.add(symbol)
            copy_status(iso:"SYMBOL ADDED - UPDATE FOR A QUOTE")
        else
            copy_status(iso:"WATCHLIST FULL - DELETE ONE FIRST")
    }

    sub set_api_key() {
        if ask_text(iso:"FINNHUB API KEY", api_key, 48, true, false) {
            market_data.set_api_key(api_key)
            copy_status(iso:"API KEY SAVED")
        }
        ; Clear the ordinary-RAM copy. The saved copy remains in the state
        ; image so the user does not have to re-enter it after every boot.
        ubyte index
        for index in 0 to 48
            api_key[index] = 0
    }

    sub refresh_visible() {
        market_data.set_requested_stock((selected / 3) * 3)
        copy_status(iso:"CONTACTING MARKET SERVICES...")
        draw_status()
        refresh_market_group()
        copy_status(iso:"REFRESH COMPLETE - CHECK EACH ROW")
    }

    sub remove_selected() {
        if market_data.count() == 0
            return
        market_data.remove(selected)
        if selected >= market_data.count() and selected > 0
            selected--
        copy_status(iso:"SYMBOL REMOVED")
    }

    sub move_down() {
        if selected + 1 < market_data.count()
            selected++
        if selected >= scroll_offset + VISIBLE_ROWS
            scroll_offset++
    }

    sub move_up() {
        if selected > 0
            selected--
        if selected < scroll_offset
            scroll_offset = selected
    }

    sub open() {
        bool close_window = false

        market_data.initialize()
        initialize_market_fetch()
        selected = 0
        scroll_offset = 0
        copy_status(iso:"XAU XAG BTC: FREE // STOCKS: KEY")
        draw_window()

        ; Consume the click that launched Market Watch so it cannot also hit
        ; the ADD button on the first application frame.
        input.poll()

        do {
            sys.waitvsync()
            input.poll()
            if input.left_pressed() {
                if input.inside(16, 64, 288, 126) and market_data.count() > 0 {
                    ubyte row = ((input.mouse_y - 64) / 18) as ubyte
                    if scroll_offset + row < market_data.count() {
                        selected = scroll_offset + row
                        draw_rows()
                    }
                } else if input.inside(5, 216, 41, 17) {
                    add_symbol()
                    draw_window()
                } else if input.inside(50, 216, 55, 17) {
                    remove_selected()
                    draw_window()
                } else if input.inside(109, 216, 66, 17) {
                    refresh_visible()
                    draw_window()
                } else if input.inside(179, 216, 72, 17) {
                    set_api_key()
                    draw_window()
                } else if input.inside(255, 216, 58, 17)
                    close_window = true
            }

            if input.key == $11 {
                move_down()
                draw_rows()
            } else if input.key == $91 {
                move_up()
                draw_rows()
            } else if input.key == 'A' or input.key == 'a' {
                add_symbol()
                draw_window()
            } else if input.key == 'K' or input.key == 'k' {
                set_api_key()
                draw_window()
            } else if input.key == 'U' or input.key == 'u' {
                refresh_visible()
                draw_window()
            } else if input.key == 'D' or input.key == 'd' {
                remove_selected()
                draw_window()
            }

            if input.wheel > 0 {
                move_up()
                draw_rows()
            } else if input.wheel < 0 {
                move_down()
                draw_rows()
            }
        } until close_window or input.key == $1b

        input.key = 0
    }
}
