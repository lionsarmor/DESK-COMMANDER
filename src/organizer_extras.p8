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
        ubyte position = 0
        gfx_lores.fillrect(48, 83, 224, 66, theme.PAPER)
        for row in 0 to 3 {
            column = 0
            while column < 27 and body[position] != 0 and body[position] != $0d {
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
        load_text(state_data.NOTES + 7 + ((number - 1) as uword) * TITLE_SIZE,
                  title, 21)
        load_text(state_data.NOTES_BODY + 1 + ((number - 1) as uword) * BODY_SIZE,
                  body, 108)
        gfx_lores.fillrect(37, 43, 246, 143, theme.INK)
        gfx_lores.fillrect(34, 40, 246, 143, theme.PAPER)
        gfx_lores.rect(34, 40, 246, 143, theme.INK)
        gfx_lores.fillrect(35, 41, 244, 20, theme.BLUE)
        gfx_lores.text(43, 47, theme.PAPER, iso:"READ NOTE")
        gfx_lores.text(48, 68, theme.BLUE, title)
        gfx_lores.rect(47, 82, 226, 68, theme.BLUE)
        draw_note_body()
        gfx_lores.fillrect(67, 158, 72, 18, theme.BLUE)
        gfx_lores.text(88, 163, theme.PAPER, iso:"EDIT")
        gfx_lores.fillrect(177, 158, 72, 18, theme.GREEN)
        gfx_lores.text(196, 163, theme.INK, iso:"DONE")
        do {
            sys.waitvsync()
            input.poll()
            if input.key == 'e' or input.key == 'E' {
                wants_edit = true
                done = true
            } else if input.key == $0d or input.key == $1b
                done = true
            if input.left_pressed() {
                if input.inside(67, 158, 72, 18) {
                    wants_edit = true
                    done = true
                } else if input.inside(177, 158, 72, 18)
                    done = true
            }
        } until done
        input.key = 0
        return wants_edit
    }

    sub email_address() -> uword {
        return state_data.ROLODEX_CUSTOM +
               (state_data.organizer_index as uword) * NEW_RECORD_SIZE + 51
    }

    sub draw_email_field() {
        ubyte length = strings.length(email)
        ubyte start = 0
        ubyte index = 0
        if length > 32
            start = length - 32
        while index < 32 and email[start + index] != 0 {
            visible_email[index] = email[start + index]
            index++
        }
        visible_email[index] = 0
        gfx_lores.fillrect(53, 104, 214, 24, theme.INK)
        gfx_lores.fillrect(56, 107, 208, 18, theme.PAPER)
        gfx_lores.text(61, 113, theme.INK, visible_email)
    }

    sub edit_long_email() -> bool {
        bool done = false
        bool accepted = false
        ubyte length
        ubyte typed
        ubyte index
        uword address = email_address()
        if state_data.organizer_creating != 0
            email[0] = 0
        else
            load_text(address, email, 47)
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
            if input.key == $14 and length > 0 {
                email[length - 1] = 0
                draw_email_field()
            } else if input.key == $0d {
                accepted = true
                done = true
            } else if typed >= 32 and typed <= 126 and length < 47 {
                email[length] = typed
                email[length + 1] = 0
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
        input.key = 0
        return accepted
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
