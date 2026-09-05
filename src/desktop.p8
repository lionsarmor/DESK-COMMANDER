%import conv
%import floats
%import gfx_lores
%import font5x7
%import input
%import calendar_app
%import notes_app
%import rolodex_app
%import strings
%import theme

; -----------------------------------------------------------------------------
; DESK COMMANDER organizer dashboard
; -----------------------------------------------------------------------------
;
; The desktop has two clear zones:
;   1. A slim icon rail keeps application launchers close to the left edge.
;   2. Notes and Calendar sit above a wide market-watch glance panel.
;
; Every area already has its own mouse hit box. The applications behind them
; are still stand-ins, but the dashboard can grow without being rearranged.

desktop {
    const uword RAIL_X = 5
    const ubyte RAIL_Y = 30
    const ubyte RAIL_WIDTH = 42
    const ubyte RAIL_HEIGHT = 179

    const uword ICON_X = 9
    const ubyte ICON_WIDTH = 34
    const ubyte ICON_HEIGHT = 30
    const ubyte FILE_Y = 32
    const ubyte CALCULATOR_Y = 67
    const ubyte ROLODEX_ICON_Y = 102
    const ubyte COMMS_Y = 137
    const ubyte SETTINGS_Y = 172

    const uword NOTES_X = 52
    const ubyte NOTES_WIDTH = 110
    const uword CALENDAR_X = 166
    const ubyte CALENDAR_WIDTH = 148
    const ubyte TOP_Y = 30
    const ubyte TOP_HEIGHT = 105

    const uword MARKET_X = 52
    const ubyte MARKET_Y = 139
    const ubyte MARKET_WIDTH = 255
    const ubyte MARKET_HEIGHT = 70

    const ubyte SECTION_NONE = 0
    const ubyte SECTION_NOTES = 1
    const ubyte SECTION_CALENDAR = 2
    const ubyte SECTION_ROLODEX = 3
    const ubyte SECTION_CALCULATOR = 4
    const ubyte SECTION_FILES = 5
    const ubyte SECTION_COMMS = 6
    const ubyte SECTION_SETTINGS = 7
    const ubyte SECTION_MARKET = 8

    const ubyte ICON_FOLDER = 1
    const ubyte ICON_CALCULATOR = 2
    const ubyte ICON_COMMS = 3
    const ubyte ICON_SETTINGS = 4
    const ubyte ICON_ROLODEX = 5

    ubyte hovered_section
    ubyte last_minute
    ubyte clock_frames
    ubyte[6] clock_text = [48, 48, 58, 48, 48, 0]

    ; Calculator state lives here because the calculator is a modal desktop
    ; accessory. The display string is also the number-entry buffer.
    ubyte[20] calculator_display
    float calculator_left
    ubyte calculator_operator
    bool calculator_start_new
    bool calculator_error

    sub show() {
        gfx_lores.clear_screen(theme.SOFT_BLUE)

        ; The small calendar is a live view of the Calendar app's data.
        calendar_app.initialize()

        draw_desktop_header()
        draw_icon_rail()

        draw_panel(NOTES_X, TOP_Y, NOTES_WIDTH, TOP_HEIGHT, iso:"NOTES", false)
        draw_notes()

        draw_panel(CALENDAR_X, TOP_Y, CALENDAR_WIDTH, TOP_HEIGHT, iso:"CALENDAR", false)
        draw_calendar()

        draw_panel(MARKET_X, MARKET_Y, MARKET_WIDTH, MARKET_HEIGHT,
                   iso:"MARKET WATCH - DEMO", false)
        draw_market_watch()

        draw_status(iso:"YOUR DESK IS READY")

        hovered_section = SECTION_NONE
        last_minute = 255
        clock_frames = 0
        update_clock()

        ; Reconfigure the pointer for this screen and discard any click that
        ; was used to leave the splash screen.
        input.enable_mouse()
    }

    sub draw_desktop_header() {
        ; One honest header replaces the old non-functional menu strip. The
        ; application identity stays on the left and the live RTC on the right.
        gfx_lores.fillrect(0, 0, 320, 27, theme.PAPER)
        gfx_lores.fillrect(0, 26, 320, 1, theme.INK)
        gfx_lores.text(5, 9, theme.INK, iso:"DESK COMMANDER")
        gfx_lores.fillrect(258, 0, 62, 26, theme.NAVY)
    }

    sub update_clock() {
        uword year_month
        uword day_hours
        uword minute_seconds
        uword jiffies_weekday
        ubyte hour
        ubyte minute

        ; The X16 KERNAL returns two clock fields in each communication word.
        ; Hours are in r1H and minutes are in r2L.
        year_month, day_hours, minute_seconds, jiffies_weekday = cx16.clock_get_date_time()
        hour = msb(day_hours)
        minute = lsb(minute_seconds)

        ; Only repaint when the minute changes. This keeps the top bar steady
        ; and avoids needless VERA drawing during the mouse loop.
        if minute == last_minute
            return

        last_minute = minute
        clock_text[0] = hour / 10 + 48
        clock_text[1] = hour % 10 + 48
        clock_text[3] = minute / 10 + 48
        clock_text[4] = minute % 10 + 48

        gfx_lores.fillrect(258, 0, 62, 26, theme.NAVY)
        gfx_lores.text(269, 9, theme.PAPER, clock_text)
    }

    sub draw_panel(uword x, ubyte y, ubyte width, ubyte height, str title, bool active) {
        ; Two-pixel offset shadow makes the section feel like a card on a desk.
        gfx_lores.fillrect(x + 2, y + 2, width, height, theme.INK)
        gfx_lores.fillrect(x, y, width, height, theme.PAPER)
        gfx_lores.rect(x, y, width, height, theme.INK)
        draw_panel_heading(x, y, width, title, active)
    }

    sub draw_panel_heading(uword x, ubyte y, ubyte width, str title, bool active) {
        ubyte heading_color = theme.BLUE
        if active
            heading_color = theme.RED

        gfx_lores.fillrect(x + 1, y + 1, width - 2, 13, heading_color)
        gfx_lores.text(x + 6, y + 3, theme.PAPER, title)
        gfx_lores.fillrect(x + width - 11, y + 5, 5, 5, theme.PAPER)
    }

    sub draw_notes() {
        gfx_lores.text(59, 47, theme.INK, iso:"TODAY")
        draw_note_line(57, iso:"PLAN DESK")
        draw_note_line(72, iso:"ADD MOUSE")
        draw_note_line(87, iso:"QUICK NOTE")

        ; Red insertion mark: this panel will eventually accept direct typing.
        gfx_lores.fillrect(73, 104, 2, 8, theme.RED)
        gfx_lores.horizontal_line(77, 111, 74, theme.SOFT_BLUE)

    }

    sub draw_note_line(ubyte y, str text) {
        gfx_lores.rect(59, y, 8, 8, theme.BLUE)
        gfx_lores.text(73, y, theme.INK, text)
        gfx_lores.horizontal_line(73, y + 10, 78, theme.SOFT_BLUE)
    }

    sub draw_calendar() {
        ubyte day
        ubyte calendar_slot
        ubyte column
        ubyte row
        uword x
        ubyte y
        ubyte event_type

        ; Show whichever month the user last viewed in the full Calendar app.
        calendar_app.draw_month_name(174, 46, theme.INK)
        gfx_lores.text(272, 46, theme.INK,
                       conv.str_uw(calendar_app.current_year))

        gfx_lores.text(174, 57, theme.BLUE, iso:"S")
        gfx_lores.text(193, 57, theme.BLUE, iso:"M")
        gfx_lores.text(212, 57, theme.BLUE, iso:"T")
        gfx_lores.text(231, 57, theme.BLUE, iso:"W")
        gfx_lores.text(250, 57, theme.BLUE, iso:"T")
        gfx_lores.text(269, 57, theme.BLUE, iso:"F")
        gfx_lores.text(288, 57, theme.BLUE, iso:"S")

        ; The compact grid still has room for months that need six rows.
        for day in 1 to calendar_app.days_in_month() {
            calendar_slot = calendar_app.first_weekday + day - 1
            column = calendar_slot % 7
            row = calendar_slot / 7
            ; Cast before multiplying: the Friday/Saturday columns cross X=255
            ; and must use 16-bit math or they wrap onto the icon rail.
            x = 174 + (column as uword) * 19
            y = 67 + row * 9
            event_type = calendar_app.event_type_for_day(day)

            draw_glance_day(x, y, day, event_type)
        }

    }

    sub draw_glance_day(uword x, ubyte y, ubyte day, ubyte event_type) {
        ubyte text_color = theme.INK

        if event_type != calendar_app.EVENT_NONE {
            gfx_lores.fillrect(x - 1, y - 1, 18, 9,
                               calendar_app.color_for_event(event_type))
            text_color = theme.PAPER
        }

        gfx_lores.text(x, y, text_color, conv.str_ub(day))
    }

    sub draw_market_watch() {
        ; These are intentionally labeled demo quotes. A future market-data
        ; service can replace the values without changing this dashboard card.
        gfx_lores.text(60, 156, theme.BLUE, iso:"SYMBOL")
        gfx_lores.text(128, 156, theme.BLUE, iso:"LAST")
        gfx_lores.text(205, 156, theme.BLUE, iso:"CHANGE")

        draw_market_row(168, iso:"AAPL", iso:"229.00", iso:"+1.20%", theme.GREEN)
        draw_market_row(181, iso:"IBM", iso:"252.10", iso:"-0.40%", theme.RED)
        draw_market_row(194, iso:"KO", iso:"68.50", iso:"+0.15%", theme.GREEN)
    }

    sub draw_market_row(ubyte y, str symbol, str price, str change,
                        ubyte change_color) {
        gfx_lores.text(60, y, theme.INK, symbol)
        gfx_lores.text(128, y, theme.INK, price)
        gfx_lores.text(205, y, change_color, change)
    }

    sub draw_icon_rail() {
        ; A dark rail separates application launchers from information cards.
        gfx_lores.fillrect(RAIL_X, RAIL_Y, RAIL_WIDTH, RAIL_HEIGHT, theme.NAVY)
        gfx_lores.fillrect(RAIL_X + RAIL_WIDTH - 2, RAIL_Y, 2, RAIL_HEIGHT, theme.BLUE)

        draw_rail_button(FILE_Y, ICON_FOLDER, false)
        draw_rail_button(CALCULATOR_Y, ICON_CALCULATOR, false)
        draw_rail_button(ROLODEX_ICON_Y, ICON_ROLODEX, false)
        draw_rail_button(COMMS_Y, ICON_COMMS, false)
        draw_rail_button(SETTINGS_Y, ICON_SETTINGS, false)
    }

    sub draw_rail_button(ubyte y, ubyte icon, bool active) {
        ubyte face_color = theme.PAPER
        ubyte icon_color = theme.BLUE

        if active {
            face_color = theme.RED
            icon_color = theme.PAPER
        }

        ; No labels: each small tile is identified by its silhouette.
        gfx_lores.fillrect(ICON_X, y, ICON_WIDTH, ICON_HEIGHT, face_color)
        gfx_lores.rect(ICON_X, y, ICON_WIDTH, ICON_HEIGHT, theme.INK)

        when icon {
            ICON_FOLDER -> draw_folder_icon(y, icon_color, face_color)
            ICON_CALCULATOR -> draw_calculator_icon(y, icon_color, face_color)
            ICON_COMMS -> draw_comms_icon(y, icon_color, face_color)
            ICON_SETTINGS -> draw_settings_icon(y, icon_color, face_color)
            ICON_ROLODEX -> draw_rolodex_icon(y, icon_color, face_color)
        }
    }

    sub draw_folder_icon(ubyte y, ubyte color, ubyte cutout_color) {
        ; Folder tab and body.
        gfx_lores.fillrect(ICON_X + 8, y + 8, 10, 4, color)
        gfx_lores.fillrect(ICON_X + 6, y + 12, 23, 13, color)
        gfx_lores.fillrect(ICON_X + 8, y + 15, 19, 7, cutout_color)
    }

    sub draw_calculator_icon(ubyte y, ubyte color, ubyte cutout_color) {
        ; Display plus a simple two-by-two keypad.
        gfx_lores.fillrect(ICON_X + 8, y + 5, 19, 24, color)
        gfx_lores.fillrect(ICON_X + 11, y + 8, 13, 5, cutout_color)
        gfx_lores.fillrect(ICON_X + 11, y + 17, 4, 4, cutout_color)
        gfx_lores.fillrect(ICON_X + 20, y + 17, 4, 4, cutout_color)
        gfx_lores.fillrect(ICON_X + 11, y + 24, 4, 3, cutout_color)
        gfx_lores.fillrect(ICON_X + 20, y + 24, 4, 3, cutout_color)
    }

    sub draw_comms_icon(ubyte y, ubyte color, ubyte cutout_color) {
        ; A clean comic-style speech balloon with a pointed tail.
        gfx_lores.fillrect(ICON_X + 6, y + 7, 23, 17, color)
        gfx_lores.fillrect(ICON_X + 9, y + 10, 17, 11, cutout_color)
        gfx_lores.fillrect(ICON_X + 8, y + 23, 6, 5, color)
    }

    sub draw_rolodex_icon(ubyte y, ubyte color, ubyte cutout_color) {
        ; A small address card with two binder tabs, a portrait, and lines.
        gfx_lores.fillrect(ICON_X + 7, y + 6, 22, 19, color)
        gfx_lores.fillrect(ICON_X + 10, y + 9, 16, 13, cutout_color)
        gfx_lores.fillrect(ICON_X + 5, y + 9, 4, 4, color)
        gfx_lores.fillrect(ICON_X + 5, y + 18, 4, 4, color)
        gfx_lores.disc(ICON_X + 14, y + 13, 2, color)
        gfx_lores.fillrect(ICON_X + 11, y + 17, 7, 4, color)
        gfx_lores.horizontal_line(ICON_X + 20, y + 11, 5, color)
        gfx_lores.horizontal_line(ICON_X + 20, y + 15, 5, color)
        gfx_lores.horizontal_line(ICON_X + 20, y + 19, 5, color)
    }

    sub draw_settings_icon(ubyte y, ubyte color, ubyte cutout_color) {
        ; Eight separate teeth make this read as a gear instead of a target.
        ; The teeth overlap a round hub, creating one clean silhouette.
        gfx_lores.disc(ICON_X + 17, y + 17, 8, color)

        gfx_lores.fillrect(ICON_X + 15, y + 5, 5, 6, color)   ; north
        gfx_lores.fillrect(ICON_X + 15, y + 24, 5, 6, color)  ; south
        gfx_lores.fillrect(ICON_X + 5, y + 15, 6, 5, color)   ; west
        gfx_lores.fillrect(ICON_X + 24, y + 15, 6, 5, color)  ; east

        gfx_lores.fillrect(ICON_X + 8, y + 8, 6, 6, color)    ; northwest
        gfx_lores.fillrect(ICON_X + 21, y + 8, 6, 6, color)   ; northeast
        gfx_lores.fillrect(ICON_X + 8, y + 21, 6, 6, color)   ; southwest
        gfx_lores.fillrect(ICON_X + 21, y + 21, 6, 6, color)  ; southeast

        ; A generous center opening keeps the gear readable when highlighted.
        gfx_lores.disc(ICON_X + 17, y + 17, 4, cutout_color)
    }

    sub draw_calculator_overlay() {
        ubyte display_length = strings.length(calculator_display)
        uword display_x = 206 - (display_length as uword) * 8

        ; The calculator is a modal desk accessory. The display is deliberately
        ; separate from the keys so every operation is easy to read.
        gfx_lores.fillrect(73, 43, 204, 164, theme.INK)
        gfx_lores.fillrect(70, 40, 204, 164, theme.PAPER)
        gfx_lores.rect(70, 40, 204, 164, theme.INK)

        gfx_lores.fillrect(71, 41, 202, 16, theme.BLUE)
        gfx_lores.text(78, 45, theme.PAPER, iso:"CALCULATOR")
        gfx_lores.fillrect(254, 43, 15, 12, theme.RED)
        gfx_lores.text(258, 45, theme.PAPER, iso:"X")

        ; Number display plus a dedicated Clear key.
        gfx_lores.fillrect(83, 65, 134, 23, theme.INK)
        gfx_lores.fillrect(86, 68, 128, 17, theme.PAPER)
        if calculator_error
            gfx_lores.text(94, 73, theme.RED, calculator_display)
        else
            gfx_lores.text(display_x, 73, theme.INK, calculator_display)
        draw_overlay_key(222, 65, iso:"C")

        ; Four familiar rows establish the future calculator interaction.
        draw_overlay_key(84, 95, iso:"7")
        draw_overlay_key(128, 95, iso:"8")
        draw_overlay_key(172, 95, iso:"9")
        draw_overlay_key(216, 95, iso:"/")

        draw_overlay_key(84, 121, iso:"4")
        draw_overlay_key(128, 121, iso:"5")
        draw_overlay_key(172, 121, iso:"6")
        draw_overlay_key(216, 121, iso:"*")

        draw_overlay_key(84, 147, iso:"1")
        draw_overlay_key(128, 147, iso:"2")
        draw_overlay_key(172, 147, iso:"3")
        draw_overlay_key(216, 147, iso:"-")

        draw_overlay_key(84, 173, iso:"0")
        draw_overlay_key(128, 173, iso:".")
        draw_overlay_key(172, 173, iso:"=")
        draw_overlay_key(216, 173, iso:"+")
    }

    sub draw_overlay_key(uword x, ubyte y, str label) {
        gfx_lores.fillrect(x + 2, y + 2, 36, 21, theme.INK)
        gfx_lores.fillrect(x, y, 36, 21, theme.PAPER)
        gfx_lores.rect(x, y, 36, 21, theme.BLUE)
        gfx_lores.text(x + 14, y + 7, theme.INK, label)
    }

    sub reset_calculator() {
        void strings.copy(iso:"0", calculator_display)
        calculator_left = 0.0
        calculator_operator = 0
        calculator_start_new = true
        calculator_error = false
    }

    sub calculator_has_decimal() -> bool {
        ubyte index = 0
        ubyte length = strings.length(calculator_display)

        while index < length {
            if calculator_display[index] == '.'
                return true
            index++
        }
        return false
    }

    sub enter_calculator_digit(ubyte key) {
        ubyte length

        if calculator_error
            reset_calculator()

        if calculator_start_new {
            calculator_display[0] = 0
            calculator_start_new = false
        }

        length = strings.length(calculator_display)

        ; Replace the initial zero instead of producing values such as 0007.
        if length == 1 and calculator_display[0] == '0' and key != '.' {
            calculator_display[0] = key
            calculator_display[1] = 0
            return
        }

        if key == '.' and calculator_has_decimal()
            return

        if length < 14 {
            ; A decimal entered first should read "0.".
            if key == '.' and length == 0 {
                calculator_display[0] = '0'
                length = 1
            }
            calculator_display[length] = key
            calculator_display[length + 1] = 0
        }
    }

    sub calculate_pending() -> bool {
        float right = floats.parse(calculator_display)
        float result

        when calculator_operator {
            '+' -> result = calculator_left + right
            '-' -> result = calculator_left - right
            '*' -> result = calculator_left * right
            '/' -> {
                if right == 0.0 {
                    void strings.copy(iso:"DIVIDE BY ZERO", calculator_display)
                    calculator_error = true
                    calculator_operator = 0
                    calculator_start_new = true
                    return false
                }
                result = calculator_left / right
            }
        }

        calculator_left = result
        void strings.copy(floats.tostr(result), calculator_display)
        return true
    }

    sub choose_calculator_operator(ubyte new_operator) {
        if calculator_error
            reset_calculator()

        ; Complete a waiting calculation before starting the next one. This
        ; permits natural chains such as 12 + 3 * 2.
        if calculator_operator != 0 and not calculator_start_new {
            if not calculate_pending()
                return
        } else
            calculator_left = floats.parse(calculator_display)

        calculator_operator = new_operator
        calculator_start_new = true
    }

    sub finish_calculation() {
        if calculator_error
            return
        if calculator_operator == 0
            return

        if calculate_pending() {
            calculator_operator = 0
            calculator_start_new = true
        }
    }

    sub backspace_calculator() {
        ubyte length

        if calculator_error {
            reset_calculator()
            return
        }

        length = strings.length(calculator_display)
        if length > 1
            calculator_display[length - 1] = 0
        else {
            calculator_display[0] = '0'
            calculator_display[1] = 0
            calculator_start_new = true
        }
    }

    sub use_calculator_key(ubyte key) {
        if key >= '0' and key <= '9'
            enter_calculator_digit(key)
        else if key == '.'
            enter_calculator_digit(key)
        else if key == '+' or key == '-' or key == '*' or key == '/'
            choose_calculator_operator(key)
        else if key == '=' or key == $0d
            finish_calculation()
        else if key == 'C' or key == 'c'
            reset_calculator()
        else if key == $14
            backspace_calculator()
    }

    sub calculator_key_at_pointer() -> ubyte {
        if input.inside(222, 65, 36, 23)
            return 'C'

        if input.inside(84, 95, 36, 21) return '7'
        if input.inside(128, 95, 36, 21) return '8'
        if input.inside(172, 95, 36, 21) return '9'
        if input.inside(216, 95, 36, 21) return '/'

        if input.inside(84, 121, 36, 21) return '4'
        if input.inside(128, 121, 36, 21) return '5'
        if input.inside(172, 121, 36, 21) return '6'
        if input.inside(216, 121, 36, 21) return '*'

        if input.inside(84, 147, 36, 21) return '1'
        if input.inside(128, 147, 36, 21) return '2'
        if input.inside(172, 147, 36, 21) return '3'
        if input.inside(216, 147, 36, 21) return '-'

        if input.inside(84, 173, 36, 21) return '0'
        if input.inside(128, 173, 36, 21) return '.'
        if input.inside(172, 173, 36, 21) return '='
        if input.inside(216, 173, 36, 21) return '+'
        return 0
    }

    sub show_calculator_overlay() {
        bool close_overlay = false
        ubyte clicked_key

        reset_calculator()
        draw_calculator_overlay()

        do {
            sys.waitvsync()
            input.poll()

            if input.left_pressed() {
                if input.inside(254, 43, 15, 12)
                    close_overlay = true
                else {
                    clicked_key = calculator_key_at_pointer()
                    if clicked_key != 0 {
                        use_calculator_key(clicked_key)
                        draw_calculator_overlay()
                    }
                }
            }

            if input.key != 0 and input.key != $1b {
                use_calculator_key(input.key)
                draw_calculator_overlay()
            }
        } until close_overlay or input.key == $1b

        ; Redraw the desktop after the modal window closes. show() also clears
        ; the closing click/key so it cannot activate anything underneath.
        show()
    }

    sub draw_file_manager_overlay() {
        ; A roomy two-pane file browser: favorite places stay on the left and
        ; the contents of the current location stay on the right.
        gfx_lores.fillrect(35, 39, 255, 168, theme.INK)
        gfx_lores.fillrect(32, 36, 255, 168, theme.PAPER)
        gfx_lores.rect(32, 36, 255, 168, theme.INK)

        gfx_lores.fillrect(33, 37, 253, 16, theme.BLUE)
        gfx_lores.text(40, 41, theme.PAPER, iso:"FILE MANAGER")
        gfx_lores.fillrect(266, 39, 15, 12, theme.RED)
        gfx_lores.text(270, 41, theme.PAPER, iso:"X")

        ; Location bar. The future browser will make each path segment usable.
        gfx_lores.fillrect(40, 59, 237, 14, theme.INK)
        gfx_lores.fillrect(42, 61, 233, 10, theme.PAPER)
        gfx_lores.text(47, 62, theme.INK, iso:"SD:/DESK")

        ; Places pane
        gfx_lores.fillrect(40, 78, 61, 99, theme.NAVY)
        gfx_lores.text(48, 82, theme.SOFT_BLUE, iso:"PLACES")
        gfx_lores.fillrect(43, 94, 55, 15, theme.BLUE)
        gfx_lores.text(47, 98, theme.PAPER, iso:"DESK")
        gfx_lores.text(47, 116, theme.PAPER, iso:"DOCS")
        gfx_lores.text(47, 134, theme.PAPER, iso:"NOTES")
        gfx_lores.text(47, 152, theme.PAPER, iso:"BACKUP")

        ; File list and column heading
        gfx_lores.rect(105, 78, 172, 99, theme.INK)
        gfx_lores.fillrect(106, 79, 170, 13, theme.BLUE)
        gfx_lores.text(111, 82, theme.PAPER, iso:"NAME           TYPE")

        draw_file_row(93, iso:"DOCUMENTS    DIR", true, true)
        draw_file_row(110, iso:"NOTES.TXT    TXT", false, false)
        draw_file_row(127, iso:"CONTACTS.DC  CARD", false, false)
        draw_file_row(144, iso:"AGENDA.DC    CAL", false, false)
        draw_file_row(161, iso:"README.TXT   TXT", false, false)

        ; Large, explicit actions are easier to understand than tiny toolbar
        ; glyphs and remain comfortable mouse targets at 320x240.
        draw_file_action(105, 182, 50, iso:"OPEN")
        draw_file_action(160, 182, 50, iso:"NEW")
        draw_file_action(215, 182, 62, iso:"CLOSE")
    }

    sub draw_file_row(ubyte y, str label, bool selected, bool folder) {
        ubyte row_color = theme.INK
        if selected {
            gfx_lores.fillrect(106, y, 170, 16, theme.SOFT_BLUE)
            row_color = theme.NAVY
        }

        ; A small type mark makes folders recognizable before reading the row.
        if folder {
            gfx_lores.fillrect(110, y + 4, 9, 3, theme.BLUE)
            gfx_lores.fillrect(108, y + 7, 14, 7, theme.BLUE)
        }
        gfx_lores.text(126, y + 4, row_color, label)
    }

    sub draw_file_action(uword x, ubyte y, ubyte width, str label) {
        gfx_lores.fillrect(x + 1, y + 1, width, 15, theme.INK)
        gfx_lores.fillrect(x, y, width, 15, theme.PAPER)
        gfx_lores.rect(x, y, width, 15, theme.BLUE)
        gfx_lores.text(x + 7, y + 4, theme.INK, label)
    }

    sub show_file_manager_overlay() {
        bool close_overlay = false

        draw_file_manager_overlay()

        do {
            sys.waitvsync()
            input.poll()

            ; Both the title-bar X and the visible Close button dismiss this
            ; scaffold. File activation arrives with disk I/O implementation.
            if input.left_pressed() {
                if input.inside(266, 39, 15, 12)
                    close_overlay = true
                if input.inside(215, 182, 62, 15)
                    close_overlay = true
            }
        } until close_overlay or input.key == $1b

        show()
    }

    sub draw_settings_overlay() {
        ; Settings uses visual categories rather than a dense preference list.
        gfx_lores.fillrect(45, 41, 235, 164, theme.INK)
        gfx_lores.fillrect(42, 38, 235, 164, theme.PAPER)
        gfx_lores.rect(42, 38, 235, 164, theme.INK)

        gfx_lores.fillrect(43, 39, 233, 16, theme.BLUE)
        gfx_lores.text(50, 43, theme.PAPER, iso:"SETTINGS")
        gfx_lores.fillrect(256, 41, 15, 12, theme.RED)
        gfx_lores.text(260, 43, theme.PAPER, iso:"X")

        draw_settings_option(51, 63, iso:"DISPLAY", 1)
        draw_settings_option(127, 63, iso:"MOUSE", 2)
        draw_settings_option(203, 63, iso:"SOUND", 3)

        draw_settings_option(51, 122, iso:"CLOCK", 4)
        draw_settings_option(127, 122, iso:"STORAGE", 5)
        draw_settings_option(203, 122, iso:"ABOUT", 6)
    }

    sub draw_settings_option(uword x, ubyte y, str label, ubyte option_icon) {
        gfx_lores.fillrect(x + 2, y + 2, 65, 50, theme.INK)
        gfx_lores.fillrect(x, y, 65, 50, theme.PAPER)
        gfx_lores.rect(x, y, 65, 50, theme.BLUE)

        when option_icon {
            1 -> draw_display_option_icon(x, y)
            2 -> draw_mouse_option_icon(x, y)
            3 -> draw_sound_option_icon(x, y)
            4 -> draw_clock_option_icon(x, y)
            5 -> draw_storage_option_icon(x, y)
            6 -> draw_about_option_icon(x, y)
        }

        ; Center labels according to their short, fixed category names.
        when option_icon {
            1 -> gfx_lores.text(x + 5, y + 39, theme.INK, label)
            2 -> gfx_lores.text(x + 13, y + 39, theme.INK, label)
            3 -> gfx_lores.text(x + 13, y + 39, theme.INK, label)
            4 -> gfx_lores.text(x + 13, y + 39, theme.INK, label)
            5 -> gfx_lores.text(x + 5, y + 39, theme.INK, label)
            6 -> gfx_lores.text(x + 13, y + 39, theme.INK, label)
        }
    }

    sub draw_display_option_icon(uword x, ubyte y) {
        gfx_lores.rect(x + 18, y + 6, 29, 20, theme.BLUE)
        gfx_lores.fillrect(x + 30, y + 26, 5, 6, theme.BLUE)
        gfx_lores.fillrect(x + 23, y + 32, 19, 3, theme.BLUE)
    }

    sub draw_mouse_option_icon(uword x, ubyte y) {
        gfx_lores.rect(x + 23, y + 5, 19, 29, theme.BLUE)
        gfx_lores.fillrect(x + 31, y + 6, 3, 9, theme.BLUE)
        gfx_lores.horizontal_line(x + 24, y + 16, 17, theme.BLUE)
    }

    sub draw_sound_option_icon(uword x, ubyte y) {
        gfx_lores.fillrect(x + 17, y + 14, 8, 12, theme.BLUE)
        gfx_lores.fillrect(x + 25, y + 10, 8, 20, theme.BLUE)
        gfx_lores.fillrect(x + 38, y + 13, 3, 14, theme.SOFT_BLUE)
        gfx_lores.fillrect(x + 44, y + 17, 3, 6, theme.BLUE)
    }

    sub draw_clock_option_icon(uword x, ubyte y) {
        gfx_lores.disc(x + 32, y + 19, 14, theme.BLUE)
        gfx_lores.disc(x + 32, y + 19, 11, theme.PAPER)
        gfx_lores.fillrect(x + 31, y + 10, 3, 10, theme.INK)
        gfx_lores.fillrect(x + 32, y + 18, 8, 3, theme.INK)
    }

    sub draw_storage_option_icon(uword x, ubyte y) {
        ; A small floppy/disk mark fits the X16 storage vocabulary.
        gfx_lores.fillrect(x + 20, y + 6, 27, 29, theme.BLUE)
        gfx_lores.fillrect(x + 25, y + 8, 14, 8, theme.PAPER)
        gfx_lores.fillrect(x + 25, y + 24, 17, 8, theme.PAPER)
    }

    sub draw_about_option_icon(uword x, ubyte y) {
        gfx_lores.disc(x + 32, y + 19, 14, theme.BLUE)
        gfx_lores.text(x + 29, y + 15, theme.PAPER, iso:"i")
    }

    sub show_settings_overlay() {
        bool close_overlay = false

        draw_settings_overlay()

        do {
            sys.waitvsync()
            input.poll()

            if input.left_pressed() and input.inside(256, 41, 15, 12)
                close_overlay = true
        } until close_overlay or input.key == $1b

        show()
    }

    sub draw_status(str message) {
        gfx_lores.fillrect(0, 213, 320, 27, theme.NAVY)
        gfx_lores.fillrect(0, 213, 320, 1, theme.INK)
        gfx_lores.text(5, 216, theme.PAPER, message)
        gfx_lores.text(5, 228, theme.SOFT_BLUE, iso:"CLICK A SECTION   ESC EXITS")
    }

    sub section_at_pointer() -> ubyte {
        if input.inside(NOTES_X, TOP_Y, NOTES_WIDTH, TOP_HEIGHT)
            return SECTION_NOTES
        if input.inside(CALENDAR_X, TOP_Y, CALENDAR_WIDTH, TOP_HEIGHT)
            return SECTION_CALENDAR
        if input.inside(MARKET_X, MARKET_Y, MARKET_WIDTH, MARKET_HEIGHT)
            return SECTION_MARKET
        if input.inside(ICON_X, FILE_Y, ICON_WIDTH, ICON_HEIGHT)
            return SECTION_FILES
        if input.inside(ICON_X, CALCULATOR_Y, ICON_WIDTH, ICON_HEIGHT)
            return SECTION_CALCULATOR
        if input.inside(ICON_X, ROLODEX_ICON_Y, ICON_WIDTH, ICON_HEIGHT)
            return SECTION_ROLODEX
        if input.inside(ICON_X, COMMS_Y, ICON_WIDTH, ICON_HEIGHT)
            return SECTION_COMMS
        if input.inside(ICON_X, SETTINGS_Y, ICON_WIDTH, ICON_HEIGHT)
            return SECTION_SETTINGS
        return SECTION_NONE
    }

    sub update_hover(ubyte new_section) {
        if new_section == hovered_section
            return

        ; Restore only the old target and redraw only the new one.
        when hovered_section {
            SECTION_NOTES -> draw_panel_heading(NOTES_X, TOP_Y, NOTES_WIDTH, iso:"NOTES", false)
            SECTION_CALENDAR -> draw_panel_heading(CALENDAR_X, TOP_Y, CALENDAR_WIDTH, iso:"CALENDAR", false)
            SECTION_ROLODEX -> draw_rail_button(ROLODEX_ICON_Y, ICON_ROLODEX, false)
            SECTION_FILES -> draw_rail_button(FILE_Y, ICON_FOLDER, false)
            SECTION_CALCULATOR -> draw_rail_button(CALCULATOR_Y, ICON_CALCULATOR, false)
            SECTION_COMMS -> draw_rail_button(COMMS_Y, ICON_COMMS, false)
            SECTION_SETTINGS -> draw_rail_button(SETTINGS_Y, ICON_SETTINGS, false)
            SECTION_MARKET -> draw_panel_heading(MARKET_X, MARKET_Y, MARKET_WIDTH, iso:"MARKET WATCH - DEMO", false)
        }

        when new_section {
            SECTION_NOTES -> draw_panel_heading(NOTES_X, TOP_Y, NOTES_WIDTH, iso:"NOTES", true)
            SECTION_CALENDAR -> draw_panel_heading(CALENDAR_X, TOP_Y, CALENDAR_WIDTH, iso:"CALENDAR", true)
            SECTION_ROLODEX -> draw_rail_button(ROLODEX_ICON_Y, ICON_ROLODEX, true)
            SECTION_FILES -> draw_rail_button(FILE_Y, ICON_FOLDER, true)
            SECTION_CALCULATOR -> draw_rail_button(CALCULATOR_Y, ICON_CALCULATOR, true)
            SECTION_COMMS -> draw_rail_button(COMMS_Y, ICON_COMMS, true)
            SECTION_SETTINGS -> draw_rail_button(SETTINGS_Y, ICON_SETTINGS, true)
            SECTION_MARKET -> draw_panel_heading(MARKET_X, MARKET_Y, MARKET_WIDTH, iso:"MARKET WATCH - DEMO", true)
        }

        hovered_section = new_section
    }

    sub show_placeholder_message() {
        when hovered_section {
            SECTION_NOTES -> draw_status(iso:"NOTES - DIRECT TYPING COMES NEXT")
            SECTION_CALENDAR -> draw_status(iso:"CALENDAR - MONTH AND DAY VIEWS")
            SECTION_ROLODEX -> draw_status(iso:"ROLODEX - SEARCHABLE CONTACT CARDS")
            SECTION_FILES -> draw_status(iso:"FILES - DISK AND DOCUMENT MANAGER")
            SECTION_COMMS -> draw_status(iso:"COMMS - FUTURE BUDDY CHAT")
            SECTION_SETTINGS -> draw_status(iso:"SETTINGS - DISPLAY AND PREFERENCES")
            SECTION_MARKET -> draw_status(iso:"MARKET WATCH - LIVE DATA COMES LATER")
        }
    }

    sub run() {
        do {
            sys.waitvsync()
            input.poll()

            update_hover(section_at_pointer())

            if input.left_pressed() {
                if hovered_section == SECTION_NOTES {
                    notes_app.open()
                    show()
                } else if hovered_section == SECTION_CALENDAR {
                    calendar_app.open()
                    show()
                } else if hovered_section == SECTION_ROLODEX {
                    rolodex_app.open()
                    show()
                } else if hovered_section == SECTION_FILES
                    show_file_manager_overlay()
                else if hovered_section == SECTION_CALCULATOR
                    show_calculator_overlay()
                else if hovered_section == SECTION_SETTINGS
                    show_settings_overlay()
                else
                    show_placeholder_message()
            }

            ; Check the RTC roughly once per second. update_clock() itself only
            ; repaints when a new minute begins.
            clock_frames += 1
            if clock_frames == 60 {
                clock_frames = 0
                update_clock()
            }
        } until input.key == $1b

        input.disable_mouse()
        gfx_lores.text_mode()
    }
}
