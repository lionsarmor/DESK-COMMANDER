%import gfx_lores
%import input
%import state_data
%import strings
%import theme

; -----------------------------------------------------------------------------
; Notes application
; -----------------------------------------------------------------------------
;
; Six short notes live in the shared SD-backed state image. Four are visible at
; once; the wheel, cursor keys, and scrollbar move through the complete list.

notes_app {
    bool initialized
    ubyte selected_note
    const ubyte NOTE_COUNT = 6
    const ubyte VISIBLE_ROWS = 4
    const ubyte NOTE_SIZE = 22
    ubyte scroll_offset
    ubyte[6] note_active
    ubyte[132] note_text

    sub note_buffer(ubyte number) -> str {
        return &note_text + ((number - 1) as uword) * NOTE_SIZE
    }

    sub save_state() {
        ; Notes executes from bank 11, so copy bytes to VERA here while this
        ; bank is visible. A bank-10 bulk copier cannot see bank-11 variables.
        ubyte index
        state_data.write(state_data.NOTES, $a8)
        for index in 0 to 5
            state_data.write(state_data.NOTES + 1 + index, note_active[index])
        for index in 0 to 131
            state_data.write(state_data.NOTES + 7 + index, note_text[index])
        state_data.save()
    }

    sub initialize() {
        if initialized
            return

        if state_data.read(state_data.NOTES) == $a8 {
            ubyte index
            for index in 0 to 5
                note_active[index] = state_data.read(state_data.NOTES + 1 + index)
            for index in 0 to 131
                note_text[index] = state_data.read(state_data.NOTES + 7 + index)
        } else {
            void strings.copy(iso:"PLAN DESK COMMANDER", note_buffer(1))
            void strings.copy(iso:"TRY CALENDAR COLORS", note_buffer(2))
            void strings.copy(iso:"BUILD FILE MANAGER", note_buffer(3))
            note_active[0] = 1
            note_active[1] = 1
            note_active[2] = 1
            note_active[3] = 0
            note_active[4] = 0
            note_active[5] = 0
            save_state()
        }
        selected_note = 1
        scroll_offset = 0
        initialized = true
    }

    sub draw_window() {
        ; Large modal window with enough room for readable note rows.
        gfx_lores.fillrect(35, 39, 255, 168, theme.INK)
        gfx_lores.fillrect(32, 36, 255, 168, theme.PAPER)
        gfx_lores.rect(32, 36, 255, 168, theme.INK)

        gfx_lores.fillrect(33, 37, 253, 16, theme.BLUE)
        gfx_lores.text(40, 41, theme.PAPER, iso:"NOTES")
        gfx_lores.fillrect(266, 39, 15, 12, theme.RED)
        gfx_lores.text(270, 41, theme.PAPER, iso:"X")

        gfx_lores.text(41, 59, theme.BLUE, iso:"SELECT A NOTE, THEN TYPE")

        draw_note_rows()
        draw_scrollbar()

        draw_button(41, 179, 55, iso:"ADD")
        draw_button(104, 179, 68, iso:"DELETE")
        draw_button(220, 179, 58, iso:"DONE")
    }

    sub draw_note_rows() {
        ; Editing a note only repaints these four rows. The frame, title bar,
        ; instructions, and buttons remain untouched and therefore steady.
        ubyte row
        ubyte number
        for row in 0 to VISIBLE_ROWS - 1 {
            number = scroll_offset + row + 1
            draw_note_row(75 + row * 24, number, note_buffer(number),
                          note_active[number - 1] != 0)
        }
    }

    sub draw_note_row(ubyte y, ubyte number, str note, bool active) {
        ubyte face_color = theme.PAPER
        ubyte text_color = theme.INK

        if number == selected_note {
            face_color = theme.SOFT_BLUE
            text_color = theme.NAVY
        }

        gfx_lores.fillrect(41, y, 220, 20, face_color)
        gfx_lores.rect(41, y, 220, 20, theme.BLUE)

        if active {
            gfx_lores.fillrect(47, y + 6, 7, 7, theme.BLUE)
            gfx_lores.text(61, y + 6, text_color, note)
        } else if number == selected_note
            gfx_lores.text(61, y + 6, theme.NAVY, iso:"EMPTY NOTE")
        else
            gfx_lores.text(61, y + 6, theme.SOFT_BLUE, iso:"EMPTY NOTE")
    }

    sub draw_scrollbar() {
        ; With six notes and four visible rows, the thumb has three stable
        ; positions. Repainting only this narrow strip keeps scrolling calm.
        gfx_lores.fillrect(266, 75, 12, 92, theme.SOFT_BLUE)
        gfx_lores.rect(266, 75, 12, 92, theme.BLUE)
        gfx_lores.fillrect(268, 77 + scroll_offset * 23, 8, 42, theme.BLUE)
    }

    sub draw_button(uword x, ubyte y, ubyte width, str label) {
        gfx_lores.fillrect(x + 1, y + 1, width, 16, theme.INK)
        gfx_lores.fillrect(x, y, width, 16, theme.PAPER)
        gfx_lores.rect(x, y, width, 16, theme.BLUE)
        gfx_lores.text(x + 8, y + 4, theme.INK, label)
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

    sub scroll_up() {
        if scroll_offset > 0
            scroll_offset--
    }

    sub scroll_down() {
        if scroll_offset < NOTE_COUNT - VISIBLE_ROWS
            scroll_offset++
    }

    sub move_selection(bool down) {
        if down and selected_note < NOTE_COUNT
            selected_note++
        else if not down and selected_note > 1
            selected_note--
        keep_selected_visible()
    }

    sub add_note() {
        ; Reuse the first empty slot and immediately place keyboard focus there.
        ubyte slot
        uword buffer
        for slot in 0 to NOTE_COUNT - 1 {
            if note_active[slot] == 0 {
                buffer = note_buffer(slot + 1)
                buffer[0] = 0
                note_active[slot] = 1
                selected_note = slot + 1
                keep_selected_visible()
                return
            }
        }
    }

    sub delete_selected_note() {
        if selected_note > 0 {
            uword buffer = note_buffer(selected_note)
            buffer[0] = 0
            note_active[selected_note - 1] = 0
        }
        selected_note = 0
    }

    sub edit_selected_note(ubyte key) {
        if selected_note > 0 {
            if key >= 32 and key <= 126
                note_active[selected_note - 1] = 1
            edit_buffer(note_buffer(selected_note), key)
        }
    }

    sub edit_buffer(str buffer, ubyte key) {
        ubyte length = strings.length(buffer)

        ; PETSCII Delete/Backspace is $14 on the Commander X16.
        if key == $14 {
            if length > 0
                buffer[length - 1] = 0
            return
        }

        ; Short printable notes fit the width of one row. Return simply ends
        ; the current typing action; clicking another row changes focus.
        if key >= 32 and key <= 126 and length < NOTE_SIZE - 1 {
            buffer[length] = key
            buffer[length + 1] = 0
        }
    }

    sub open() {
        bool close_window = false
        ubyte clicked_note
        ubyte old_offset

        initialize()
        draw_window()

        do {
            sys.waitvsync()
            input.poll()

            if input.left_pressed() {
                clicked_note = note_at_pointer()

                if clicked_note != 0 {
                    selected_note = clicked_note
                    draw_note_rows()
                } else if input.inside(41, 179, 55, 16) {
                    add_note()
                    draw_note_rows()
                    draw_scrollbar()
                } else if input.inside(104, 179, 68, 16) {
                    delete_selected_note()
                    draw_note_rows()
                } else if input.inside(220, 179, 58, 16) or
                          input.inside(266, 39, 15, 12) {
                    close_window = true
                }
            }

            if input.wheel > 0 {
                old_offset = scroll_offset
                scroll_up()
                if old_offset != scroll_offset {
                    draw_note_rows()
                    draw_scrollbar()
                }
            } else if input.wheel < 0 {
                old_offset = scroll_offset
                scroll_down()
                if old_offset != scroll_offset {
                    draw_note_rows()
                    draw_scrollbar()
                }
            }

            if input.key == $11 {
                move_selection(true)
                draw_note_rows()
                draw_scrollbar()
            } else if input.key == $91 {
                move_selection(false)
                draw_note_rows()
                draw_scrollbar()
            } else if input.key != 0 and input.key != $1b and selected_note != 0 {
                edit_selected_note(input.key)
                draw_note_rows()
            }
        } until close_window or input.key == $1b

        ; Committing on app close avoids writing the SD card for every keypress.
        save_state()
    }
}
