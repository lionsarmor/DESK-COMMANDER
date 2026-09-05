%import gfx_lores
%import input
%import strings
%import theme

; -----------------------------------------------------------------------------
; Notes application
; -----------------------------------------------------------------------------
;
; V1 starts with four short in-memory notes. This is intentionally small and
; easy to understand. A later storage milestone can replace these buffers with
; disk-backed records without changing the window or input behavior.

notes_app {
    bool initialized
    bool note_one_active
    bool note_two_active
    bool note_three_active
    bool note_four_active

    ubyte selected_note
    ubyte[29] note_one
    ubyte[29] note_two
    ubyte[29] note_three
    ubyte[29] note_four

    sub initialize() {
        if initialized
            return

        void strings.copy(iso:"PLAN DESK COMMANDER V1", note_one)
        void strings.copy(iso:"TRY CALENDAR COLORS", note_two)
        void strings.copy(iso:"BUILD FILE MANAGER", note_three)

        note_one_active = true
        note_two_active = true
        note_three_active = true
        note_four_active = false
        selected_note = 1
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

        draw_button(41, 179, 55, iso:"ADD")
        draw_button(104, 179, 68, iso:"DELETE")
        draw_button(220, 179, 58, iso:"DONE")
    }

    sub draw_note_rows() {
        ; Editing a note only repaints these four rows. The frame, title bar,
        ; instructions, and buttons remain untouched and therefore steady.
        draw_note_row(75, 1, note_one, note_one_active)
        draw_note_row(99, 2, note_two, note_two_active)
        draw_note_row(123, 3, note_three, note_three_active)
        draw_note_row(147, 4, note_four, note_four_active)
    }

    sub draw_note_row(ubyte y, ubyte number, str note, bool active) {
        ubyte face_color = theme.PAPER
        ubyte text_color = theme.INK

        if number == selected_note {
            face_color = theme.SOFT_BLUE
            text_color = theme.NAVY
        }

        gfx_lores.fillrect(41, y, 237, 20, face_color)
        gfx_lores.rect(41, y, 237, 20, theme.BLUE)

        if active {
            gfx_lores.fillrect(47, y + 6, 7, 7, theme.BLUE)
            gfx_lores.text(61, y + 6, text_color, note)
        } else {
            gfx_lores.text(61, y + 6, theme.SOFT_BLUE, iso:"EMPTY NOTE")
        }
    }

    sub draw_button(uword x, ubyte y, ubyte width, str label) {
        gfx_lores.fillrect(x + 1, y + 1, width, 16, theme.INK)
        gfx_lores.fillrect(x, y, width, 16, theme.PAPER)
        gfx_lores.rect(x, y, width, 16, theme.BLUE)
        gfx_lores.text(x + 8, y + 4, theme.INK, label)
    }

    sub note_at_pointer() -> ubyte {
        if input.inside(41, 75, 237, 20)
            return 1
        if input.inside(41, 99, 237, 20)
            return 2
        if input.inside(41, 123, 237, 20)
            return 3
        if input.inside(41, 147, 237, 20)
            return 4
        return 0
    }

    sub add_note() {
        ; Reuse the first empty slot and immediately place keyboard focus there.
        if note_one_active == false {
            note_one[0] = 0
            note_one_active = true
            selected_note = 1
        } else if note_two_active == false {
            note_two[0] = 0
            note_two_active = true
            selected_note = 2
        } else if note_three_active == false {
            note_three[0] = 0
            note_three_active = true
            selected_note = 3
        } else if note_four_active == false {
            note_four[0] = 0
            note_four_active = true
            selected_note = 4
        }
    }

    sub delete_selected_note() {
        when selected_note {
            1 -> {
                note_one[0] = 0
                note_one_active = false
            }
            2 -> {
                note_two[0] = 0
                note_two_active = false
            }
            3 -> {
                note_three[0] = 0
                note_three_active = false
            }
            4 -> {
                note_four[0] = 0
                note_four_active = false
            }
        }
        selected_note = 0
    }

    sub edit_selected_note(ubyte key) {
        when selected_note {
            1 -> edit_buffer(note_one, key)
            2 -> edit_buffer(note_two, key)
            3 -> edit_buffer(note_three, key)
            4 -> edit_buffer(note_four, key)
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
        if key >= 32 and key <= 126 and length < 27 {
            buffer[length] = key
            buffer[length + 1] = 0
        }
    }

    sub open() {
        bool close_window = false
        ubyte clicked_note

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
                } else if input.inside(104, 179, 68, 16) {
                    delete_selected_note()
                    draw_note_rows()
                } else if input.inside(220, 179, 58, 16) or
                          input.inside(266, 39, 15, 12) {
                    close_window = true
                }
            }

            if input.key != 0 and input.key != $1b and selected_note != 0 {
                edit_selected_note(input.key)
                draw_note_rows()
            }
        } until close_window or input.key == $1b
    }
}
