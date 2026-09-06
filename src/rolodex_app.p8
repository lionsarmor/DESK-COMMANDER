%import gfx_lores
%import input
%import state_data
%import strings
%import theme

; -----------------------------------------------------------------------------
; Rolodex application
; -----------------------------------------------------------------------------
;
; This alpha keeps ten read-only sample contact cards in the program. Typing
; filters immediately; the wheel and cursor keys scroll. Active/deleted flags
; persist, while fully editable disk-backed contact records remain V1 work.

rolodex_app {
    const ubyte CONTACT_COUNT = 10
    const ubyte NO_CONTACT = 255
    const ubyte VISIBLE_ROWS = 5

    bool initialized
    ubyte[10] contact_active
    ubyte[17] search_text
    ubyte selected_result
    ubyte scroll_offset

    sub initialize() {
        ubyte contact

        if initialized
            return

        if state_data.read(state_data.ROLODEX) == $a5 {
            state_data.restore(state_data.ROLODEX + 1, &contact_active,
                               CONTACT_COUNT)
        } else {
            ; Sample cards make the alpha easy to evaluate. The release build
            ; will start blank and offer a separate demo-data option.
            for contact in 0 to CONTACT_COUNT - 1
                contact_active[contact] = 1
            save_state()
        }
        initialized = true
    }

    sub save_state() {
        state_data.write(state_data.ROLODEX, $a5)
        state_data.store(&contact_active, state_data.ROLODEX + 1,
                         CONTACT_COUNT)
        state_data.save()
    }

    sub contact_name(ubyte contact) -> str {
        when contact {
            0 -> return iso:"RODDY"
            1 -> return iso:"ALEX MARTIN"
            2 -> return iso:"CASEY PARK"
            3 -> return iso:"DANA REED"
            4 -> return iso:"JAMIE WEST"
            5 -> return iso:"MORGAN LEE"
            6 -> return iso:"PAT QUINN"
            7 -> return iso:"RILEY JONES"
            8 -> return iso:"SAM TAYLOR"
            9 -> return iso:"TERRY CLARK"
        }
        return iso:"UNKNOWN"
    }

    sub contact_role(ubyte contact) -> str {
        when contact {
            0 -> return iso:"DESK COMMANDER"
            1 -> return iso:"DESIGN"
            2 -> return iso:"ENGINEERING"
            3 -> return iso:"WRITING"
            4 -> return iso:"MUSIC"
            5 -> return iso:"OPERATIONS"
            6 -> return iso:"COMMUNITY"
            7 -> return iso:"ART"
            8 -> return iso:"HARDWARE"
            9 -> return iso:"SUPPORT"
        }
        return iso:""
    }

    sub contact_phone(ubyte contact) -> str {
        when contact {
            0 -> return iso:"555-0100"
            1 -> return iso:"555-0101"
            2 -> return iso:"555-0102"
            3 -> return iso:"555-0103"
            4 -> return iso:"555-0104"
            5 -> return iso:"555-0105"
            6 -> return iso:"555-0106"
            7 -> return iso:"555-0107"
            8 -> return iso:"555-0108"
            9 -> return iso:"555-0109"
        }
        return iso:""
    }

    sub contact_email(ubyte contact) -> str {
        when contact {
            0 -> return iso:"RODDY@DC.TEST"
            1 -> return iso:"ALEX@DC.TEST"
            2 -> return iso:"CASEY@DC.TEST"
            3 -> return iso:"DANA@DC.TEST"
            4 -> return iso:"JAMIE@DC.TEST"
            5 -> return iso:"MORGAN@DC.TEST"
            6 -> return iso:"PAT@DC.TEST"
            7 -> return iso:"RILEY@DC.TEST"
            8 -> return iso:"SAM@DC.TEST"
            9 -> return iso:"TERRY@DC.TEST"
        }
        return iso:""
    }

    sub contact_social(ubyte contact) -> str {
        when contact {
            0 -> return iso:"@RODDY_X16"
            1 -> return iso:"@ALEXMAKES"
            2 -> return iso:"@CASEYCODES"
            3 -> return iso:"@DANAWRITES"
            4 -> return iso:"@JAMIEPLAYS"
            5 -> return iso:"@MORGANOPS"
            6 -> return iso:"@PATCONNECTS"
            7 -> return iso:"@RILEYDRAWS"
            8 -> return iso:"@SAMBITS"
            9 -> return iso:"@TERRYHELPS"
        }
        return iso:""
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
        gfx_lores.text(32, 33, theme.PAPER, iso:"ROLODEX")
        gfx_lores.fillrect(272, 31, 15, 12, theme.RED)
        gfx_lores.text(276, 33, theme.PAPER, iso:"X")

        ; Search is always active: type at any time to narrow the list.
        gfx_lores.text(34, 51, theme.BLUE, iso:"SEARCH")
        draw_search_field()

        gfx_lores.text(34, 75, theme.BLUE, iso:"CONTACTS")
        gfx_lores.text(160, 75, theme.BLUE, iso:"CARD")

        draw_results()

        gfx_lores.text(34, 196, theme.SOFT_BLUE, iso:"WHEEL/ARROWS")
        draw_action_button(158, 191, 60, iso:"DELETE", theme.RED)
        draw_action_button(231, 191, 49, iso:"DONE", theme.BLUE)
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
            thumb_y += scroll_offset * 9
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
        if selected_result > 0
            selected_result--
        if selected_result < scroll_offset
            scroll_offset = selected_result
    }

    sub move_down() {
        ubyte count = matching_contact_count()

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

        contact_active[contact] = 0
        count = matching_contact_count()

        ; Keep the selection and scroll position on a real remaining row.
        if count == 0 {
            selected_result = 0
            scroll_offset = 0
            return
        }
        if selected_result >= count
            selected_result = count - 1
        if scroll_offset > 0 and scroll_offset + VISIBLE_ROWS > count
            scroll_offset--
    }

    sub open() {
        bool close_window = false
        ubyte clicked_row
        ubyte clicked_contact
        ubyte old_offset
        ubyte old_selection

        initialize()
        search_text[0] = 0
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
                            selected_result = scroll_offset + clicked_row
                            draw_results()
                        }
                    }
                } else if input.inside(158, 191, 60, 14) {
                    delete_selected_contact()
                    draw_results()
                } else if input.inside(231, 191, 49, 14) or
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
            if input.key == $11 {
                old_selection = selected_result
                move_down()
                if selected_result != old_selection
                    draw_results()
            } else if input.key == $91 {
                old_selection = selected_result
                move_up()
                if selected_result != old_selection
                    draw_results()
            } else if input.key != 0 and input.key != $1b {
                edit_search(input.key)
                draw_search_field()
                draw_results()
            }
        } until close_window or input.key == $1b

        save_state()

        ; Escape closes Rolodex without also exiting the desktop.
        input.key = 0
    }
}
