%import comms_data
%import gfx_lores
%import theme

; Drawing-only half of Comms. Keeping pixels in bank 16 leaves bank 12 free
; for input flow and bank 15 free for ZiModem HTTP work.
comms_visual {
    ; Presence codes arrive from the server as ASCII bytes.
    const ubyte PRESENCE_ONLINE = $4f
    const ubyte PRESENCE_AWAY = $41

    const ubyte DIRECT_ROWS = 8
    const ubyte GROUP_ROWS = 4
    const ubyte FACE_SMILE = $53 ; S
    const ubyte FACE_GRIN = $47  ; G
    const ubyte FACE_WINK = $57  ; W
    const ubyte FACE_FROWN = $46 ; F
    const ubyte FACE_ANGRY = $41 ; A
    ubyte[33] name_text
    ubyte[33] sender_text
    ubyte[97] message_text
    ubyte[97] draft_text
    ubyte[49] message_line_one
    ubyte[49] message_line_two
    ubyte[49] face_line
    ubyte[39] visible_draft
    ubyte[32] username
    ubyte[30] status_text

    ; Face pixels live in their own tiny bank so the normal Comms renderer
    ; remains safely below its physical 8 KB bank limit.
    extsub @bank 17 $a003 = emoji_draw_small() clobbers(A, X, Y)
    extsub @bank 17 $a006 = emoji_draw_big() clobbers(A, X, Y)
    extsub @bank 17 $a009 = emoji_draw_picker() clobbers(A, X, Y)
    extsub @bank 17 $a00f = emoji_draw_conversation_button() clobbers(A, X, Y)

    sub draw_button(uword x, ubyte width, str label, ubyte color) {
        gfx_lores.fillrect(x, 20, width, 17, color)
        gfx_lores.rect(x, 20, width, 17, theme.INK)
        gfx_lores.text(x + 5, 25, theme.PAPER, label)
    }

    sub draw_header() {
        ; One compact toolbar replaces the old DESK COMMS title strip.
        gfx_lores.fillrect(0, 18, 320, 21, theme.BLUE)
        draw_button(2, 43, iso:"USER", theme.NAVY)
        draw_button(47, 43, iso:"HOST", theme.BLUE)
        draw_button(92, 35, iso:"+FR", theme.GREEN)
        draw_button(129, 43, iso:"+GRP", theme.GOLD)
        draw_button(174, 35, iso:"MEM", theme.SOFT_BLUE)
        draw_button(211, 35, iso:"DEL", theme.RED)
        draw_button(248, 43, iso:"SYNC", theme.NAVY)
        gfx_lores.fillrect(293, 20, 25, 17, theme.RED)
        gfx_lores.rect(293, 20, 25, 17, theme.INK)
        gfx_lores.text(302, 25, theme.PAPER, iso:"X")
    }

    sub draw_direct_row(ubyte row, ubyte item) {
        ubyte y = 96 + row * 13
        ubyte presence = comms_data.friend_presence(item)
        comms_data.copy_friend(item, name_text)
        gfx_lores.fillrect(23, y, 126, 12, theme.NAVY)
        if presence == PRESENCE_ONLINE
            gfx_lores.disc(30, y + 6, 3, theme.GREEN)
        else if presence == PRESENCE_AWAY
            gfx_lores.disc(30, y + 6, 3, theme.GOLD)
        else
            gfx_lores.disc(30, y + 6, 3, theme.RED)
        gfx_lores.text(38, y + 3, theme.PAPER, name_text)
    }

    sub draw_group_row(ubyte row, ubyte item) {
        ubyte y = 96 + row * 20
        comms_data.copy_group(item, name_text)
        gfx_lores.fillrect(169, y, 126, 17, theme.NAVY)
        gfx_lores.rect(177, y + 5, 7, 7, theme.SOFT_BLUE)
        gfx_lores.text(190, y + 5, theme.PAPER, name_text)
    }

    sub draw_sidebar() {
        ; Friends and groups live in a modal chooser instead of permanently
        ; consuming the left third of the transcript. Current public-alpha
        ; limits let every entry fit without another scrolling surface.
        ubyte row
        gfx_lores.fillrect(15, 64, 290, 145, theme.INK)
        gfx_lores.fillrect(12, 61, 290, 145, theme.PAPER)
        gfx_lores.rect(12, 61, 290, 145, theme.INK)
        gfx_lores.fillrect(13, 62, 288, 21, theme.BLUE)
        gfx_lores.text(22, 69, theme.PAPER, iso:"CHOOSE A CONVERSATION")
        gfx_lores.fillrect(281, 65, 16, 14, theme.RED)
        gfx_lores.text(286, 69, theme.PAPER, iso:"X")
        gfx_lores.text(23, 87, theme.BLUE, iso:"FRIENDS")
        gfx_lores.text(169, 87, theme.BLUE, iso:"GROUPS")
        for row in 0 to DIRECT_ROWS - 1 {
            if row < comms_data.friend_count() draw_direct_row(row, row)
        }
        for row in 0 to GROUP_ROWS - 1 {
            if row < comms_data.group_count() draw_group_row(row, row)
        }
    }

    sub draw_text_with_faces(uword x, ubyte y, ubyte color, str value) {
        ; On disk and over HTTP a face is only three safe ASCII bytes: :S:,
        ; :G:, :W:, :F:, or :A:. Blank those bytes, draw the remaining text once,
        ; then paint the corresponding yellow face over the reserved columns.
        ubyte index = 0
        while value[index] != 0 and index < 48 {
            if index < 46 and value[index] == ':' and value[index + 2] == ':' and
               (value[index + 1] == FACE_SMILE or value[index + 1] == FACE_GRIN or
                value[index + 1] == FACE_WINK or value[index + 1] == FACE_FROWN or
                value[index + 1] == FACE_ANGRY) {
                face_line[index] = ' '
                face_line[index + 1] = ' '
                face_line[index + 2] = ' '
                index += 3
            } else {
                face_line[index] = value[index]
                index++
            }
        }
        face_line[index] = 0
        gfx_lores.text(x, y, color, face_line)

        index = 0
        while value[index] != 0 and index < 48 {
            if index < 46 and value[index] == ':' and value[index + 2] == ':' and
               (value[index + 1] == FACE_SMILE or value[index + 1] == FACE_GRIN or
                value[index + 1] == FACE_WINK or value[index + 1] == FACE_FROWN or
                value[index + 1] == FACE_ANGRY) {
                comms_data.set_face_draw(x + (index as uword) * 6 + 8,
                                         y + 3, value[index + 1])
                emoji_draw_small()
                index += 3
            } else
                index++
        }
    }

    sub append_emoji(ubyte face) {
        comms_data.get_message(draft_text)
        ubyte length = 0
        while draft_text[length] != 0 and length < comms_data.MAX_MESSAGE_LENGTH
            length++
        if length > 93
            return
        draft_text[length] = ':'
        draft_text[length + 1] = face
        draft_text[length + 2] = ':'
        draft_text[length + 3] = 0
        comms_data.set_message(draft_text)
        comms_data.set_composer_focused(true)
        draw_composer()
    }

    sub insert_emoji() {
        when comms_data.emoji_choice() {
            0 -> append_emoji(FACE_SMILE)
            1 -> append_emoji(FACE_FROWN)
            2 -> append_emoji(FACE_WINK)
            3 -> append_emoji(FACE_ANGRY)
            else -> append_emoji(FACE_GRIN)
        }
    }

    sub draw_emoji_picker() {
        emoji_draw_picker()
    }

    sub same_name(str left, str right) -> bool {
        ; Usernames are at most sixteen bytes. Compare them locally rather
        ; than pulling a string helper into this small drawing overlay.
        ubyte index = 0
        while index < 16 {
            if left[index] != right[index] return false
            if left[index] == 0 return true
            index++
        }
        return true
    }

    sub sender_color(str sender) -> ubyte {
        comms_data.get_username(username)
        if same_name(sender, username) return theme.CHAT_SELF

        ; A stable name hash assigns every other sender one of five bright
        ; colors. The same name therefore keeps its color in direct and group
        ; chat without storing another user preference.
        ubyte hash = 0
        ubyte index = 0
        while sender[index] != 0 and index < 16 {
            hash += sender[index]
            index++
        }
        when hash % 5 {
            0 -> return theme.CHAT_CYAN
            1 -> return theme.CHAT_VIOLET
            2 -> return theme.CHAT_ORANGE
            3 -> return theme.CHAT_ROSE
            else -> return theme.CHAT_AZURE
        }
    }

    sub wrap_message() {
        ; Full-width bubbles hold 48 characters per line. Prefer a nearby
        ; space so words stay intact; long words split safely at the edge.
        ubyte length = 0
        while message_text[length] != 0 and length < comms_data.MAX_MESSAGE_LENGTH
            length++
        ubyte split = length
        if split > 48 {
            split = 48
            ubyte space = split
            while space > 24 and message_text[space] != ' '
                space--
            ; Only move the word when the remainder still fits line two.
            ; Otherwise a full 96-character message could lose its tail.
            if message_text[space] == ' ' and length - space - 1 <= 48
                split = space
            ; Never divide one of the three-byte face tokens across lines.
            if split >= 1 and message_text[split - 1] == ':' and
               message_text[split + 1] == ':'
                split--
            else if split >= 2 and message_text[split - 2] == ':' and
                    message_text[split] == ':'
                split -= 2
        }

        ubyte index = 0
        while index < split {
            message_line_one[index] = message_text[index]
            index++
        }
        message_line_one[index] = 0

        ubyte source = split
        while message_text[source] == ' '
            source++
        index = 0
        while message_text[source] != 0 and index < 48 {
            message_line_two[index] = message_text[source]
            source++
            index++
        }
        message_line_two[index] = 0
    }

    sub draw_messages() {
        ubyte row
        comms_data.selected_name(name_text)
        gfx_lores.fillrect(0, 39, 320, 201, theme.PAPER)
        gfx_lores.fillrect(0, 39, 320, 25, theme.SOFT_BLUE)
        ; Icon-only selector keeps the header quiet while retaining a generous
        ; click target for opening Friends and Groups.
        emoji_draw_conversation_button()
        if name_text[0] == 0
            gfx_lores.text(31, 48, theme.BLUE, iso:"CHOOSE CHAT")
        else {
            gfx_lores.text(31, 48, theme.NAVY, name_text)
            ; History controls only belong to an open conversation. Hiding
            ; them in the empty state prevents overlap with its longer title.
            gfx_lores.text(245, 48, theme.BLUE, iso:"^")
            gfx_lores.text(260, 48, theme.BLUE, iso:"v")
            if comms_data.message_offset() == 0
                gfx_lores.text(276, 48, theme.BLUE, iso:"NEW")
            else
                gfx_lores.text(276, 48, theme.BLUE, iso:"OLD")
        }
        if comms_data.message_count() > 0 {
            for row in 0 to comms_data.message_count() - 1 {
                ubyte y = 69 + row * 50
                comms_data.copy_sender(row, sender_text)
                comms_data.copy_message(row, message_text)
                wrap_message()
                ubyte bubble_color = sender_color(sender_text)
                gfx_lores.text(8, y, bubble_color, sender_text)
                gfx_lores.fillrect(6, y + 8, 306, 34, bubble_color)
                draw_text_with_faces(12, y + 13, theme.PAPER, message_line_one)
                if message_line_two[0] != 0
                    draw_text_with_faces(12, y + 24, theme.PAPER, message_line_two)
            }
        }
        comms_data.get_status(status_text)
        gfx_lores.fillrect(6, 198, 306, 11, theme.PAPER)
        gfx_lores.text(9, 201, comms_data.status_color(), status_text)
        draw_composer()
    }

    sub draw_composer() {
        ; The server accepts 96 characters. The field shows the newest 26 as
        ; the user types, giving the small X16 window normal horizontal scroll
        ; behavior instead of opening a second modal dialog.
        comms_data.get_message(draft_text)
        ubyte length = 0
        while draft_text[length] != 0 and length < comms_data.MAX_MESSAGE_LENGTH
            length++
        ubyte source = 0
        if length > 26
            source = length - 26
        ; Keep the horizontally scrolled draft from beginning halfway through
        ; a face token.
        if source >= 1 and draft_text[source - 1] == ':' and
           draft_text[source + 1] == ':'
            source--
        else if source >= 2 and draft_text[source - 2] == ':' and
                draft_text[source] == ':'
            source -= 2
        ubyte output = 0
        while draft_text[source] != 0 and output < 26 {
            visible_draft[output] = draft_text[source]
            source++
            output++
        }
        visible_draft[output] = 0

        gfx_lores.fillrect(6, 211, 175, 21, theme.PAPER)
        if comms_data.composer_focused()
            gfx_lores.rect(6, 211, 175, 21, theme.GREEN)
        else
            gfx_lores.rect(6, 211, 175, 21, theme.BLUE)
        if visible_draft[0] == 0
            gfx_lores.text(12, 218, theme.SOFT_BLUE, iso:"TYPE MESSAGE...")
        else
            draw_text_with_faces(12, 218, theme.INK, visible_draft)
        gfx_lores.fillrect(188, 210, 27, 23, theme.GOLD)
        gfx_lores.rect(188, 210, 27, 23, theme.INK)
        comms_data.set_face_draw(201, 220, FACE_SMILE)
        emoji_draw_big()
        gfx_lores.fillrect(220, 211, 92, 21, theme.BLUE)
        gfx_lores.rect(220, 211, 92, 21, theme.INK)
        gfx_lores.text(254, 218, theme.PAPER, iso:"SEND")
    }

    sub draw() {
        gfx_lores.fillrect(0, 18, 320, 222, theme.PAPER)
        draw_header()
        draw_messages()
    }
}
