%import gfx_lores
%import input
%import state_data
%import strings
%import theme

; -----------------------------------------------------------------------------
; Notes application
; -----------------------------------------------------------------------------
;
; Six titled notes live in the shared SD-backed state image. Each note has a
; short list title and a 108-character multiline body. Editing is transactional:
; Save commits both fields, while Cancel/Escape leaves the old note untouched.

notes_app {
    extsub @bank 20 $a000 = open_note_reader() clobbers(X, Y) -> bool @A
    const ubyte NOTE_COUNT = 6
    const ubyte VISIBLE_ROWS = 4
    const ubyte TITLE_SIZE = 22
    const ubyte BODY_SIZE = 109
    const ubyte BODY_COLUMNS = 27
    const ubyte BODY_ROWS = 4

    const ubyte FOCUS_LIST = 0
    const ubyte FOCUS_ADD = 1
    const ubyte FOCUS_EDIT = 2
    const ubyte FOCUS_DELETE = 3
    const ubyte FOCUS_DONE = 4

    bool initialized
    ubyte selected_note
    ubyte scroll_offset
    ubyte focus_item
    ubyte status_message
    ubyte[6] note_active
    ubyte[132] note_title
    ubyte[22] edit_title
    ubyte[109] edit_body
    ubyte[28] line_buffer

    sub title_buffer(ubyte number) -> str {
        return &note_title + ((number - 1) as uword) * TITLE_SIZE
    }

    sub body_address(ubyte number) -> uword {
        return state_data.NOTES_BODY + 1 +
               ((number - 1) as uword) * BODY_SIZE
    }

    sub copy_text(str source, str destination, ubyte maximum) {
        ubyte index = 0
        while source[index] != 0 and index < maximum {
            destination[index] = source[index]
            index++
        }
        destination[index] = 0
    }

    sub save_state() {
        ; Notes executes from bank 11, so copy bytes to VERA here while this
        ; bank is visible. A bank-10 copier cannot see bank-11 variables.
        ubyte index
        state_data.write(state_data.NOTES, $a9)
        for index in 0 to 5
            state_data.write(state_data.NOTES + 1 + index, note_active[index])
        for index in 0 to 131
            state_data.write(state_data.NOTES + 7 + index, note_title[index])

        state_data.save()
    }

    sub initialize() {
        ubyte index
        ubyte note
        uword title

        if initialized
            return

        if state_data.read(state_data.NOTES) == $a8 or
           state_data.read(state_data.NOTES) == $a9 {
            for index in 0 to 5
                note_active[index] = state_data.read(state_data.NOTES + 1 + index)
            for index in 0 to 131
                note_title[index] = state_data.read(state_data.NOTES + 7 + index)
        } else {
            ; Production first run is private and blank. Demo notes are no
            ; longer installed implicitly.
            for index in 0 to 5
                note_active[index] = 0
            for index in 0 to 131
                note_title[index] = 0
        }

        if state_data.read(state_data.NOTES_BODY) != $a9 {
            ; Migrate old one-line notes by using their text as both title and
            ; initial body. No existing user note disappears in the V2 move.
            for note in 1 to NOTE_COUNT {
                for index in 0 to BODY_SIZE - 1
                    state_data.write(body_address(note) + index, 0)
                if note_active[note - 1] != 0 {
                    title = title_buffer(note)
                    index = 0
                    while title[index] != 0 and
                          index < BODY_SIZE - 1 {
                        state_data.write(body_address(note) + index,
                                         title[index])
                        index++
                    }
                }
            }
            state_data.write(state_data.NOTES_BODY, $a9)
            save_state()
        }

        selected_note = 1
        scroll_offset = 0
        focus_item = FOCUS_LIST
        status_message = 0
        initialized = true
    }

    sub draw_window() {
        gfx_lores.fillrect(35, 39, 255, 168, theme.INK)
        gfx_lores.fillrect(32, 36, 255, 168, theme.PAPER)
        gfx_lores.rect(32, 36, 255, 168, theme.INK)

        gfx_lores.fillrect(33, 37, 253, 16, theme.BLUE)
        gfx_lores.text(40, 41, theme.PAPER, iso:"NOTES")
        gfx_lores.fillrect(266, 39, 15, 12, theme.RED)
        gfx_lores.text(270, 41, theme.PAPER, iso:"X")

        when status_message {
            1 -> gfx_lores.text(41, 59, theme.GREEN, iso:"NOTE SAVED")
            2 -> gfx_lores.text(41, 59, theme.GREEN, iso:"NOTE DELETED")
            3 -> gfx_lores.text(41, 59, theme.RED, iso:"NOTES FULL")
            4 -> gfx_lores.text(41, 59, theme.RED, iso:"DELETE AGAIN TO CONFIRM")
            else -> gfx_lores.text(41, 59, theme.BLUE,
                                   iso:"SELECT A NOTE TO EDIT")
        }

        draw_note_rows()
        draw_scrollbar()
        draw_actions()
    }

    sub draw_note_rows() {
        ubyte row
        ubyte number
        for row in 0 to VISIBLE_ROWS - 1 {
            number = scroll_offset + row + 1
            draw_note_row(75 + row * 24, number, title_buffer(number),
                          note_active[number - 1] != 0)
        }
    }

    sub draw_note_row(ubyte y, ubyte number, str title, bool active) {
        ubyte face_color = theme.PAPER
        ubyte text_color = theme.INK
        ubyte border_color = theme.BLUE

        if number == selected_note {
            face_color = theme.SOFT_BLUE
            text_color = theme.NAVY
            if focus_item == FOCUS_LIST
                border_color = theme.GREEN
        }

        gfx_lores.fillrect(41, y, 220, 20, face_color)
        gfx_lores.rect(41, y, 220, 20, border_color)

        if active {
            gfx_lores.fillrect(47, y + 6, 7, 7, theme.BLUE)
            gfx_lores.text(61, y + 6, text_color, title)
        } else if number == selected_note
            gfx_lores.text(61, y + 6, theme.NAVY, iso:"EMPTY NOTE")
        else
            gfx_lores.text(61, y + 6, theme.SOFT_BLUE, iso:"EMPTY NOTE")
    }

    sub draw_scrollbar() {
        gfx_lores.fillrect(266, 75, 12, 92, theme.SOFT_BLUE)
        gfx_lores.rect(266, 75, 12, 92, theme.BLUE)
        gfx_lores.fillrect(268, 77 + scroll_offset * 23, 8, 42, theme.BLUE)
    }

    sub draw_button(uword x, ubyte width, str label, ubyte item) {
        ubyte border_color = theme.BLUE
        if focus_item == item
            border_color = theme.GREEN
        gfx_lores.fillrect(x + 1, 180, width, 16, theme.INK)
        gfx_lores.fillrect(x, 179, width, 16, theme.PAPER)
        gfx_lores.rect(x, 179, width, 16, border_color)
        gfx_lores.text(x + 7, 183, theme.INK, label)
    }

    sub draw_actions() {
        draw_button(41, 42, iso:"ADD", FOCUS_ADD)
        draw_button(88, 48, iso:"EDIT", FOCUS_EDIT)
        draw_button(141, 62, iso:"DELETE", FOCUS_DELETE)
        draw_button(220, 58, iso:"DONE", FOCUS_DONE)
    }

    sub note_at_pointer() -> ubyte {
        if input.inside(41, 75, 220, 92)
            return scroll_offset + ((input.mouse_y - 75) / 24) as ubyte + 1
        return 0
    }

    sub keep_selected_visible() {
        if selected_note <= scroll_offset
            scroll_offset = selected_note - 1
        else if selected_note > scroll_offset + VISIBLE_ROWS
            scroll_offset = selected_note - VISIBLE_ROWS
    }

    sub move_selection(bool down) {
        status_message = 0
        if down and selected_note < NOTE_COUNT
            selected_note++
        else if not down and selected_note > 1
            selected_note--
        keep_selected_visible()
    }

    sub draw_dialog_button(uword x, ubyte width, str label, bool focused) {
        ubyte face_color = theme.PAPER
        ubyte border_color = theme.BLUE
        if focused {
            face_color = theme.SOFT_BLUE
            border_color = theme.GREEN
        }
        gfx_lores.fillrect(x, 157, width, 18, face_color)
        gfx_lores.rect(x, 157, width, 18, border_color)
        gfx_lores.text(x + 15, 162, theme.INK, label)
    }

    sub draw_title_field() {
        gfx_lores.fillrect(54, 102, 212, 22, theme.INK)
        gfx_lores.fillrect(57, 105, 206, 16, theme.PAPER)
        if strings.length(edit_title) == 0
            gfx_lores.text(62, 109, theme.SOFT_BLUE, iso:"TYPE A TITLE")
        else
            gfx_lores.text(62, 109, theme.INK, edit_title)
    }

    sub ask_title(str heading) -> bool {
        bool accepted = false
        bool finished = false
        ubyte length

        gfx_lores.fillrect(41, 70, 238, 111, theme.INK)
        gfx_lores.fillrect(38, 67, 238, 111, theme.PAPER)
        gfx_lores.rect(38, 67, 238, 111, theme.INK)
        gfx_lores.fillrect(39, 68, 236, 18, theme.BLUE)
        gfx_lores.text(47, 73, theme.PAPER, heading)
        gfx_lores.text(54, 92, theme.BLUE, iso:"TITLE")
        draw_title_field()
        draw_dialog_button(58, 72, iso:"SAVE", true)
        draw_dialog_button(177, 80, iso:"CANCEL", false)

        do {
            sys.waitvsync()
            input.poll()
            length = strings.length(edit_title)
            if input.key == $14 {
                if length > 0
                    edit_title[length - 1] = 0
                draw_title_field()
            } else if input.key >= 32 and input.key <= 126 and
                      length < TITLE_SIZE - 1 {
                edit_title[length] = input.key
                edit_title[length + 1] = 0
                draw_title_field()
            } else if input.key == $0d and length > 0 {
                accepted = true
                finished = true
            }

            if input.left_pressed() {
                if input.inside(58, 157, 72, 18) and length > 0 {
                    accepted = true
                    finished = true
                } else if input.inside(177, 157, 80, 18)
                    finished = true
            }
        } until finished or input.key == $1b
        input.key = 0
        return accepted
    }

    sub draw_body_field() {
        ubyte row
        ubyte column
        ubyte position = 0

        gfx_lores.fillrect(50, 87, 220, 61, theme.INK)
        gfx_lores.fillrect(53, 90, 214, 55, theme.PAPER)
        for row in 0 to BODY_ROWS - 1 {
            column = 0
            while column < BODY_COLUMNS and edit_body[position] != 0 and
                  edit_body[position] != $0d {
                line_buffer[column] = edit_body[position]
                column++
                position++
            }
            line_buffer[column] = 0
            if column > 0
                gfx_lores.text(55, 93 + row * 12, theme.INK, line_buffer)
            if edit_body[position] == $0d
                position++
        }
    }

    sub ask_body() -> bool {
        bool accepted = false
        bool finished = false
        ubyte dialog_focus = 0
        ubyte length

        gfx_lores.fillrect(37, 51, 246, 134, theme.INK)
        gfx_lores.fillrect(34, 48, 246, 134, theme.PAPER)
        gfx_lores.rect(34, 48, 246, 134, theme.INK)
        gfx_lores.fillrect(35, 49, 244, 18, theme.BLUE)
        gfx_lores.text(43, 54, theme.PAPER, iso:"EDIT NOTE BODY")
        gfx_lores.text(50, 74, theme.BLUE, iso:"TAB THEN ENTER TO SAVE")
        draw_body_field()
        draw_dialog_button(53, 72, iso:"SAVE", false)
        draw_dialog_button(177, 80, iso:"CANCEL", false)

        do {
            sys.waitvsync()
            input.poll()
            length = strings.length(edit_body)

            if input.key == $09 {
                dialog_focus++
                if dialog_focus > 2
                    dialog_focus = 0
                draw_dialog_button(53, 72, iso:"SAVE", dialog_focus == 1)
                draw_dialog_button(177, 80, iso:"CANCEL", dialog_focus == 2)
            } else if input.key == $14 and dialog_focus == 0 {
                if length > 0
                    edit_body[length - 1] = 0
                draw_body_field()
            } else if input.key == $0d {
                if dialog_focus == 1 {
                    accepted = true
                    finished = true
                } else if dialog_focus == 2
                    finished = true
                else if length < BODY_SIZE - 1 {
                    edit_body[length] = $0d
                    edit_body[length + 1] = 0
                    draw_body_field()
                }
            } else if input.key >= 32 and input.key <= 126 and
                      dialog_focus == 0 and length < BODY_SIZE - 1 {
                edit_body[length] = input.key
                edit_body[length + 1] = 0
                draw_body_field()
            }

            if input.left_pressed() {
                if input.inside(53, 157, 72, 18) {
                    accepted = true
                    finished = true
                } else if input.inside(177, 157, 80, 18)
                    finished = true
                else if input.inside(50, 87, 220, 61)
                    dialog_focus = 0
            }
        } until finished or input.key == $1b
        input.key = 0
        return accepted
    }

    sub edit_note(bool creating) {
        ubyte slot = selected_note
        ubyte index

        if creating {
            slot = 1
            while slot <= NOTE_COUNT and note_active[slot - 1] != 0
                slot++
            if slot > NOTE_COUNT {
                status_message = 3
                return
            }
            edit_title[0] = 0
            edit_body[0] = 0
        } else {
            if selected_note == 0 or note_active[selected_note - 1] == 0
                return
            copy_text(title_buffer(selected_note), edit_title, TITLE_SIZE - 1)
            index = 0
            while state_data.read(body_address(selected_note) + index) != 0 and
                  index < BODY_SIZE - 1 {
                edit_body[index] = state_data.read(
                    body_address(selected_note) + index)
                index++
            }
            edit_body[index] = 0
        }

        if creating {
            if not ask_title(iso:"NEW NOTE")
                return
        } else if not ask_title(iso:"EDIT NOTE")
            return
        if not ask_body()
            return

        copy_text(edit_title, title_buffer(slot), TITLE_SIZE - 1)
        for index in 0 to BODY_SIZE - 1
            state_data.write(body_address(slot) + index, 0)
        index = 0
        while edit_body[index] != 0 and index < BODY_SIZE - 1 {
            state_data.write(body_address(slot) + index, edit_body[index])
            index++
        }
        note_active[slot - 1] = 1
        selected_note = slot
        keep_selected_visible()
        status_message = 1
        save_state()
    }

    sub delete_selected_note() {
        ubyte index
        uword title = title_buffer(selected_note)
        if selected_note == 0 or note_active[selected_note - 1] == 0
            return
        ; The first press arms deletion without opening a flashing modal. A
        ; second press on the same selected row performs the destructive step.
        if status_message != 4 {
            status_message = 4
            return
        }

        note_active[selected_note - 1] = 0
        title[0] = 0
        for index in 0 to BODY_SIZE - 1
            state_data.write(body_address(selected_note) + index, 0)
        status_message = 2
        save_state()
    }

    sub activate_focus() -> bool {
        when focus_item {
            FOCUS_LIST -> view_note()
            FOCUS_ADD -> edit_note(true)
            FOCUS_EDIT -> edit_note(false)
            FOCUS_DELETE -> delete_selected_note()
            FOCUS_DONE -> return true
        }
        return false
    }

    sub view_note() {
        if note_active[selected_note - 1] == 0
            return
        state_data.organizer_index = selected_note
        if open_note_reader()
            edit_note(false)
    }

    sub open() {
        bool close_window = false
        ubyte clicked_note
        ubyte old_offset

        initialize()
        focus_item = FOCUS_LIST
        status_message = 0
        draw_window()

        do {
            sys.waitvsync()
            input.poll()

            if input.left_pressed() {
                clicked_note = note_at_pointer()
                if clicked_note != 0 {
                    status_message = 0
                    selected_note = clicked_note
                    focus_item = FOCUS_LIST
                    draw_note_rows()
                    draw_actions()
                    if note_active[selected_note - 1] != 0 {
                        view_note()
                        draw_window()
                    }
                } else if input.inside(41, 179, 42, 16) {
                    focus_item = FOCUS_ADD
                    edit_note(true)
                    draw_window()
                } else if input.inside(88, 179, 48, 16) {
                    focus_item = FOCUS_EDIT
                    edit_note(false)
                    draw_window()
                } else if input.inside(141, 179, 62, 16) {
                    focus_item = FOCUS_DELETE
                    delete_selected_note()
                    draw_window()
                } else if input.inside(220, 179, 58, 16) or
                          input.inside(266, 39, 15, 12)
                    close_window = true
            }

            if input.wheel > 0 {
                old_offset = scroll_offset
                if scroll_offset > 0
                    scroll_offset--
                if old_offset != scroll_offset {
                    draw_note_rows()
                    draw_scrollbar()
                }
            } else if input.wheel < 0 {
                old_offset = scroll_offset
                if scroll_offset < NOTE_COUNT - VISIBLE_ROWS
                    scroll_offset++
                if old_offset != scroll_offset {
                    draw_note_rows()
                    draw_scrollbar()
                }
            }

            if input.key == $09 {
                focus_item++
                if focus_item > FOCUS_DONE
                    focus_item = FOCUS_LIST
                draw_note_rows()
                draw_actions()
            } else if input.key == $11 and focus_item == FOCUS_LIST {
                move_selection(true)
                draw_note_rows()
                draw_scrollbar()
            } else if input.key == $91 and focus_item == FOCUS_LIST {
                move_selection(false)
                draw_note_rows()
                draw_scrollbar()
            } else if input.key == $9d and focus_item > FOCUS_ADD {
                focus_item--
                draw_actions()
            } else if input.key == $1d and focus_item >= FOCUS_ADD and
                      focus_item < FOCUS_DONE {
                focus_item++
                draw_actions()
            } else if input.key == $0d {
                close_window = activate_focus()
                if not close_window
                    draw_window()
            }
        } until close_window or input.key == $1b

        input.key = 0
    }
}
