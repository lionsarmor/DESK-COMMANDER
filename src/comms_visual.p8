%import comms_data
%import gfx_lores
%import theme

; Drawing-only half of Comms. Keeping pixels in bank 16 leaves bank 12 free
; for input flow and bank 15 free for ZiModem HTTP work.
comms_visual {
    ; Presence codes arrive from the server as ASCII bytes.
    const ubyte PRESENCE_ONLINE = $4f
    const ubyte PRESENCE_AWAY = $41

    const ubyte DIRECT_ROWS = 4
    const ubyte GROUP_ROWS = 3
    ubyte[33] name_text
    ubyte[33] sender_text
    ubyte[33] message_text
    ubyte[33] draft_text
    ubyte[24] visible_draft
    ubyte[32] username
    ubyte[30] status_text

    sub draw_button(uword x, ubyte width, str label, ubyte color) {
        gfx_lores.fillrect(x, 40, width, 17, color)
        gfx_lores.rect(x, 40, width, 17, theme.INK)
        gfx_lores.text(x + 5, 45, theme.PAPER, label)
    }

    sub draw_header() {
        gfx_lores.fillrect(0, 18, 320, 41, theme.BLUE)
        comms_data.get_username(username)
        gfx_lores.text(8, 24, theme.PAPER, iso:"DESK COMMS")
        if username[0] != 0 gfx_lores.text(105, 24, theme.PAPER, username)
        gfx_lores.fillrect(299, 21, 15, 13, theme.RED)
        gfx_lores.text(303, 24, theme.PAPER, iso:"X")
        draw_button(3, 42, iso:"USER", theme.NAVY)
        draw_button(48, 42, iso:"HOST", theme.BLUE)
        draw_button(93, 35, iso:"+FR", theme.GREEN)
        draw_button(131, 42, iso:"+GRP", theme.GOLD)
        draw_button(176, 38, iso:"MEM", theme.SOFT_BLUE)
        draw_button(217, 45, iso:"SYNC", theme.NAVY)
        draw_button(265, 42, iso:"TEST", theme.GREEN)
    }

    sub draw_direct_row(ubyte row, ubyte item) {
        ubyte y = 77 + row * 18
        ubyte presence = comms_data.friend_presence(item)
        comms_data.copy_friend(item, name_text)
        gfx_lores.fillrect(7, y, 96, 16, theme.NAVY)
        if presence == PRESENCE_ONLINE
            gfx_lores.disc(15, y + 8, 3, theme.GREEN)
        else if presence == PRESENCE_AWAY
            gfx_lores.disc(15, y + 8, 3, theme.GOLD)
        else
            gfx_lores.disc(15, y + 8, 3, theme.RED)
        gfx_lores.text(24, y + 5, theme.PAPER, name_text)
    }

    sub draw_group_row(ubyte row, ubyte item) {
        ubyte y = 168 + row * 18
        comms_data.copy_group(item, name_text)
        gfx_lores.fillrect(7, y, 96, 16, theme.NAVY)
        gfx_lores.rect(12, y + 5, 7, 7, 7)
        gfx_lores.text(24, y + 5, theme.PAPER, name_text)
    }

    sub draw_sidebar() {
        ubyte row
        gfx_lores.fillrect(0, 59, 106, 181, theme.NAVY)
        gfx_lores.text(10, 66, theme.SOFT_BLUE, iso:"FRIENDS")
        gfx_lores.text(86, 66, theme.SOFT_BLUE, iso:"^")
        gfx_lores.text(96, 66, theme.SOFT_BLUE, iso:"v")
        for row in 0 to DIRECT_ROWS - 1 {
            ubyte item = comms_data.direct_scroll() + row
            if item < comms_data.friend_count() draw_direct_row(row, item)
        }
        gfx_lores.text(10, 157, theme.SOFT_BLUE, iso:"GROUPS")
        gfx_lores.text(86, 157, theme.SOFT_BLUE, iso:"^")
        gfx_lores.text(96, 157, theme.SOFT_BLUE, iso:"v")
        for row in 0 to GROUP_ROWS - 1 {
            ubyte group_item = comms_data.group_scroll() + row
            if group_item < comms_data.group_count() draw_group_row(row, group_item)
        }
    }

    sub draw_messages() {
        ubyte row
        comms_data.selected_name(name_text)
        gfx_lores.fillrect(106, 59, 214, 181, theme.PAPER)
        gfx_lores.fillrect(106, 59, 214, 25, theme.SOFT_BLUE)
        if name_text[0] == 0
            gfx_lores.text(114, 68, theme.NAVY, iso:"CHOOSE A CONVERSATION")
        else {
            gfx_lores.text(114, 68, theme.NAVY, name_text)
            ; History controls only belong to an open conversation. Hiding
            ; them in the empty state prevents overlap with its longer title.
            gfx_lores.text(245, 68, theme.BLUE, iso:"^")
            gfx_lores.text(260, 68, theme.BLUE, iso:"v")
            if comms_data.message_offset() == 0
                gfx_lores.text(276, 68, theme.BLUE, iso:"NEW")
            else
                gfx_lores.text(276, 68, theme.BLUE, iso:"OLD")
        }
        if comms_data.message_count() > 0 {
            for row in 0 to comms_data.message_count() - 1 {
                ubyte y = 90 + row * 28
                comms_data.copy_sender(row, sender_text)
                comms_data.copy_message(row, message_text)
                gfx_lores.text(113, y, theme.BLUE, sender_text)
                gfx_lores.fillrect(111, y + 8, 199, 16, theme.SOFT_BLUE)
                gfx_lores.text(116, y + 13, theme.INK, message_text)
            }
        }
        comms_data.get_status(status_text)
        gfx_lores.fillrect(110, 198, 202, 11, theme.PAPER)
        gfx_lores.text(113, 201, comms_data.status_color(), status_text)
        draw_composer()
    }

    sub draw_composer() {
        ; The server accepts 32 characters. The field shows the newest 23 as
        ; the user types, giving the small X16 window normal horizontal scroll
        ; behavior instead of opening a second modal dialog.
        comms_data.get_message(draft_text)
        ubyte length = 0
        while draft_text[length] != 0 and length < 32
            length++
        ubyte source = 0
        if length > 23
            source = length - 23
        ubyte output = 0
        while draft_text[source] != 0 and output < 23 {
            visible_draft[output] = draft_text[source]
            source++
            output++
        }
        visible_draft[output] = 0

        gfx_lores.fillrect(111, 211, 145, 21, theme.PAPER)
        if comms_data.composer_focused()
            gfx_lores.rect(111, 211, 145, 21, theme.GREEN)
        else
            gfx_lores.rect(111, 211, 145, 21, theme.BLUE)
        if visible_draft[0] == 0
            gfx_lores.text(117, 218, theme.SOFT_BLUE, iso:"TYPE MESSAGE...")
        else
            gfx_lores.text(117, 218, theme.INK, visible_draft)
        gfx_lores.fillrect(261, 211, 51, 21, theme.BLUE)
        gfx_lores.text(270, 218, theme.PAPER, iso:"SEND")
    }

    sub draw() {
        gfx_lores.fillrect(0, 18, 320, 222, theme.PAPER)
        draw_header()
        draw_sidebar()
        draw_messages()
    }
}
