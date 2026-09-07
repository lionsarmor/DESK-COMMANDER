%import conv
%import gfx_lores
%import input
%import state_data
%import strings
%import syslib
%import theme

; -----------------------------------------------------------------------------
; Calendar application
; -----------------------------------------------------------------------------
;
; The working set is a bounded appointment book: each record stores a year,
; month, day, type, and short title. Arrays live in RAM while the app is open;
; save_state() mirrors them into the device-8 persistent state image.

calendar_app {
    const ubyte EVENT_NONE = 0
    const ubyte EVENT_APPOINTMENT = 1
    const ubyte EVENT_TASK = 2
    const ubyte EVENT_PERSONAL = 3
    const ubyte NO_EVENT_SLOT = 255
    const ubyte MAX_EVENTS = 24

    bool initialized
    ubyte current_month
    uword current_year
    ; Sunday is 0, Monday is 1, and so on.
    ubyte first_weekday
    ubyte selected_day
    ubyte[24] event_months
    ubyte[24] event_days
    ubyte[24] event_types
    uword[24] event_years
    ; Titles live directly in the shared VERA state image: twenty bytes per
    ; event, nineteen visible characters plus the zero ending.
    ubyte[20] event_title_buffer

    sub load_state() {
        state_data.transfer_memory_5 = &current_month
        state_data.transfer_memory_6 = &current_year
        state_data.transfer_memory_7 = &first_weekday
        state_data.transfer_memory_8 = &selected_day
        state_data.transfer_memory = &event_months
        state_data.transfer_memory_2 = &event_days
        state_data.transfer_memory_3 = &event_types
        state_data.transfer_memory_4 = &event_years
        state_data.restore_calendar_arrays()
    }

    sub save_state() {
        state_data.write(state_data.CALENDAR, $a5)
        state_data.transfer_memory_5 = &current_month
        state_data.transfer_memory_6 = &current_year
        state_data.transfer_memory_7 = &first_weekday
        state_data.transfer_memory_8 = &selected_day
        state_data.transfer_memory = &event_months
        state_data.transfer_memory_2 = &event_days
        state_data.transfer_memory_3 = &event_types
        state_data.transfer_memory_4 = &event_years
        state_data.store_calendar_arrays()
        state_data.save()
    }

    sub initialize() {
        if initialized
            return

        if state_data.read(state_data.CALENDAR) == $a5
            load_state()
        else {
            current_month = 9
            current_year = 2026
            first_weekday = 2       ; September 1, 2026 is a Tuesday.
            selected_day = 5

            ; A few examples make the color language visible on first launch.
            create_sample_event(0, 5, EVENT_APPOINTMENT, iso:"DENTIST AT 10 AM")
            create_sample_event(1, 12, EVENT_TASK, iso:"FINISH ROADMAP")
            create_sample_event(2, 21, EVENT_PERSONAL, iso:"DINNER WITH ALEX")
            create_sample_event(3, 30, EVENT_APPOINTMENT, iso:"PROJECT MEETING")
            save_state()
        }

        initialized = true
    }

    sub create_sample_event(ubyte slot, ubyte day, ubyte event_type, str title) {
        event_months[slot] = 9
        event_days[slot] = day
        event_types[slot] = event_type
        event_years[slot] = 2026
        copy_event_title(slot, title)
    }

    sub title_for_slot(ubyte slot) -> str {
        return state_data.CALENDAR + 126 + (slot as uword) * 20
    }

    ; Bank switching stays inside these tiny helpers. Code and ordinary app
    ; variables remain visible in bank 0 everywhere else.
    sub copy_event_title(ubyte slot, str source) {
        uword destination = title_for_slot(slot)
        ubyte index = 0

        while source[index] != 0 and index < 19 {
            state_data.write(destination + index, source[index])
            index++
        }
        state_data.write(destination + index, 0)
    }

    sub event_title_length(ubyte slot) -> ubyte {
        uword title = title_for_slot(slot)
        ubyte length = 0

        while state_data.read(title + length) != 0 and length < 19
            length++
        return length
    }

    sub clear_event_title(ubyte slot) {
        uword title = title_for_slot(slot)

        state_data.write(title, 0)
    }

    sub set_event_title_character(ubyte slot, ubyte index, ubyte value) {
        uword title = title_for_slot(slot)

        state_data.write(title + index, value)
    }

    sub draw_event_title(ubyte slot) {
        ubyte index
        uword title = title_for_slot(slot)
        for index in 0 to 19
            event_title_buffer[index] = state_data.read(title + index)
        gfx_lores.text(77, 101, theme.INK, event_title_buffer)
    }

    sub draw_event_title_field() {
        ; The title is the only part of the event window that changes while
        ; somebody types. Repainting this small dirty region avoids the harsh
        ; flash caused by drawing the entire modal for every character.
        ubyte event_slot = event_slot_for(selected_day)

        gfx_lores.fillrect(72, 97, 182, 16, theme.PAPER)
        if event_slot == NO_EVENT_SLOT
            gfx_lores.text(77, 101, theme.SOFT_BLUE, iso:"TYPE EVENT NAME")
        else
            draw_event_title(event_slot)
    }

    sub event_slot_for(ubyte day) -> ubyte {
        ubyte slot

        for slot in 0 to MAX_EVENTS - 1 {
            if event_types[slot] != EVENT_NONE and
               event_months[slot] == current_month and
               event_days[slot] == day and
               event_years[slot] == current_year
                return slot
        }
        return NO_EVENT_SLOT
    }

    sub event_type_for_day(ubyte day) -> ubyte {
        ; The desktop's at-a-glance calendar uses this small public query.
        ; Keeping the record lookup here means both calendar views always read
        ; exactly the same event data.
        ubyte slot = event_slot_for(day)

        if slot == NO_EVENT_SLOT
            return EVENT_NONE
        return event_types[slot]
    }

    sub available_event_slot() -> ubyte {
        ubyte slot

        for slot in 0 to MAX_EVENTS - 1 {
            if event_types[slot] == EVENT_NONE
                return slot
        }
        return NO_EVENT_SLOT
    }

    sub ensure_selected_event(ubyte event_type) -> ubyte {
        ubyte slot = event_slot_for(selected_day)

        if slot == NO_EVENT_SLOT {
            slot = available_event_slot()
            if slot == NO_EVENT_SLOT
                return slot

            event_months[slot] = current_month
            event_days[slot] = selected_day
            event_years[slot] = current_year
            clear_event_title(slot)
        }

        event_types[slot] = event_type
        return slot
    }

    sub color_for_event(ubyte event_type) -> ubyte {
        when event_type {
            EVENT_APPOINTMENT -> return theme.RED
            EVENT_TASK -> return theme.BLUE
            EVENT_PERSONAL -> return theme.GREEN
        }
        return theme.PAPER
    }

    sub days_in_month() -> ubyte {
        when current_month {
            2 -> {
                ; Gregorian leap-year rule. The next century edge is far away,
                ; but handling it correctly costs very little here.
                if current_year % 400 == 0
                    return 29
                if current_year % 100 == 0
                    return 28
                if current_year % 4 == 0
                    return 29
                return 28
            }
            4 -> return 30
            6 -> return 30
            9 -> return 30
            11 -> return 30
        }
        return 31
    }

    sub draw_month_name(uword x, ubyte y, ubyte color) {
        when current_month {
            1 -> gfx_lores.text(x, y, color, iso:"JANUARY")
            2 -> gfx_lores.text(x, y, color, iso:"FEBRUARY")
            3 -> gfx_lores.text(x, y, color, iso:"MARCH")
            4 -> gfx_lores.text(x, y, color, iso:"APRIL")
            5 -> gfx_lores.text(x, y, color, iso:"MAY")
            6 -> gfx_lores.text(x, y, color, iso:"JUNE")
            7 -> gfx_lores.text(x, y, color, iso:"JULY")
            8 -> gfx_lores.text(x, y, color, iso:"AUGUST")
            9 -> gfx_lores.text(x, y, color, iso:"SEPTEMBER")
            10 -> gfx_lores.text(x, y, color, iso:"OCTOBER")
            11 -> gfx_lores.text(x, y, color, iso:"NOVEMBER")
            12 -> gfx_lores.text(x, y, color, iso:"DECEMBER")
        }
    }

    sub draw_month_heading() {
        ; Compact arrow buttons leave enough room for even SEPTEMBER 2026.
        gfx_lores.fillrect(40, 52, 15, 15, theme.BLUE)
        gfx_lores.text(44, 55, theme.PAPER, iso:"<")
        draw_month_name(59, 55, theme.INK)
        gfx_lores.text(135, 55, theme.INK, conv.str_uw(current_year))
        gfx_lores.fillrect(175, 52, 15, 15, theme.BLUE)
        gfx_lores.text(179, 55, theme.PAPER, iso:">")
    }

    sub previous_month() {
        ubyte previous_days

        if current_month == 1 {
            current_month = 12
            current_year--
        } else
            current_month--

        previous_days = days_in_month()
        first_weekday = (first_weekday + 7 - previous_days % 7) % 7
        selected_day = 1
    }

    sub next_month() {
        ubyte old_days = days_in_month()

        first_weekday = (first_weekday + old_days % 7) % 7
        if current_month == 12 {
            current_month = 1
            current_year++
        } else
            current_month++
        selected_day = 1
    }

    sub draw_window() {
        ubyte day

        gfx_lores.fillrect(35, 35, 255, 176, theme.INK)
        gfx_lores.fillrect(32, 32, 255, 176, theme.PAPER)
        gfx_lores.rect(32, 32, 255, 176, theme.INK)

        gfx_lores.fillrect(33, 33, 253, 16, theme.BLUE)
        gfx_lores.text(40, 37, theme.PAPER, iso:"CALENDAR")
        gfx_lores.fillrect(266, 35, 15, 12, theme.RED)
        gfx_lores.text(270, 37, theme.PAPER, iso:"X")

        draw_month_heading()
        draw_weekday_headings()

        for day in 1 to days_in_month()
            draw_day(day)

        draw_legend()
        draw_event_panel()

        gfx_lores.fillrect(229, 184, 49, 16, theme.INK)
        gfx_lores.fillrect(227, 182, 49, 16, theme.PAPER)
        gfx_lores.rect(227, 182, 49, 16, theme.BLUE)
        gfx_lores.text(235, 186, theme.INK, iso:"DONE")
    }

    sub draw_weekday_headings() {
        gfx_lores.text(47, 72, theme.BLUE, iso:"S")
        gfx_lores.text(68, 72, theme.BLUE, iso:"M")
        gfx_lores.text(89, 72, theme.BLUE, iso:"T")
        gfx_lores.text(110, 72, theme.BLUE, iso:"W")
        gfx_lores.text(131, 72, theme.BLUE, iso:"T")
        gfx_lores.text(152, 72, theme.BLUE, iso:"F")
        gfx_lores.text(173, 72, theme.BLUE, iso:"S")
    }

    sub draw_day(ubyte day) {
        ubyte calendar_slot = first_weekday + day - 1
        ubyte column = calendar_slot % 7
        ubyte row = calendar_slot / 7
        uword x = 41 + column * 21
        ubyte y = 81 + row * 16
        ubyte event_slot = event_slot_for(day)
        ubyte event_type = EVENT_NONE

        if event_slot != NO_EVENT_SLOT
            event_type = event_types[event_slot]

        ubyte face_color = color_for_event(event_type)
        ubyte text_color = theme.INK

        if event_type != EVENT_NONE
            text_color = theme.PAPER

        gfx_lores.fillrect(x, y, 20, 15, face_color)
        gfx_lores.rect(x, y, 20, 15, theme.SOFT_BLUE)
        gfx_lores.text(x + 2, y + 3, text_color, conv.str_ub(day))

        ; Gold selection edge remains visible over every event color.
        if day == selected_day
            gfx_lores.rect(x, y, 20, 15, theme.GOLD)
    }

    sub draw_legend() {
        gfx_lores.fillrect(42, 187, 7, 7, theme.RED)
        gfx_lores.text(52, 186, theme.INK, iso:"APPT")
        gfx_lores.fillrect(89, 187, 7, 7, theme.BLUE)
        gfx_lores.text(99, 186, theme.INK, iso:"TASK")
        gfx_lores.fillrect(136, 187, 7, 7, theme.GREEN)
        gfx_lores.text(146, 186, theme.INK, iso:"PERSONAL")
    }

    sub draw_event_panel() {
        ubyte event_slot = event_slot_for(selected_day)
        ubyte event_type = EVENT_NONE

        if event_slot != NO_EVENT_SLOT
            event_type = event_types[event_slot]

        gfx_lores.fillrect(193, 57, 85, 119, theme.NAVY)
        gfx_lores.text(201, 62, theme.SOFT_BLUE, iso:"SELECTED")
        gfx_lores.text(201, 75, theme.PAPER, iso:"DAY")
        gfx_lores.text(241, 75, theme.PAPER, conv.str_ub(selected_day))

        when event_type {
            EVENT_NONE -> gfx_lores.text(201, 88, theme.PAPER, iso:"NO EVENT")
            EVENT_APPOINTMENT -> gfx_lores.text(201, 88, theme.RED, iso:"APPOINT")
            EVENT_TASK -> gfx_lores.text(201, 88, theme.SOFT_BLUE, iso:"TASK")
            EVENT_PERSONAL -> gfx_lores.text(201, 88, theme.GREEN, iso:"PERSONAL")
        }

        draw_event_button(198, 104, theme.RED, iso:"APPT")
        draw_event_button(198, 123, theme.BLUE, iso:"TASK")
        draw_event_button(198, 142, theme.GREEN, iso:"PERSONAL")
        draw_event_button(198, 161, theme.PAPER, iso:"REMOVE")
    }

    sub draw_event_button(uword x, ubyte y, ubyte color, str label) {
        gfx_lores.fillrect(x, y, 74, 15, color)
        gfx_lores.rect(x, y, 74, 15, theme.PAPER)
        gfx_lores.text(x + 7, y + 4, theme.INK, label)
    }

    sub day_at_pointer() -> ubyte {
        ubyte day
        ubyte slot
        ubyte column
        ubyte row
        uword x
        ubyte y

        for day in 1 to 31 {
            if day > days_in_month()
                return 0

            slot = first_weekday + day - 1
            column = slot % 7
            row = slot / 7
            x = 41 + column * 21
            y = 81 + row * 16

            if input.inside(x, y, 20, 15)
                return day
        }
        return 0
    }

    sub set_selected_event_type(ubyte event_type) {
        ubyte event_slot = ensure_selected_event(event_type)

        if event_slot == NO_EVENT_SLOT
            return

        ; New events receive a useful starting title. The user can immediately
        ; replace it in the Event Details window.
        if event_title_length(event_slot) == 0 {
            when event_type {
                EVENT_APPOINTMENT -> copy_event_title(event_slot, iso:"NEW APPOINTMENT")
                EVENT_TASK -> copy_event_title(event_slot, iso:"NEW TASK")
                EVENT_PERSONAL -> copy_event_title(event_slot, iso:"PERSONAL EVENT")
            }
        }
    }

    sub remove_selected_event() {
        ubyte event_slot = event_slot_for(selected_day)

        if event_slot != NO_EVENT_SLOT {
            event_types[event_slot] = EVENT_NONE
            clear_event_title(event_slot)
        }
    }

    sub draw_event_editor() {
        ubyte event_slot = event_slot_for(selected_day)
        ubyte event_type = EVENT_NONE

        if event_slot != NO_EVENT_SLOT
            event_type = event_types[event_slot]

        ; This smaller window sits above the month view, making the connection
        ; between the clicked date and its event obvious.
        gfx_lores.fillrect(61, 61, 210, 132, theme.INK)
        gfx_lores.fillrect(58, 58, 210, 132, theme.PAPER)
        gfx_lores.rect(58, 58, 210, 132, theme.INK)

        gfx_lores.fillrect(59, 59, 208, 16, theme.BLUE)
        gfx_lores.text(66, 63, theme.PAPER, iso:"EVENT DETAILS")
        gfx_lores.fillrect(247, 61, 15, 12, theme.RED)
        gfx_lores.text(251, 63, theme.PAPER, iso:"X")

        draw_month_name(70, 81, theme.BLUE)
        gfx_lores.text(153, 81, theme.INK, conv.str_ub(selected_day))

        ; Editable title field
        gfx_lores.fillrect(69, 94, 188, 22, theme.INK)
        draw_event_title_field()

        gfx_lores.text(70, 119, theme.BLUE, iso:"TYPE")
        draw_editor_type_button(70, 130, 54, theme.RED, iso:"APPT",
                                event_type == EVENT_APPOINTMENT)
        draw_editor_type_button(129, 130, 54, theme.BLUE, iso:"TASK",
                                event_type == EVENT_TASK)
        draw_editor_type_button(188, 130, 68, theme.GREEN, iso:"PERSON",
                                event_type == EVENT_PERSONAL)

        draw_editor_action(70, 162, 67, iso:"DELETE")
        draw_editor_action(193, 162, 63, iso:"DONE")
    }

    sub draw_editor_type_button(uword x, ubyte y, ubyte width, ubyte color,
                                str label, bool selected) {
        gfx_lores.fillrect(x, y, width, 19, color)
        if selected
            gfx_lores.rect(x, y, width, 19, theme.GOLD)
        else
            gfx_lores.rect(x, y, width, 19, theme.INK)
        gfx_lores.text(x + 7, y + 6, theme.INK, label)
    }

    sub draw_editor_action(uword x, ubyte y, ubyte width, str label) {
        gfx_lores.fillrect(x + 2, y + 2, width, 18, theme.INK)
        gfx_lores.fillrect(x, y, width, 18, theme.PAPER)
        gfx_lores.rect(x, y, width, 18, theme.BLUE)
        gfx_lores.text(x + 8, y + 5, theme.INK, label)
    }

    sub edit_event_title(ubyte key) {
        ubyte event_slot = event_slot_for(selected_day)
        ubyte length = 0

        if event_slot != NO_EVENT_SLOT
            length = event_title_length(event_slot)

        if key == $14 {
            if length > 0
                set_event_title_character(event_slot, length - 1, 0)
            return
        }

        if key >= 32 and key <= 126 and length < 19 {
            if event_slot == NO_EVENT_SLOT
                event_slot = ensure_selected_event(EVENT_PERSONAL)

            if event_slot == NO_EVENT_SLOT
                return

            set_event_title_character(event_slot, length, key)
            set_event_title_character(event_slot, length + 1, 0)

            ; Typing into an empty day creates a personal event by default.
            ; The colored type buttons can change that with one click.
            if event_types[event_slot] == EVENT_NONE
                event_types[event_slot] = EVENT_PERSONAL
        }
    }

    sub open_event_editor() {
        bool close_editor = false

        draw_event_editor()

        do {
            sys.waitvsync()
            input.poll()

            if input.left_pressed() {
                if input.inside(70, 130, 54, 19) {
                    set_selected_event_type(EVENT_APPOINTMENT)
                    draw_event_editor()
                } else if input.inside(129, 130, 54, 19) {
                    set_selected_event_type(EVENT_TASK)
                    draw_event_editor()
                } else if input.inside(188, 130, 68, 19) {
                    set_selected_event_type(EVENT_PERSONAL)
                    draw_event_editor()
                } else if input.inside(70, 162, 67, 18) {
                    remove_selected_event()
                    draw_event_editor()
                } else if input.inside(193, 162, 63, 18) or
                          input.inside(247, 61, 15, 12) {
                    close_editor = true
                }
            }

            if input.key != 0 and input.key != $1b {
                edit_event_title(input.key)
                draw_event_title_field()
            }
        } until close_editor or input.key == $1b

        ; Do not let Escape leak into the month window and close both layers.
        input.key = 0
    }

    sub open() {
        bool close_window = false
        ubyte clicked_day

        initialize()
        draw_window()

        do {
            sys.waitvsync()
            input.poll()

            if input.left_pressed() {
                clicked_day = day_at_pointer()

                if input.inside(40, 52, 15, 15) {
                    previous_month()
                    draw_window()
                } else if input.inside(175, 52, 15, 15) {
                    next_month()
                    draw_window()
                ; Clicking any date, including a colored one, displays its
                ; current event in a small editable details window.
                } else if clicked_day != 0 {
                    selected_day = clicked_day
                    open_event_editor()
                    draw_window()
                } else if input.inside(198, 104, 74, 15) {
                    set_selected_event_type(EVENT_APPOINTMENT)
                    draw_window()
                } else if input.inside(198, 123, 74, 15) {
                    set_selected_event_type(EVENT_TASK)
                    draw_window()
                } else if input.inside(198, 142, 74, 15) {
                    set_selected_event_type(EVENT_PERSONAL)
                    draw_window()
                } else if input.inside(198, 161, 74, 15) {
                    remove_selected_event()
                    draw_window()
                } else if input.inside(266, 35, 15, 12) or
                          input.inside(227, 182, 49, 16) {
                    close_window = true
                }
            }
        } until close_window or input.key == $1b

        save_state()

    }
}
