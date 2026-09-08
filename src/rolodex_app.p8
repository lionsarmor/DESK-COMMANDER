%import gfx_lores
%import input
%import state_data
%import strings
%import theme

; -----------------------------------------------------------------------------
; Desk Directory application
; -----------------------------------------------------------------------------
;
; Four user-created cards live in the shared SD-backed state image. Typing
; filters immediately; the wheel and cursor keys scroll. Add and Delete both
; save as soon as they complete. A fresh installation starts empty.

rolodex_app {
    const ubyte CUSTOM_COUNT = 4
    const ubyte CONTACT_COUNT = CUSTOM_COUNT
    const ubyte NO_CONTACT = 255
    const ubyte VISIBLE_ROWS = 5
    const ubyte CUSTOM_NAME = 0
    const ubyte CUSTOM_ROLE = 17
    const ubyte CUSTOM_PHONE = 34
    const ubyte CUSTOM_EMAIL = 51
    const ubyte CUSTOM_SOCIAL = 71
    const ubyte CUSTOM_RECORD_SIZE = 88
    const uword CUSTOM_STATE = state_data.ROLODEX_CUSTOM
    const uword OLD_CUSTOM_STATE = state_data.BASE + 900
    const uword EDIT_BACKUP = $7e00

    ; Keep the complete footer hint clear of the action buttons. These shared
    ; values are used for both drawing and mouse hit-testing.
    const uword ADD_BUTTON_X = 112
    const ubyte ADD_BUTTON_WIDTH = 36
    const uword EDIT_BUTTON_X = 152
    const ubyte EDIT_BUTTON_WIDTH = 42
    const uword DELETE_BUTTON_X = 198
    const ubyte DELETE_BUTTON_WIDTH = 34
    const uword DONE_BUTTON_X = 236
    const ubyte DONE_BUTTON_WIDTH = 50
    const ubyte ACTION_BUTTON_Y = 191
    const ubyte ACTION_BUTTON_HEIGHT = 14

    bool initialized
    ubyte[CONTACT_COUNT] contact_active
    ubyte[17] search_text
    ubyte[25] contact_buffer
    ubyte[25] field_text
    ubyte selected_result
    ubyte scroll_offset
    ubyte status_message

    sub initialize() {
        ubyte contact

        if initialized
            return

        if state_data.read(state_data.ROLODEX) == $a8 {
            state_data.restore(state_data.ROLODEX + 1, &contact_active,
                               CONTACT_COUNT)
        } else {
            for contact in 0 to CONTACT_COUNT - 1
                contact_active[contact] = 0
            save_state()
        }
        initialized = true
    }

    sub save_state() {
        state_data.write(state_data.ROLODEX, $a8)
        state_data.store(&contact_active, state_data.ROLODEX + 1,
                         CONTACT_COUNT)
        state_data.save()
    }

    sub custom_address(ubyte contact, ubyte field) -> uword {
        return CUSTOM_STATE + (contact as uword) *
               CUSTOM_RECORD_SIZE + field
    }

    sub custom_value(ubyte contact, ubyte field, ubyte maximum) -> str {
        ubyte index = 0
        uword address = custom_address(contact, field)
        while index < maximum and state_data.read(address + index) != 0 {
            contact_buffer[index] = state_data.read(address + index)
            index++
        }
        contact_buffer[index] = 0
        return &contact_buffer
    }

    sub save_custom_value(ubyte contact, ubyte field, ubyte maximum) {
        ubyte index = 0
        uword address = custom_address(contact, field)
        while index < maximum and field_text[index] != 0 {
            state_data.write(address + index, field_text[index])
            index++
        }
        state_data.write(address + index, 0)
    }

    sub clear_custom(ubyte contact) {
        ubyte index
        uword address = custom_address(contact, 0)
        for index in 0 to CUSTOM_RECORD_SIZE - 1
            state_data.write(address + index, 0)
    }

    sub contact_name(ubyte contact) -> str {
        return custom_value(contact, CUSTOM_NAME, 16)
    }

    sub contact_role(ubyte contact) -> str {
        return custom_value(contact, CUSTOM_ROLE, 16)
    }

    sub contact_phone(ubyte contact) -> str {
        return custom_value(contact, CUSTOM_PHONE, 16)
    }

    sub contact_email(ubyte contact) -> str {
        return custom_value(contact, CUSTOM_EMAIL, 19)
    }

    sub contact_social(ubyte contact) -> str {
        return custom_value(contact, CUSTOM_SOCIAL, 16)
    }

    sub same_letter(ubyte left, ubyte right) -> bool {
        ; Make ordinary ASCII upper/lowercase letters compare equally.
        if left >= 97 and left <= 122
            left -= 32
        if right >= 97 and right <= 122
            right -= 32
        return left == right
    }

    sub text_matches(str candidate) -> bool {
        ubyte query_length = strings.length(search_text)
        ubyte candidate_length
        ubyte start
        ubyte letter
        bool match

        if query_length == 0
            return true

        candidate_length = strings.length(candidate)
        if query_length > candidate_length
            return false

        start = 0
        while start + query_length <= candidate_length {
            match = true
            letter = 0
            while letter < query_length {
                if not same_letter(candidate[start + letter],
                                   search_text[letter])
                    match = false
                letter++
            }
            if match
                return true
            start++
        }
        return false
    }

    sub contact_matches(ubyte contact) -> bool {
        if contact_active[contact] == 0
            return false

        return text_matches(contact_name(contact)) or
               text_matches(contact_email(contact)) or
               text_matches(contact_social(contact))
    }

    sub matching_contact_count() -> ubyte {
        ubyte contact
        ubyte count = 0

        for contact in 0 to CONTACT_COUNT - 1 {
            if contact_matches(contact)
                count++
        }
        return count
    }

    sub contact_at_result(ubyte wanted_result) -> ubyte {
        ubyte contact
        ubyte result = 0

        for contact in 0 to CONTACT_COUNT - 1 {
            if contact_matches(contact) {
                if result == wanted_result
                    return contact
                result++
            }
        }
        return NO_CONTACT
    }

    sub draw_window() {
        gfx_lores.fillrect(27, 31, 269, 181, theme.INK)
        gfx_lores.fillrect(24, 28, 269, 181, theme.PAPER)
        gfx_lores.rect(24, 28, 269, 181, theme.INK)

        gfx_lores.fillrect(25, 29, 267, 16, theme.BLUE)
        gfx_lores.text(32, 33, theme.PAPER, iso:"DESK DIRECTORY")
        gfx_lores.fillrect(272, 31, 15, 12, theme.RED)
        gfx_lores.text(276, 33, theme.PAPER, iso:"X")

        ; Search is always active: type at any time to narrow the list.
        gfx_lores.text(34, 51, theme.BLUE, iso:"SEARCH")
        draw_search_field()

        gfx_lores.text(34, 75, theme.BLUE, iso:"CONTACTS")
        gfx_lores.text(160, 75, theme.BLUE, iso:"CARD")

        draw_results()

        when status_message {
            1 -> gfx_lores.text(34, 196, theme.RED, iso:"DIR FULL")
            2 -> gfx_lores.text(34, 196, theme.GREEN, iso:"SAVED")
            3 -> gfx_lores.text(34, 196, theme.GREEN, iso:"DELETED")
            4 -> gfx_lores.text(34, 196, theme.RED, iso:"DEL AGAIN")
            else -> gfx_lores.text(34, 196, theme.SOFT_BLUE, iso:"TYPE FIND")
        }
        draw_action_button(ADD_BUTTON_X, ACTION_BUTTON_Y, ADD_BUTTON_WIDTH,
                           iso:"ADD", theme.GREEN)
        draw_action_button(EDIT_BUTTON_X, ACTION_BUTTON_Y, EDIT_BUTTON_WIDTH,
                           iso:"EDIT", theme.BLUE)
        draw_action_button(DELETE_BUTTON_X, ACTION_BUTTON_Y,
                           DELETE_BUTTON_WIDTH, iso:"DEL", theme.RED)
        draw_action_button(DONE_BUTTON_X, ACTION_BUTTON_Y, DONE_BUTTON_WIDTH,
                           iso:"DONE", theme.BLUE)
    }

    sub draw_search_field() {
        gfx_lores.fillrect(83, 49, 198, 19, theme.INK)
        gfx_lores.fillrect(86, 52, 192, 13, theme.PAPER)
        if strings.length(search_text) == 0
            gfx_lores.text(90, 55, theme.SOFT_BLUE, iso:"NAME EMAIL @HANDLE")
        else
            gfx_lores.text(90, 55, theme.INK, search_text)
    }

    sub draw_results() {
        ubyte row
        ubyte contact
        ubyte y

        ; Only repaint the changing list, thumb, and card. The window frame,
        ; search box, and buttons stay untouched while the user scrolls.
        for row in 0 to VISIBLE_ROWS - 1 {
            contact = contact_at_result(scroll_offset + row)
            y = 87 + row * 21
            draw_contact_row(y, contact, scroll_offset + row == selected_result)
        }

        draw_scrollbar()
        draw_contact_card(contact_at_result(selected_result))
    }

    sub draw_contact_row(ubyte y, ubyte contact, bool selected) {
        ubyte face_color = theme.PAPER
        ubyte text_color = theme.INK

        if selected {
            face_color = theme.SOFT_BLUE
            text_color = theme.NAVY
        }

        gfx_lores.fillrect(34, y, 108, 18, face_color)
        gfx_lores.rect(34, y, 108, 18, theme.BLUE)
        if contact == NO_CONTACT
            gfx_lores.text(40, y + 5, theme.SOFT_BLUE, iso:"--")
        else
            gfx_lores.text(40, y + 5, text_color, contact_name(contact))
    }

    sub draw_scrollbar() {
        ubyte count = matching_contact_count()
        ubyte thumb_y = 89

        gfx_lores.fillrect(146, 87, 5, 102, theme.SOFT_BLUE)
        if count > VISIBLE_ROWS
            ; The thumb has 78 pixels of travel inside the 102-pixel track.
            ; Scale by the actual result count so the last contact never draws
            ; the thumb below the bottom of the list.
            thumb_y += lsb((scroll_offset as uword) * 78 /
                           (count - VISIBLE_ROWS))
        gfx_lores.fillrect(146, thumb_y, 5, 24, theme.BLUE)
    }

    sub draw_contact_card(ubyte contact) {
        gfx_lores.fillrect(157, 87, 124, 102, theme.NAVY)

        if contact == NO_CONTACT {
            gfx_lores.text(166, 98, theme.PAPER, iso:"NO MATCHES")
            return
        }

        draw_card_field(91, iso:"NAME", contact_name(contact))
        draw_card_field(109, iso:"ROLE", contact_role(contact))
        draw_card_field(127, iso:"PHONE", contact_phone(contact))
        draw_card_field(145, iso:"EMAIL", contact_email(contact))
        draw_card_field(163, iso:"SOCIAL", contact_social(contact))
    }

    sub draw_card_field(ubyte y, str label, str value) {
        gfx_lores.text(166, y, theme.SOFT_BLUE, label)
        gfx_lores.text(166, y + 8, theme.PAPER, value)
    }

    sub draw_action_button(uword x, ubyte y, ubyte width, str label,
                           ubyte border_color) {
        gfx_lores.fillrect(x + 2, y + 2, width, 14, theme.INK)
        gfx_lores.fillrect(x, y, width, 14, theme.PAPER)
        gfx_lores.rect(x, y, width, 14, border_color)
        gfx_lores.text(x + 7, y + 3, theme.INK, label)
    }

    sub draw_entry_field() {
        gfx_lores.fillrect(55, 105, 210, 22, theme.INK)
        gfx_lores.fillrect(58, 108, 204, 16, theme.PAPER)
        if strings.length(field_text) == 0
            gfx_lores.text(63, 112, theme.SOFT_BLUE, iso:"TYPE HERE")
        else
            gfx_lores.text(63, 112, theme.INK, field_text)
    }

    sub backup_record(ubyte contact) {
        ubyte index
        uword address = custom_address(contact, 0)
        for index in 0 to CUSTOM_RECORD_SIZE - 1
            state_data.write(EDIT_BACKUP + index,
                             state_data.read(address + index))
    }

    sub restore_record(ubyte contact) {
        ubyte index
        uword address = custom_address(contact, 0)
        for index in 0 to CUSTOM_RECORD_SIZE - 1
            state_data.write(address + index,
                             state_data.read(EDIT_BACKUP + index))
    }

    sub prepare_field(ubyte contact, ubyte field, ubyte maximum,
                      bool creating) {
        ubyte index = 0
        uword address = custom_address(contact, field)
        if creating {
            field_text[0] = 0
            return
        }
        while index < maximum and state_data.read(address + index) != 0 {
            field_text[index] = state_data.read(address + index)
            index++
        }
        field_text[index] = 0
    }

    sub ask_field(str title, str hint, ubyte maximum,
                  bool required) -> bool {
        bool finished = false
        bool accepted = false
        ubyte length

        gfx_lores.fillrect(45, 70, 230, 107, theme.INK)
        gfx_lores.fillrect(42, 67, 230, 107, theme.PAPER)
        gfx_lores.rect(42, 67, 230, 107, theme.INK)
        gfx_lores.fillrect(43, 68, 228, 18, theme.BLUE)
        gfx_lores.text(51, 73, theme.PAPER, title)
        gfx_lores.text(55, 93, theme.BLUE, hint)
        draw_entry_field()
        gfx_lores.rect(61, 141, 76, 20, theme.GREEN)
        gfx_lores.text(86, 147, theme.INK, iso:"OK")
        gfx_lores.rect(165, 141, 88, 20, theme.RED)
        gfx_lores.text(180, 147, theme.INK, iso:"CANCEL")

        do {
            sys.waitvsync()
            input.poll()

            if input.key == $14 {
                length = strings.length(field_text)
                if length > 0
                    field_text[length - 1] = 0
                draw_entry_field()
            } else if input.key >= 32 and input.key <= 126 {
                length = strings.length(field_text)
                if length < maximum {
                    field_text[length] = input.key
                    field_text[length + 1] = 0
                    draw_entry_field()
                }
            } else if input.key == $0d and
                      (not required or strings.length(field_text) > 0) {
                accepted = true
                finished = true
            }

            if input.left_pressed() {
                if input.inside(61, 141, 76, 20) and
                   (not required or strings.length(field_text) > 0) {
                    accepted = true
                    finished = true
                } else if input.inside(165, 141, 88, 20)
                    finished = true
            }
        } until finished or input.key == $1b

        input.key = 0
        return accepted
    }

    sub first_free_custom() -> ubyte {
        ubyte contact
        for contact in 0 to CONTACT_COUNT - 1 {
            if contact_active[contact] == 0
                return contact
        }
        return NO_CONTACT
    }

    sub add_contact() {
        ubyte contact = first_free_custom()

        if contact == NO_CONTACT {
            status_message = 1
            draw_window()
            return
        }

        edit_contact(contact, true)
    }

    sub edit_contact(ubyte contact, bool creating) {
        backup_record(contact)
        if creating
            clear_custom(contact)

        prepare_field(contact, CUSTOM_NAME, 16, creating)
        if not ask_field(iso:"CONTACT 1/5", iso:"NAME (REQUIRED)", 16, true) {
            restore_record(contact)
            return
        }
        save_custom_value(contact, CUSTOM_NAME, 16)

        prepare_field(contact, CUSTOM_ROLE, 16, creating)
        if not ask_field(iso:"CONTACT 2/5", iso:"ROLE / COMPANY", 16, false) {
            restore_record(contact)
            return
        }
        save_custom_value(contact, CUSTOM_ROLE, 16)

        prepare_field(contact, CUSTOM_PHONE, 16, creating)
        if not ask_field(iso:"CONTACT 3/5", iso:"PHONE", 16, false) {
            restore_record(contact)
            return
        }
        save_custom_value(contact, CUSTOM_PHONE, 16)

        prepare_field(contact, CUSTOM_EMAIL, 19, creating)
        if not ask_field(iso:"CONTACT 4/5", iso:"EMAIL", 19, false) {
            restore_record(contact)
            return
        }
        save_custom_value(contact, CUSTOM_EMAIL, 19)

        prepare_field(contact, CUSTOM_SOCIAL, 16, creating)
        if not ask_field(iso:"CONTACT 5/5", iso:"SOCIAL HANDLE", 16, false) {
            restore_record(contact)
            return
        }
        save_custom_value(contact, CUSTOM_SOCIAL, 16)

        contact_active[contact] = 1
        search_text[0] = 0
        reset_search_selection()
        status_message = 2
        save_state()
    }

    sub edit_selected_contact() {
        ubyte contact = contact_at_result(selected_result)
        if contact != NO_CONTACT
            edit_contact(contact, false)
    }

    sub reset_search_selection() {
        selected_result = 0
        scroll_offset = 0
    }

    sub edit_search(ubyte key) {
        ubyte length = strings.length(search_text)

        if key == $14 {
            if length > 0
                search_text[length - 1] = 0
            reset_search_selection()
            return
        }

        if key >= 32 and key <= 126 and length < 15 {
            search_text[length] = key
            search_text[length + 1] = 0
            reset_search_selection()
        }
    }

    sub move_up() {
        status_message = 0
        if selected_result > 0
            selected_result--
        if selected_result < scroll_offset
            scroll_offset = selected_result
    }

    sub move_down() {
        ubyte count = matching_contact_count()
        status_message = 0

        if selected_result + 1 < count
            selected_result++
        if selected_result >= scroll_offset + VISIBLE_ROWS
            scroll_offset++
    }

    sub scroll_up() {
        if scroll_offset > 0
            scroll_offset--
    }

    sub scroll_down() {
        ubyte count = matching_contact_count()

        if count > VISIBLE_ROWS and scroll_offset + VISIBLE_ROWS < count
            scroll_offset++
    }

    sub delete_selected_contact() {
        ubyte contact = contact_at_result(selected_result)
        ubyte count

        if contact == NO_CONTACT
            return

        if status_message != 4 {
            status_message = 4
            return
        }

        contact_active[contact] = 0
        clear_custom(contact)
        count = matching_contact_count()

        ; Keep the selection and scroll position on a real remaining row.
        if count == 0 {
            selected_result = 0
            scroll_offset = 0
            status_message = 3
            save_state()
            return
        }
        if selected_result >= count
            selected_result = count - 1
        if scroll_offset > 0 and scroll_offset + VISIBLE_ROWS > count
            scroll_offset--
        status_message = 3
        save_state()
    }

    sub open() {
        bool close_window = false
        ubyte clicked_row
        ubyte clicked_contact
        ubyte old_offset
        ubyte old_selection

        initialize()
        search_text[0] = 0
        status_message = 0
        reset_search_selection()
        draw_window()

        do {
            sys.waitvsync()
            input.poll()

            if input.left_pressed() {
                if input.inside(34, 87, 108, 105) {
                    clicked_row = ((input.mouse_y - 87) / 21) as ubyte
                    if clicked_row < VISIBLE_ROWS {
                        clicked_contact = contact_at_result(scroll_offset + clicked_row)
                        if clicked_contact != NO_CONTACT {
                            status_message = 0
                            selected_result = scroll_offset + clicked_row
                            draw_results()
                        }
                    }
                } else if input.inside(ADD_BUTTON_X, ACTION_BUTTON_Y,
                                       ADD_BUTTON_WIDTH,
                                       ACTION_BUTTON_HEIGHT)
                    add_contact()
                else if input.inside(EDIT_BUTTON_X, ACTION_BUTTON_Y,
                                     EDIT_BUTTON_WIDTH,
                                     ACTION_BUTTON_HEIGHT) {
                    edit_selected_contact()
                    draw_window()
                } else if input.inside(DELETE_BUTTON_X, ACTION_BUTTON_Y,
                                     DELETE_BUTTON_WIDTH,
                                     ACTION_BUTTON_HEIGHT) {
                    delete_selected_contact()
                    draw_window()
                } else if input.inside(DONE_BUTTON_X, ACTION_BUTTON_Y,
                                       DONE_BUTTON_WIDTH,
                                       ACTION_BUTTON_HEIGHT) or
                          input.inside(272, 31, 15, 12) {
                    close_window = true
                }
            }

            if input.wheel > 0 {
                old_offset = scroll_offset
                scroll_up()
                if scroll_offset != old_offset
                    draw_results()
            } else if input.wheel < 0 {
                old_offset = scroll_offset
                scroll_down()
                if scroll_offset != old_offset
                    draw_results()
            }

            ; PETSCII cursor-down is $11; cursor-up is $91.
            ; INSERT adds a card; ENTER edits; an empty-search DELETE requires
            ; the same second press as the mouse button. These shortcuts keep
            ; the complete Directory workflow usable without a mouse.
            if input.key == $94 {
                add_contact()
                draw_window()
            } else if input.key == $14 and search_text[0] == 0 {
                delete_selected_contact()
                draw_window()
            } else if input.key == $11 {
                old_selection = selected_result
                move_down()
                if selected_result != old_selection
                    draw_results()
            } else if input.key == $91 {
                old_selection = selected_result
                move_up()
                if selected_result != old_selection
                    draw_results()
            } else if input.key == $0d {
                edit_selected_contact()
                draw_window()
            } else if input.key != 0 and input.key != $1b {
                edit_search(input.key)
                draw_search_field()
                draw_results()
            }
        } until close_window or input.key == $1b

        save_state()

        ; Escape closes Desk Directory without also exiting the desktop.
        input.key = 0
    }
}
