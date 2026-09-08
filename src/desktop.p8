%import conv
%import appmeta
%import diskio
%import desktop_extras
%import floats
%import gfx_lores
%import font5x7
%import input
%import calendar_app
%import market_data
%import preferences
%import strings
%import theme

; -----------------------------------------------------------------------------
; DESK COMMANDER organizer dashboard
; -----------------------------------------------------------------------------
;
; The desktop has two clear zones:
;   1. A slim icon rail keeps application launchers close to the left edge.
;   2. Notes and Calendar sit above Market Watch and a Screensaver launcher.
;
; Every area has its own mouse hit box and keyboard section number.

desktop {
    ; The file manager is a loadable high-RAM app. Keeping it outside the core
    ; desktop lets Desk Commander grow without crossing the X16's $9F00 limit.
    extsub @bank 4 $a000 = initialize_file_manager() clobbers(A, X, Y)
    extsub @bank 4 $a003 = open_file_manager() clobbers(A, X, Y)
    extsub @bank 7 $a000 = initialize_network_app() clobbers(A, X, Y)
    extsub @bank 7 $a003 = open_network_app() clobbers(A, X, Y)
    extsub @bank 13 $a000 = initialize_network_ui() clobbers(A, X, Y)
    extsub @bank 8 $a000 = initialize_market_app() clobbers(A, X, Y)
    extsub @bank 8 $a003 = open_market_app() clobbers(A, X, Y)
    extsub @bank 9 $a000 = initialize_market_fetch() clobbers(A, X, Y)
    extsub @bank 9 $a006 = refresh_market_group() clobbers(A, X, Y)
    extsub @bank 11 $a000 = initialize_notes_app() clobbers(A, X, Y)
    extsub @bank 11 $a003 = open_notes_app() clobbers(A, X, Y)
    extsub @bank 12 $a000 = initialize_comms_app() clobbers(A, X, Y)
    extsub @bank 12 $a003 = open_comms_app() clobbers(A, X, Y)
    extsub @bank 19 $a000 = initialize_rolodex_app() clobbers(A, X, Y)
    extsub @bank 19 $a003 = open_rolodex_app() clobbers(A, X, Y)
    extsub @bank 18 $a000 = initialize_screensaver() clobbers(A, X, Y)
    extsub @bank 18 $a003 = open_screensaver() clobbers(A, X, Y)
    sub draw_compact_market() { desktop_extras.draw_market_watch() }
    sub draw_market_refresh_idle() {
        desktop_extras.draw_market_refresh_button(false)
    }
    sub draw_market_refresh_busy() {
        desktop_extras.draw_market_refresh_button(true)
    }
    sub draw_screensaver_idle() { desktop_extras.draw_launcher(false) }
    sub draw_screensaver_active() { desktop_extras.draw_launcher(true) }

    sub load_bank(str filename, ubyte bank) -> bool {
        ; This routine itself lives in conventional RAM, so it remains visible
        ; while $A000-$BFFF is switched to the destination application bank.
        cx16.rambank(bank)
        cx16.r0 = diskio.loadlib(filename, $a000)
        cx16.rambank(0)
        return cx16.r0 != 0
    }

    sub load_file_suite() -> bool {
        bool loaded = load_bank(iso:"ZZFILEMAN.BIN", 4)
        if not load_bank(iso:"ZZFILEOPS.BIN", 5) loaded = false
        if not load_bank(iso:"ZZEDITOR.BIN", 6) loaded = false
        if not load_bank(iso:"ZZLAUNCH.BIN", 14) loaded = false
        return loaded
    }

    sub load_network_setup() -> bool {
        bool loaded = load_bank(iso:"ZZNETWORK.BIN", 7)
        if not load_bank(iso:"ZZNETPK.BIN", 13) loaded = false
        return loaded
    }

    sub load_market_watch() -> bool {
        bool loaded = load_bank(iso:"ZZMARKET.BIN", 8)
        if not load_bank(iso:"ZZMARKETNET.BIN", 9) loaded = false
        return loaded
    }

    sub load_notes() -> bool {
        return load_bank(iso:"ZZNOTES.BIN", 11)
    }

    sub load_rolodex() -> bool {
        return load_bank(iso:"ZZROLO.BIN", 19)
    }

    sub load_comms() -> bool {
        bool loaded = load_bank(iso:"ZZCOMMS.BIN", 12)
        if not load_bank(iso:"ZZCHATNET.BIN", 15) loaded = false
        if not load_bank(iso:"ZZCHATUI.BIN", 16) loaded = false
        if not load_bank(iso:"ZZEMOJI.BIN", 17) loaded = false
        return loaded
    }

    sub load_screensaver() -> bool {
        return load_bank(iso:"ZZSCREEN.BIN", 18)
    }

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
    const ubyte MARKET_WIDTH = 165
    const ubyte MARKET_HEIGHT = 70
    const uword SCREENSAVER_X = 221
    const ubyte SCREENSAVER_Y = 139
    const ubyte SCREENSAVER_WIDTH = 86
    const ubyte SCREENSAVER_HEIGHT = 70

    const ubyte SECTION_NONE = 0
    const ubyte SECTION_NOTES = 1
    const ubyte SECTION_CALENDAR = 2
    const ubyte SECTION_ROLODEX = 3
    const ubyte SECTION_CALCULATOR = 4
    const ubyte SECTION_FILES = 5
    const ubyte SECTION_COMMS = 6
    const ubyte SECTION_SETTINGS = 7
    const ubyte SECTION_MARKET = 8
    const ubyte SECTION_SCREENSAVER = 9

    const ubyte ICON_FOLDER = 1
    const ubyte ICON_CALCULATOR = 2
    const ubyte ICON_COMMS = 3
    const ubyte ICON_SETTINGS = 4
    const ubyte ICON_ROLODEX = 5

    ubyte hovered_section
    uword last_mouse_x
    uword last_mouse_y
    ubyte last_minute
    ubyte clock_frames
    uword market_frames
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
        market_data.initialize()
        ; Preserve personal symbols while ensuring the useful keyless assets
        ; appear for both new and upgraded installations when room exists.
        market_data.install_featured_assets()

        draw_desktop_header()
        draw_icon_rail()

        draw_panel(NOTES_X, TOP_Y, NOTES_WIDTH, TOP_HEIGHT, iso:"NOTES", false)
        draw_notes()

        draw_panel(CALENDAR_X, TOP_Y, CALENDAR_WIDTH, TOP_HEIGHT, iso:"CALENDAR", false)
        draw_calendar()

        draw_panel(MARKET_X, MARKET_Y, MARKET_WIDTH, MARKET_HEIGHT,
                   iso:"MARKET WATCH", false)
        if load_screensaver() {
            initialize_screensaver()
            draw_compact_market()
            draw_screensaver_idle()
        } else {
            gfx_lores.text(63, 177, theme.RED, iso:"MARKET DISPLAY MISSING")
            draw_panel(SCREENSAVER_X, SCREENSAVER_Y, SCREENSAVER_WIDTH,
                       SCREENSAVER_HEIGHT, iso:"SCREEN", false)
            gfx_lores.text(235, 177, theme.RED, iso:"MISSING")
        }

        draw_status(iso:"YOUR DESK IS READY")

        hovered_section = SECTION_NONE
        last_minute = 255
        clock_frames = 0
        market_frames = 0
        update_clock()

        ; Reconfigure the pointer for this screen and discard any click that
        ; was used to leave the splash screen.
        input.enable_mouse()
        last_mouse_x = input.mouse_x
        last_mouse_y = input.mouse_y
    }

    sub draw_desktop_header() {
        ; Leave a generous quiet area after the wordmark. The compact navy
        ; status field holds sound, Wi-Fi, and time at a glance.
        gfx_lores.fillrect(0, 0, 320, 18, theme.NAVY)
        gfx_lores.fillrect(0, 0, 204, 17, theme.PAPER)
        gfx_lores.fillrect(0, 17, 320, 1, theme.INK)
        gfx_lores.text(5, 5, theme.INK, iso:"DESK COMMANDER")

        draw_sound_status_icon()

        ; Two-pixel signal arcs and a solid dot read clearly at 320x240.
        ; Green is connected; offline keeps the white glyph plus a red slash.
        ubyte wifi_color = theme.PAPER
        if state_data.read(state_data.NETWORK_CONNECTED) != 0
            wifi_color = theme.GREEN
        gfx_lores.line(230, 6, 237, 2, wifi_color)
        gfx_lores.line(237, 2, 244, 6, wifi_color)
        gfx_lores.line(230, 7, 237, 3, wifi_color)
        gfx_lores.line(237, 3, 244, 7, wifi_color)
        gfx_lores.line(233, 11, 237, 8, wifi_color)
        gfx_lores.line(237, 8, 241, 11, wifi_color)
        gfx_lores.line(233, 12, 237, 9, wifi_color)
        gfx_lores.line(237, 9, 241, 12, wifi_color)
        ; A square three-pixel receiver dot stays crisp. The circle primitive
        ; makes a radius-one dot look like a distracting plus at this scale.
        gfx_lores.fillrect(236, 14, 3, 3, wifi_color)
        if state_data.read(state_data.NETWORK_CONNECTED) == 0
            gfx_lores.line(230, 3, 244, 16, theme.RED)
    }

    sub draw_sound_status_icon() {
        ; Repaint only the speaker region when Sound changes in Settings. This
        ; updates the permanent bar immediately without disturbing the clock.
        gfx_lores.fillrect(205, 2, 19, 15, theme.NAVY)

        ; Filled speaker silhouette: waves mean on; a red slash means muted.
        gfx_lores.fillrect(209, 8, 4, 4, theme.PAPER)
        gfx_lores.fillrect(213, 7, 2, 6, theme.PAPER)
        gfx_lores.fillrect(215, 5, 2, 10, theme.PAPER)
        if preferences.sound_enabled {
            gfx_lores.line(219, 6, 221, 8, theme.PAPER)
            gfx_lores.line(221, 8, 221, 11, theme.PAPER)
            gfx_lores.line(221, 11, 219, 13, theme.PAPER)
        }
        if not preferences.sound_enabled
            gfx_lores.line(208, 3, 221, 15, theme.RED)
    }

    sub update_clock() {
        uword year_month
        uword day_hours
        uword minute_seconds
        uword jiffies_weekday
        ubyte hour
        ubyte minute
        bool is_pm

        ; The X16 KERNAL returns two clock fields in each communication word.
        ; Hours are in r1H and minutes are in r2L.
        year_month, day_hours, minute_seconds, jiffies_weekday = cx16.clock_get_date_time()
        hour = msb(day_hours)
        minute = lsb(minute_seconds)
        is_pm = hour >= 12

        ; Only repaint when the minute changes. This keeps the top bar steady
        ; and avoids needless VERA drawing during the mouse loop.
        if minute == last_minute
            return

        last_minute = minute
        if not preferences.use_24_hour_clock {
            hour %= 12
            if hour == 0
                hour = 12
        }

        if not preferences.use_24_hour_clock and hour < 10
            clock_text[0] = 32           ; ISO space
        else
            clock_text[0] = hour / 10 + 48
        clock_text[1] = hour % 10 + 48
        clock_text[3] = minute / 10 + 48
        clock_text[4] = minute % 10 + 48

        gfx_lores.fillrect(258, 0, 62, 17, theme.NAVY)
        if preferences.use_24_hour_clock
            gfx_lores.text(269, 5, theme.PAPER, clock_text)
        else {
            gfx_lores.text(263, 5, theme.PAPER, clock_text)
            ; Keep AM/PM as compiler-encoded ISO strings. Building this suffix
            ; byte-by-byte caused PETSCII values to leak into the bitmap font.
            if is_pm
                gfx_lores.text(303, 5, theme.PAPER, iso:"PM")
            else
                gfx_lores.text(303, 5, theme.PAPER, iso:"AM")
        }
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

    sub refresh_market_glance() {
        draw_market_refresh_busy()
        draw_status(iso:"UPDATING THREE MARKET PRICES...")
        if load_market_watch() {
            initialize_market_fetch()
            market_data.set_requested_stock(market_data.current_page() * 3)
            refresh_market_group()
            draw_compact_market()
            draw_status(iso:"MARKET PRICES UPDATED")
        } else {
            draw_market_refresh_idle()
            draw_status(iso:"MARKET WATCH APP IS MISSING")
        }
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
        ; An open folder with a tab, document sheet, and visible text lines.
        gfx_lores.fillrect(ICON_X + 7, y + 7, 11, 5, color)
        gfx_lores.fillrect(ICON_X + 5, y + 11, 25, 15, color)
        gfx_lores.fillrect(ICON_X + 8, y + 14, 19, 9, cutout_color)
        gfx_lores.fillrect(ICON_X + 11, y + 10, 14, 11, cutout_color)
        gfx_lores.rect(ICON_X + 11, y + 10, 14, 11, color)
        gfx_lores.horizontal_line(ICON_X + 14, y + 14, 8, color)
        gfx_lores.horizontal_line(ICON_X + 14, y + 17, 8, color)
        gfx_lores.fillrect(ICON_X + 6, y + 21, 23, 5, color)
    }

    sub draw_calculator_icon(ubyte y, ubyte color, ubyte cutout_color) {
        ; A compact handheld calculator: clipped corners, inset LCD, three
        ; number rows, and a separate operator column. The stronger silhouette
        ; remains recognizable when the rail button is highlighted red.
        gfx_lores.fillrect(ICON_X + 8, y + 2, 20, 27, color)
        gfx_lores.fillrect(ICON_X + 6, y + 4, 24, 23, color)
        gfx_lores.fillrect(ICON_X + 9, y + 5, 18, 20, cutout_color)

        ; Recessed display with a tiny right-aligned readout mark.
        gfx_lores.fillrect(ICON_X + 10, y + 6, 16, 6, color)
        gfx_lores.fillrect(ICON_X + 12, y + 8, 11, 2, cutout_color)
        gfx_lores.fillrect(ICON_X + 23, y + 8, 2, 2, cutout_color)
        gfx_lores.horizontal_line(ICON_X + 10, y + 13, 16, color)

        ; Raised square keys plus a tall operation key and wide equals key.
        gfx_lores.fillrect(ICON_X + 10, y + 15, 3, 3, color)
        gfx_lores.fillrect(ICON_X + 15, y + 15, 3, 3, color)
        gfx_lores.fillrect(ICON_X + 20, y + 15, 3, 3, color)
        gfx_lores.fillrect(ICON_X + 25, y + 15, 2, 7, color)
        gfx_lores.fillrect(ICON_X + 10, y + 20, 3, 3, color)
        gfx_lores.fillrect(ICON_X + 15, y + 20, 3, 3, color)
        gfx_lores.fillrect(ICON_X + 20, y + 20, 3, 3, color)
        gfx_lores.fillrect(ICON_X + 10, y + 25, 8, 2, color)
        gfx_lores.fillrect(ICON_X + 20, y + 25, 7, 2, color)
    }

    sub draw_comms_icon(ubyte y, ubyte color, ubyte cutout_color) {
        ; Two overlapping conversation balloons make COMMS read as an app,
        ; while the three dots add detail without becoming tiny text.
        gfx_lores.fillrect(ICON_X + 13, y + 5, 18, 14, color)
        gfx_lores.fillrect(ICON_X + 15, y + 7, 14, 9, cutout_color)
        gfx_lores.fillrect(ICON_X + 26, y + 17, 4, 4, color)

        gfx_lores.fillrect(ICON_X + 4, y + 11, 22, 14, color)
        gfx_lores.fillrect(ICON_X + 7, y + 14, 16, 8, cutout_color)
        gfx_lores.fillrect(ICON_X + 6, y + 23, 5, 4, color)

        gfx_lores.fillrect(ICON_X + 9, y + 17, 2, 2, color)
        gfx_lores.fillrect(ICON_X + 14, y + 17, 2, 2, color)
        gfx_lores.fillrect(ICON_X + 19, y + 17, 2, 2, color)
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
        ; Three control sliders are cleaner than a tiny low-resolution gear.
        ; Each square knob has a cutout center, matching the Rolodex detail.
        gfx_lores.horizontal_line(ICON_X + 6, y + 8, 23, color)
        gfx_lores.fillrect(ICON_X + 11, y + 5, 7, 7, color)
        gfx_lores.fillrect(ICON_X + 13, y + 7, 3, 3, cutout_color)

        gfx_lores.horizontal_line(ICON_X + 6, y + 15, 23, color)
        gfx_lores.fillrect(ICON_X + 21, y + 12, 7, 7, color)
        gfx_lores.fillrect(ICON_X + 23, y + 14, 3, 3, cutout_color)

        gfx_lores.horizontal_line(ICON_X + 6, y + 22, 23, color)
        gfx_lores.fillrect(ICON_X + 14, y + 19, 7, 7, color)
        gfx_lores.fillrect(ICON_X + 16, y + 21, 3, 3, cutout_color)
    }

    sub draw_calculator_overlay() {
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
        draw_calculator_display()
        draw_overlay_key(222, 65, iso:"C")

        ; Four familiar rows keep the working calculator compact and readable.
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

    sub draw_calculator_display() {
        ubyte display_length = strings.length(calculator_display)
        uword display_x = 206 - (display_length as uword) * 8

        ; Digits change constantly, so keep this as a small dirty region.
        gfx_lores.fillrect(83, 65, 134, 23, theme.INK)
        gfx_lores.fillrect(86, 68, 128, 17, theme.PAPER)
        if calculator_error
            gfx_lores.text(94, 73, theme.RED, calculator_display)
        else
            gfx_lores.text(display_x, 73, theme.INK, calculator_display)
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
                        draw_calculator_display()
                    }
                }
            }

            if input.key != 0 and input.key != $1b {
                use_calculator_key(input.key)
                draw_calculator_display()
            }
        } until close_overlay or input.key == $1b

        ; Redraw the desktop after the modal window closes. show() also clears
        ; the closing click/key so it cannot activate anything underneath.
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

        draw_settings_option(51, 63, iso:"THEME", 1)
        draw_settings_option(127, 63, iso:"MOUSE", 2)
        draw_settings_option(203, 63, iso:"SOUND", 3)

        draw_settings_option(51, 122, iso:"CLOCK", 4)
        draw_settings_option(127, 122, iso:"NETWORK", 5)
        draw_settings_option(203, 122, iso:"ABOUT", 6)
    }

    sub draw_settings_option(uword x, ubyte y, str label, ubyte option_icon) {
        gfx_lores.fillrect(x + 2, y + 2, 65, 50, theme.INK)
        gfx_lores.fillrect(x, y, 65, 50, theme.PAPER)
        gfx_lores.rect(x, y, 65, 50, theme.BLUE)

        when option_icon {
            1 -> draw_theme_option_icon(x, y)
            2 -> draw_mouse_option_icon(x, y)
            3 -> draw_sound_option_icon(x, y)
            4 -> draw_clock_option_icon(x, y)
            5 -> draw_network_option_icon(x, y)
            6 -> draw_about_option_icon(x, y)
        }

        ; NETWORK is wider than the other category names.
        if option_icon == 5
            gfx_lores.text(x + 5, y + 39, theme.INK, label)
        else
            gfx_lores.text(x + 13, y + 39, theme.INK, label)
    }

    sub draw_theme_option_icon(uword x, ubyte y) {
        ; Three swatches preview the package using the live palette indexes.
        gfx_lores.fillrect(x + 13, y + 7, 12, 12, theme.NAVY)
        gfx_lores.fillrect(x + 27, y + 7, 12, 12, theme.BLUE)
        gfx_lores.fillrect(x + 41, y + 7, 12, 12, theme.RED)

        when theme.current_package {
            0 -> gfx_lores.text(x + 20, y + 25, theme.INK, iso:"X16")
            1 -> gfx_lores.text(x + 12, y + 25, theme.INK, iso:"AMBER")
            2 -> gfx_lores.text(x + 12, y + 25, theme.INK, iso:"NIGHT")
        }
    }

    sub draw_mouse_option_icon(uword x, ubyte y) {
        ; A proper desktop-mouse badge: cable, rounded shell, separate buttons,
        ; and wheel. The wheel color previews the active cursor package without
        ; turning the whole Settings icon into another pointer.
        ubyte accent = 16
        if input.mouse_preset == 0
            accent = theme.MOUSE_BLUE
        else if input.mouse_preset == 1
            accent = theme.MOUSE_RED

        ; Cable and offset shadow give the tiny symbol some depth.
        gfx_lores.line(x + 32, y + 3, x + 32, y + 7, theme.INK)
        gfx_lores.fillrect(x + 26, y + 9, 17, 19, theme.INK)
        gfx_lores.disc(x + 34, y + 10, 8, theme.INK)
        gfx_lores.disc(x + 34, y + 27, 8, theme.INK)

        ; Bright inset shell, divided buttons, and a crisp center wheel.
        gfx_lores.fillrect(x + 28, y + 10, 13, 16, theme.PAPER)
        gfx_lores.disc(x + 34, y + 11, 6, theme.PAPER)
        gfx_lores.disc(x + 34, y + 25, 6, theme.PAPER)
        gfx_lores.horizontal_line(x + 28, y + 16, 13, theme.BLUE)
        gfx_lores.line(x + 34, y + 10, x + 34, y + 16, theme.BLUE)
        gfx_lores.fillrect(x + 32, y + 11, 4, 7, accent)
    }

    sub draw_sound_option_icon(uword x, ubyte y) {
        gfx_lores.fillrect(x + 17, y + 14, 8, 12, theme.BLUE)
        gfx_lores.fillrect(x + 25, y + 10, 8, 20, theme.BLUE)
        gfx_lores.fillrect(x + 38, y + 13, 3, 14, theme.SOFT_BLUE)
        gfx_lores.fillrect(x + 44, y + 17, 3, 6, theme.BLUE)

        if not preferences.sound_enabled {
            gfx_lores.line(x + 16, y + 7, x + 49, y + 32, theme.RED)
            gfx_lores.text(x + 25, y + 28, theme.RED, iso:"OFF")
        }
    }

    sub draw_clock_option_icon(uword x, ubyte y) {
        gfx_lores.disc(x + 32, y + 19, 14, theme.BLUE)
        gfx_lores.disc(x + 32, y + 19, 11, theme.PAPER)
        gfx_lores.fillrect(x + 31, y + 10, 3, 10, theme.INK)
        gfx_lores.fillrect(x + 32, y + 18, 8, 3, theme.INK)

        if preferences.use_24_hour_clock
            gfx_lores.text(x + 42, y + 28, theme.BLUE, iso:"24")
        else
            gfx_lores.text(x + 42, y + 28, theme.BLUE, iso:"12")
    }

    sub draw_network_option_icon(uword x, ubyte y) {
        ; A bright Wi-Fi mark reads clearly at the Settings tile's tiny size.
        gfx_lores.line(x + 17, y + 13, x + 32, y + 6, theme.BLUE)
        gfx_lores.line(x + 32, y + 6, x + 47, y + 13, theme.BLUE)
        gfx_lores.line(x + 22, y + 20, x + 32, y + 14, theme.BLUE)
        gfx_lores.line(x + 32, y + 14, x + 42, y + 20, theme.BLUE)
        gfx_lores.line(x + 27, y + 26, x + 32, y + 22, theme.BLUE)
        gfx_lores.line(x + 32, y + 22, x + 37, y + 26, theme.BLUE)
        gfx_lores.disc(x + 32, y + 31, 3, theme.RED)
    }

    sub draw_about_option_icon(uword x, ubyte y) {
        gfx_lores.disc(x + 32, y + 19, 14, theme.BLUE)
        gfx_lores.text(x + 29, y + 15, theme.PAPER, iso:"i")
    }

    sub show_network_setup() {
        if load_network_setup() {
            initialize_network_ui()
            initialize_network_app()
            open_network_app()
        } else
            draw_status(iso:"NETWORK APP IS MISSING")
    }

    sub draw_about_dialog() {
        gfx_lores.fillrect(39, 34, 244, 174, theme.INK)
        gfx_lores.fillrect(36, 31, 244, 174, theme.PAPER)
        gfx_lores.rect(36, 31, 244, 174, theme.INK)
        gfx_lores.fillrect(37, 32, 242, 16, theme.BLUE)
        gfx_lores.text(44, 36, theme.PAPER, iso:"ABOUT DESK COMMANDER")
        gfx_lores.fillrect(259, 34, 15, 12, theme.RED)
        gfx_lores.text(263, 36, theme.PAPER, iso:"X")

        gfx_lores.text(48, 58, theme.RED, iso:"RODDY")
        gfx_lores.text(48, 70, theme.INK, iso:"CREATOR / DESIGNER")
        gfx_lores.text(48, 84, theme.INK, iso:"BUILDING FRIENDLY RETRO")
        gfx_lores.text(48, 96, theme.INK, iso:"SOFTWARE FOR THE X16.")

        gfx_lores.horizontal_line(48, 112, 220, theme.SOFT_BLUE)
        gfx_lores.text(48, 122, theme.BLUE, iso:"DESK COMMANDER")
        gfx_lores.text(48, 136, theme.INK, iso:"A DESKMATE-INSPIRED")
        gfx_lores.text(48, 148, theme.INK, iso:"HOME FOR NOTES, DATES,")
        gfx_lores.text(48, 160, theme.INK, iso:"CONTACTS, FILES & TOOLS.")
        gfx_lores.text(48, 178, theme.BLUE, appmeta.VERSION)
        gfx_lores.text(48, 190, theme.RED, appmeta.CREATOR)
    }

    sub show_about_dialog() {
        draw_about_dialog()

        wait_for_large_dialog()
    }

    sub wait_for_large_dialog() {
        bool close_dialog = false

        do {
            sys.waitvsync()
            input.poll()
            if input.left_pressed() {
                ; Covers the nearly identical close buttons used by About
                ; and the in-place Network page.
                if input.inside(256, 34, 18, 19)
                    close_dialog = true
            }
        } until close_dialog or input.key == $1b

        input.key = 0
    }

    sub draw_clock_choice(uword x, str label, bool selected) {
        gfx_lores.fillrect(x + 2, 119, 61, 23, theme.INK)
        gfx_lores.fillrect(x, 117, 61, 23, theme.PAPER)
        if selected
            gfx_lores.rect(x, 117, 61, 23, theme.GOLD)
        else
            gfx_lores.rect(x, 117, 61, 23, theme.BLUE)
        gfx_lores.text(x + 3, 124, theme.INK, label)
    }

    sub draw_clock_format_dialog() {
        gfx_lores.fillrect(85, 79, 158, 83, theme.INK)
        gfx_lores.fillrect(82, 76, 158, 83, theme.PAPER)
        gfx_lores.rect(82, 76, 158, 83, theme.INK)
        gfx_lores.fillrect(83, 77, 156, 16, theme.BLUE)
        gfx_lores.text(90, 81, theme.PAPER, iso:"CLOCK FORMAT")
        gfx_lores.fillrect(219, 79, 15, 12, theme.RED)
        gfx_lores.text(223, 81, theme.PAPER, iso:"X")
        gfx_lores.text(94, 101, theme.INK, iso:"CHOOSE A DISPLAY")

        draw_clock_choice(92, iso:"12 HOUR", not preferences.use_24_hour_clock)
        draw_clock_choice(167, iso:"24 HOUR", preferences.use_24_hour_clock)
        gfx_lores.text(105, 147, theme.SOFT_BLUE, iso:"A/P OR 00-23")
    }

    sub show_clock_format_dialog() {
        bool close_dialog = false

        draw_clock_format_dialog()
        do {
            sys.waitvsync()
            input.poll()

            if input.left_pressed() {
                if input.inside(92, 117, 61, 23) {
                    preferences.use_24_hour_clock = false
                    preferences.save()
                    last_minute = 255
                    update_clock()
                    close_dialog = true
                } else if input.inside(167, 117, 61, 23) {
                    preferences.use_24_hour_clock = true
                    preferences.save()
                    last_minute = 255
                    update_clock()
                    close_dialog = true
                } else if input.inside(219, 79, 15, 12)
                    close_dialog = true
            }
        } until close_dialog or input.key == $1b

        ; Escape belongs to this small dialog, not the Settings window.
        input.key = 0
    }

    sub show_settings_overlay() {
        bool close_overlay = false

        draw_settings_overlay()

        do {
            sys.waitvsync()
            input.poll()

            if input.left_pressed() {
                if input.inside(51, 63, 65, 50) {
                    theme.next_package()
                    draw_settings_option(51, 63, iso:"THEME", 1)
                } else if input.inside(127, 63, 65, 50) {
                    input.next_mouse_preset()
                    draw_settings_option(127, 63, iso:"MOUSE", 2)
                } else if input.inside(203, 63, 65, 50) {
                    preferences.toggle_sound()
                    ; Keep the always-visible status bar synchronized with
                    ; the Sound tile while Settings remains open.
                    draw_sound_status_icon()
                    draw_settings_option(203, 63, iso:"SOUND", 3)
                } else if input.inside(51, 122, 65, 50) {
                    show_clock_format_dialog()
                    draw_settings_overlay()
                } else if input.inside(127, 122, 65, 50) {
                    show_network_setup()
                    draw_settings_overlay()
                } else if input.inside(203, 122, 65, 50) {
                    show_about_dialog()
                    draw_settings_overlay()
                } else if input.inside(256, 41, 15, 12)
                    close_overlay = true
            }

            ; Direct category shortcuts also make Settings usable when a
            ; pointer is unavailable. N opens the Network setup application.
            if input.key == 'N' or input.key == 'n' {
                show_network_setup()
                draw_settings_overlay()
            }
        } until close_overlay or input.key == $1b

        show()
    }

    sub draw_status(str message) {
        gfx_lores.fillrect(0, 213, 320, 27, theme.NAVY)
        gfx_lores.fillrect(0, 213, 320, 1, theme.INK)
        gfx_lores.text(5, 216, theme.PAPER, message)
        gfx_lores.text(5, 228, theme.SOFT_BLUE, iso:"ARROWS SELECT   ENTER OPENS")
    }

    sub section_at_pointer() -> ubyte {
        if input.inside(NOTES_X, TOP_Y, NOTES_WIDTH, TOP_HEIGHT)
            return SECTION_NOTES
        if input.inside(CALENDAR_X, TOP_Y, CALENDAR_WIDTH, TOP_HEIGHT)
            return SECTION_CALENDAR
        if input.inside(MARKET_X, MARKET_Y, MARKET_WIDTH, MARKET_HEIGHT)
            return SECTION_MARKET
        if input.inside(SCREENSAVER_X, SCREENSAVER_Y,
                        SCREENSAVER_WIDTH, SCREENSAVER_HEIGHT)
            return SECTION_SCREENSAVER
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
            SECTION_MARKET -> {
                draw_panel_heading(MARKET_X, MARKET_Y, MARKET_WIDTH, iso:"MARKET WATCH", false)
                draw_market_refresh_idle()
            }
            SECTION_SCREENSAVER -> draw_screensaver_idle()
        }

        when new_section {
            SECTION_NOTES -> draw_panel_heading(NOTES_X, TOP_Y, NOTES_WIDTH, iso:"NOTES", true)
            SECTION_CALENDAR -> draw_panel_heading(CALENDAR_X, TOP_Y, CALENDAR_WIDTH, iso:"CALENDAR", true)
            SECTION_ROLODEX -> draw_rail_button(ROLODEX_ICON_Y, ICON_ROLODEX, true)
            SECTION_FILES -> draw_rail_button(FILE_Y, ICON_FOLDER, true)
            SECTION_CALCULATOR -> draw_rail_button(CALCULATOR_Y, ICON_CALCULATOR, true)
            SECTION_COMMS -> draw_rail_button(COMMS_Y, ICON_COMMS, true)
            SECTION_SETTINGS -> draw_rail_button(SETTINGS_Y, ICON_SETTINGS, true)
            SECTION_MARKET -> {
                draw_panel_heading(MARKET_X, MARKET_Y, MARKET_WIDTH, iso:"MARKET WATCH", true)
                draw_market_refresh_idle()
            }
            SECTION_SCREENSAVER -> draw_screensaver_active()
        }

        hovered_section = new_section
    }

    sub select_next_section() {
        ubyte next_section = hovered_section + 1
        if hovered_section == SECTION_NONE or next_section > SECTION_SCREENSAVER
            next_section = SECTION_NOTES
        update_hover(next_section)
    }

    sub select_previous_section() {
        ubyte previous_section = hovered_section - 1
        if hovered_section == SECTION_NONE or hovered_section == SECTION_NOTES
            previous_section = SECTION_SCREENSAVER
        update_hover(previous_section)
    }

    sub open_selected_section() {
        if hovered_section == SECTION_NOTES {
            if load_notes() {
                initialize_notes_app()
                open_notes_app()
                show()
            } else
                draw_status(iso:"NOTES APP IS MISSING")
        } else if hovered_section == SECTION_CALENDAR {
            calendar_app.open()
            show()
        } else if hovered_section == SECTION_ROLODEX {
            if load_rolodex() {
                initialize_rolodex_app()
                open_rolodex_app()
                show()
            } else
                draw_status(iso:"DIRECTORY APP IS MISSING")
        } else if hovered_section == SECTION_FILES {
            if load_file_suite() {
                initialize_file_manager()
                open_file_manager()
                show()
            } else
                draw_status(iso:"FILE MANAGER APP IS MISSING")
        }
        else if hovered_section == SECTION_CALCULATOR
            show_calculator_overlay()
        else if hovered_section == SECTION_COMMS {
            if load_comms() {
                initialize_comms_app()
                open_comms_app()
                show()
            } else
                draw_status(iso:"COMMS APP IS MISSING")
        } else if hovered_section == SECTION_SETTINGS
            show_settings_overlay()
        else if hovered_section == SECTION_MARKET {
            if load_market_watch() {
                initialize_market_app()
                open_market_app()
                show()
            } else
                draw_status(iso:"MARKET WATCH APP IS MISSING")
        } else if hovered_section == SECTION_SCREENSAVER {
            if load_screensaver() {
                initialize_screensaver()
                open_screensaver()
                show()
            } else
                draw_status(iso:"SCREENSAVER APP IS MISSING")
        }
    }

    sub run() {
        do {
            sys.waitvsync()
            input.poll()

            ; Moving the pointer hands focus back to the mouse. Until then,
            ; arrow-key focus stays put instead of snapping under the cursor.
            if input.mouse_x != last_mouse_x or input.mouse_y != last_mouse_y {
                last_mouse_x = input.mouse_x
                last_mouse_y = input.mouse_y
                update_hover(section_at_pointer())
            }

            if input.key == $1d or input.key == $11 {
                select_next_section()
            } else if input.key == $9d or input.key == $91 {
                select_previous_section()
            }

            if input.left_pressed() {
                if input.inside(195, 141, 18, 11) {
                    preferences.play_click()
                    refresh_market_glance()
                } else {
                    update_hover(section_at_pointer())
                    open_selected_section()
                }
            } else if input.key == $0d and hovered_section != SECTION_NONE {
                preferences.play_click()
                open_selected_section()
            }

            ; Check the RTC roughly once per second. update_clock() itself only
            ; repaints when a new minute begins.
            clock_frames += 1
            if clock_frames == 60 {
                clock_frames = 0
                update_clock()
            }

            market_frames++
            if market_frames == 1800 {
                market_frames = 0
                market_data.next_page()
                draw_compact_market()
            }
        } until input.key == $1b

        input.disable_mouse()
        gfx_lores.text_mode()
    }
}
