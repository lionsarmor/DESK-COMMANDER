%import gfx_lores
%import input
%import state_data
%import strings
%import theme

; Extra organizer UI lives in bank 20 so the already-full application banks
; remain safe on a stock Commander X16.
organizer_extras {
    const ubyte TITLE_SIZE = 22
    const ubyte BODY_SIZE = 109
    const ubyte EMAIL_SIZE = 48
    const ubyte OLD_RECORD_SIZE = 88
    const ubyte NEW_RECORD_SIZE = 116
    ubyte[22] title
    ubyte[109] body
    ubyte[28] line
    ubyte[48] email
    ubyte[33] visible_email
    ubyte[109] row_starts
    ubyte row_count
    ubyte first_row
    bool edit_focused
    ubyte email_cursor

    sub begin_dialog() {
        gfx_lores.eor_mode = false
        ; Input variables are local to each compiled overlay. Seed the helper
        ; from the device and wait for release to prevent click-through.
        do {
            sys.waitvsync()
            input.poll()
        } until input.buttons == 0
        input.key = 0
    }

    sub end_dialog() {
        do {
            sys.waitvsync()
            input.poll()
        } until input.buttons == 0
        input.key = 0
    }

    sub index_body() {
        ubyte position = 0
        ubyte column = 0
        row_count = 1
        row_starts[0] = 0
        first_row = 0
        while position < 108 and body[position] != 0 {
            column++
            if body[position] == $0d or column == 26 {
                ; An explicit newline immediately after a full row belongs
                ; to that row, rather than creating an accidental blank one.
                if body[position] != $0d and body[position + 1] == $0d
                    position++
                row_starts[row_count] = position + 1
                row_count++
                column = 0
            }
            position++
        }
    }

    sub load_text(uword address, str destination, ubyte maximum) {
        ubyte index = 0
        while index < maximum and state_data.read(address + index) != 0 {
            destination[index] = state_data.read(address + index)
            index++
        }
        destination[index] = 0
    }

    sub draw_note_body() {
        ubyte row
        ubyte column
        ubyte position
        gfx_lores.fillrect(48, 83, 224, 66, theme.PAPER)
        for row in 0 to 3 {
            if first_row + row >= row_count
                break
            position = row_starts[first_row + row]
            column = 0
            while column < 26 and position < 108 and body[position] != 0 and body[position] != $0d {
                line[column] = body[position]
                column++
                position++
            }
            line[column] = 0
            gfx_lores.text(54, 89 + row * 13, theme.INK, line)
            if body[position] == $0d
                position++
        }
    }

    sub open_note_reader() -> bool {
        bool done = false
        bool wants_edit = false
        ubyte number = state_data.organizer_index
        begin_dialog()
        if number < 1 or number > 6 return false
        load_text(state_data.NOTES + 7 + ((number - 1) as uword) * TITLE_SIZE,
                  title, 21)
        load_text(state_data.NOTES_BODY + 1 + ((number - 1) as uword) * BODY_SIZE,
                  body, 108)
        index_body()
        edit_focused = false
        gfx_lores.fillrect(37, 43, 246, 143, theme.INK)
        gfx_lores.fillrect(34, 40, 246, 143, theme.PAPER)
        gfx_lores.rect(34, 40, 246, 143, theme.INK)
        gfx_lores.fillrect(35, 41, 244, 20, theme.BLUE)
        gfx_lores.text(43, 47, theme.PAPER, iso:"READ NOTE")
        gfx_lores.text(48, 68, theme.BLUE, title)
        gfx_lores.rect(47, 82, 226, 68, theme.BLUE)
        draw_note_body()
        draw_reader_buttons()
        do {
            sys.waitvsync()
            input.poll()
            if input.key == $09 or input.key == $1d or input.key == $9d {
                edit_focused = not edit_focused
                draw_reader_buttons()
            } else if input.key == $11 or input.wheel < 0 {
                if first_row + 4 < row_count {
                    first_row++
                    draw_note_body()
                }
            } else if input.key == $91 or input.wheel > 0 {
                if first_row > 0 {
                    first_row--
                    draw_note_body()
                }
            } else if input.key == 'e' or input.key == 'E' {
                wants_edit = true
                done = true
            } else if input.key == $0d {
                wants_edit = edit_focused
                done = true
            } else if input.key == $1b
                done = true
            if input.left_pressed() {
                if input.inside(67, 158, 72, 18) {
                    wants_edit = true
                    done = true
                } else if input.inside(177, 158, 72, 18)
                    done = true
            }
        } until done
        end_dialog()
        return wants_edit
    }

    sub draw_reader_buttons() {
        gfx_lores.fillrect(67, 158, 72, 18, theme.BLUE)
        gfx_lores.text(87, 163, theme.PAPER, iso:"EDIT")
        gfx_lores.fillrect(177, 158, 72, 18, theme.BLUE)
        gfx_lores.text(197, 163, theme.PAPER, iso:"DONE")
        if edit_focused
            gfx_lores.rect(67, 158, 72, 18, theme.GREEN)
        else
            gfx_lores.rect(177, 158, 72, 18, theme.GREEN)
        if row_count > 4
            gfx_lores.text(48, 150, theme.BLUE, iso:"ARROWS / WHEEL TO SCROLL")
    }

    sub email_address() -> uword {
        return state_data.ROLODEX_CUSTOM +
               (state_data.organizer_index as uword) * NEW_RECORD_SIZE + 51
    }

    sub show_edit_body() {
        gfx_lores.eor_mode = false
        load_text($7d00, body, 108)
        index_body()
        if row_count > 4 first_row = row_count - 4
        gfx_lores.rect(47, 82, 226, 68, theme.BLUE)
        draw_note_body()
    }

    sub draw_email_field() {
        ubyte length = strings.length(email)
        ubyte start = 0
        ubyte index = 0
        ; 25 characters at eight pixels each fit the 208-pixel field.
        if email_cursor >= 25
            start = email_cursor - 24
        while index < 25 and email[start + index] != 0 {
            visible_email[index] = email[start + index]
            index++
        }
        visible_email[index] = 0
        gfx_lores.fillrect(53, 104, 214, 24, theme.INK)
        gfx_lores.fillrect(56, 107, 208, 18, theme.PAPER)
        gfx_lores.text(61, 113, theme.INK, visible_email)
        gfx_lores.fillrect(61 + ((email_cursor - start) as uword) * 8,
                           122, 7, 1, theme.BLUE)
    }

    sub edit_long_email() -> bool {
        bool done = false
        bool accepted = false
        ubyte length
        ubyte typed
        ubyte index
        uword address = email_address()
        begin_dialog()
        if state_data.organizer_creating != 0
            email[0] = 0
        else
            load_text(address, email, 47)
        email_cursor = strings.length(email)
        gfx_lores.fillrect(42, 69, 236, 103, theme.INK)
        gfx_lores.fillrect(39, 66, 236, 103, theme.PAPER)
        gfx_lores.rect(39, 66, 236, 103, theme.INK)
        gfx_lores.fillrect(40, 67, 234, 20, theme.BLUE)
        gfx_lores.text(48, 73, theme.PAPER, iso:"CONTACT 4/5 - EMAIL")
        gfx_lores.text(53, 94, theme.BLUE, iso:"UP TO 47 CHARACTERS")
        draw_email_field()
        gfx_lores.fillrect(68, 142, 72, 18, theme.GREEN)
        gfx_lores.text(94, 147, theme.INK, iso:"OK")
        gfx_lores.fillrect(165, 142, 88, 18, theme.RED)
        gfx_lores.text(183, 147, theme.PAPER, iso:"CANCEL")
        do {
            sys.waitvsync()
            input.poll()
            length = strings.length(email)
            typed = input.key
            if typed >= $c1 and typed <= $da
                typed -= $80
            if input.key == $9d and email_cursor > 0 {
                email_cursor--
                draw_email_field()
            } else if input.key == $1d and email_cursor < length {
                email_cursor++
                draw_email_field()
            } else if input.key == $14 and email_cursor > 0 {
                index = email_cursor
                while index <= length {
                    email[index - 1] = email[index]
                    index++
                }
                email_cursor--
                draw_email_field()
            } else if input.key == $0d {
                accepted = true
                done = true
            } else if typed >= 32 and typed <= 126 and length < 47 {
                index = length + 1
                while index > email_cursor {
                    email[index] = email[index - 1]
                    index--
                }
                email[email_cursor] = typed
                email_cursor++
                draw_email_field()
            }
            if input.left_pressed() {
                if input.inside(68, 142, 72, 18) {
                    accepted = true
                    done = true
                } else if input.inside(165, 142, 88, 18)
                    done = true
            }
        } until done or input.key == $1b
        if accepted {
            for index in 0 to EMAIL_SIZE - 1
                state_data.write(address + index, 0)
            index = 0
            while index < 47 and email[index] != 0 {
                state_data.write(address + index, email[index])
                index++
            }
        }
        end_dialog()
        return accepted
    }

    sub preview_field(ubyte offset, ubyte maximum, ubyte y, str label) {
        load_text(state_data.ROLODEX_CUSTOM +
                  (state_data.organizer_index as uword) * NEW_RECORD_SIZE +
                  offset, email, maximum)
        if strings.length(email) > 14 {
            email[13] = '>'
            email[14] = 0
        }
        gfx_lores.text(166, y, theme.SOFT_BLUE, label)
        gfx_lores.text(166, y + 8, theme.PAPER, email)
    }

    sub show_contact_preview() {
        gfx_lores.eor_mode = false
        gfx_lores.fillrect(157, 87, 124, 102, theme.NAVY)
        if state_data.organizer_index >= 4 {
            gfx_lores.text(166, 98, theme.PAPER, iso:"NO MATCHES")
            return
        }
        preview_field(0, 16, 91, iso:"NAME")
        preview_field(17, 16, 109, iso:"ROLE")
        preview_field(34, 16, 127, iso:"PHONE")
        preview_field(51, 47, 145, iso:"EMAIL")
        preview_field(99, 16, 163, iso:"SOCIAL")
        gfx_lores.text(166, 181, theme.SOFT_BLUE, iso:"CLICK TO VIEW")
    }

    sub detail_field(ubyte offset, ubyte y, str label) {
        load_text(state_data.ROLODEX_CUSTOM +
                  (state_data.organizer_index as uword) * NEW_RECORD_SIZE +
                  offset, email, 16)
        gfx_lores.text(42, y, theme.BLUE, label)
        gfx_lores.text(110, y, theme.INK, email)
    }

    sub show_contact() {
        begin_dialog()
        gfx_lores.fillrect(31, 35, 260, 172, theme.PAPER)
        gfx_lores.rect(31, 35, 260, 172, theme.INK)
        gfx_lores.fillrect(32, 36, 258, 19, theme.BLUE)
        gfx_lores.text(42, 42, theme.PAPER, iso:"CONTACT DETAILS")
        detail_field(0, 65, iso:"NAME")
        detail_field(17, 81, iso:"ROLE")
        detail_field(34, 97, iso:"PHONE")
        detail_field(99, 113, iso:"SOCIAL")
        gfx_lores.text(42, 133, theme.BLUE, iso:"EMAIL")
        load_text(email_address(), email, 47)
        ubyte index
        for index in 0 to 23 {
            visible_email[index] = email[index]
            if email[index] == 0 break
        }
        visible_email[24] = 0
        gfx_lores.text(42, 145, theme.INK, visible_email)
        if strings.length(email) > 24
            gfx_lores.text(42, 155, theme.INK, &email + 24)
        gfx_lores.rect(124, 180, 72, 18, theme.GREEN)
        gfx_lores.text(144, 185, theme.INK, iso:"DONE")
        do {
            sys.waitvsync()
            input.poll()
            if input.left_pressed() and input.inside(124, 180, 72, 18)
                break
        } until input.key == $0d or input.key == $1b
        end_dialog()
    }

    sub migrate_field(uword old_address, uword new_address, ubyte maximum) {
        ubyte index = 0
        while index < maximum and state_data.read(old_address + index) != 0 {
            state_data.write(new_address + index, state_data.read(old_address + index))
            index++
        }
    }

    sub migrate_directory_records() {
        ubyte contact
        ubyte index
        uword old_address
        uword new_address
        for contact in 0 to 3 {
            old_address = state_data.ROLODEX_CUSTOM_OLD +
                          (contact as uword) * OLD_RECORD_SIZE
            new_address = state_data.ROLODEX_CUSTOM +
                          (contact as uword) * NEW_RECORD_SIZE
            for index in 0 to NEW_RECORD_SIZE - 1
                state_data.write(new_address + index, 0)
            migrate_field(old_address, new_address, 16)
            migrate_field(old_address + 17, new_address + 17, 16)
            migrate_field(old_address + 34, new_address + 34, 16)
            migrate_field(old_address + 51, new_address + 51, 19)
            migrate_field(old_address + 71, new_address + 99, 16)
        }
    }
}
