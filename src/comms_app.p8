%import comms_data
%import gfx_lores
%import input
%import strings
%import theme

; Full-screen chat client. UI is bank 12; HTTP transport is bank 15.
comms_app {
    ; Conversation kinds are sent directly in an ASCII HTTP query. Do not use
    ; PETSCII character literals for these wire values.
    const ubyte DIRECT_KIND = $46
    const ubyte GROUP_KIND = $47

    extsub @bank 15 $a000 = initialize_chat_network() clobbers(A, X, Y)
    extsub @bank 15 $a003 = chat_sync() clobbers(X, Y) -> bool @A
    extsub @bank 15 $a006 = chat_load_messages() clobbers(X, Y) -> bool @A
    extsub @bank 15 $a009 = chat_send_message() clobbers(X, Y) -> bool @A
    extsub @bank 15 $a00c = chat_create_account() clobbers(X, Y) -> bool @A
    extsub @bank 15 $a00f = chat_add_friend() clobbers(X, Y) -> bool @A
    extsub @bank 15 $a012 = chat_create_group() clobbers(X, Y) -> bool @A
    extsub @bank 15 $a015 = chat_add_group_member() clobbers(X, Y) -> bool @A
    extsub @bank 16 $a000 = initialize_comms_visual() clobbers(A, X, Y)
    extsub @bank 16 $a003 = chat_draw() clobbers(A, X, Y)
    extsub @bank 16 $a006 = chat_draw_sidebar() clobbers(A, X, Y)
    extsub @bank 16 $a009 = chat_draw_messages() clobbers(A, X, Y)
    extsub @bank 16 $a00c = chat_draw_composer() clobbers(A, X, Y)

    const ubyte DIRECT_ROWS = 4
    const ubyte GROUP_ROWS = 3
    ubyte[33] edit_text
    ubyte[33] name_text
    ubyte[33] draft_text
    uword receive_timer

    sub copy_status(str value, ubyte color) {
        comms_data.set_status(value, color)
    }

    sub field_key(ubyte key) -> ubyte {
        if key >= $c1 and key <= $da
            return key - $80
        return key
    }

    sub valid_ip(str value) -> bool {
        ; Accept a plain dotted IPv4 address only. Besides catching typos,
        ; this prevents stray keyboard bytes from ever reaching ZiModem or
        ; the persistent state file.
        ubyte index = 0
        ubyte dots = 0
        ubyte digits = 0
        uword octet = 0
        while value[index] != 0 {
            ubyte character = value[index]
            if character == '.' {
                if digits == 0 or octet > 255 or dots == 3 return false
                dots++
                digits = 0
                octet = 0
            } else if character >= '0' and character <= '9' {
                if digits == 3 return false
                octet = octet * 10 + character - '0'
                digits++
            } else
                return false
            index++
        }
        return dots == 3 and digits > 0 and octet <= 255
    }

    sub entry_is_valid(bool ip_only) -> bool {
        if ip_only return valid_ip(edit_text)
        return edit_text[0] != 0
    }

    sub show_invalid_ip() {
        gfx_lores.fillrect(45, 75, 224, 22, theme.RED)
        gfx_lores.text(52, 82, theme.PAPER, iso:"INVALID IP - USE 0-255.0-255...")
    }

    sub draw_edit_field() {
        gfx_lores.fillrect(61, 111, 198, 24, theme.INK)
        gfx_lores.fillrect(64, 114, 192, 18, theme.PAPER)
        gfx_lores.text(69, 120, theme.INK, edit_text)
    }

    sub edit_dialog(str heading, ubyte maximum, bool ip_only) -> bool {
        bool done = false
        bool accepted = false
        edit_text[0] = 0
        gfx_lores.fillrect(47, 77, 226, 95, theme.INK)
        gfx_lores.fillrect(44, 74, 226, 95, theme.PAPER)
        gfx_lores.rect(44, 74, 226, 95, theme.INK)
        gfx_lores.fillrect(45, 75, 224, 22, theme.BLUE)
        gfx_lores.text(52, 82, theme.PAPER, heading)
        draw_edit_field()
        gfx_lores.fillrect(78, 143, 67, 19, theme.BLUE)
        gfx_lores.text(99, 149, theme.PAPER, iso:"OK")
        gfx_lores.fillrect(165, 143, 67, 19, theme.RED)
        gfx_lores.text(181, 149, theme.PAPER, iso:"CANCEL")
        do {
            sys.waitvsync()
            input.poll()
            ubyte length = strings.length(edit_text)
            ubyte typed = field_key(input.key)
            if input.key == $14 and length > 0 {
                edit_text[length - 1] = 0
                draw_edit_field()
            } else if input.key == $0d and length > 0 {
                if entry_is_valid(ip_only) {
                    accepted = true
                    done = true
                } else
                    show_invalid_ip()
            } else if typed >= 32 and typed <= 126 and length < maximum {
                ; General chat fields accept printable ASCII. The server-IP
                ; field is deliberately stricter: digits and periods only.
                if not ip_only or (typed >= '0' and typed <= '9') or typed == '.' {
                    edit_text[length] = typed
                    edit_text[length + 1] = 0
                    draw_edit_field()
                }
            }
            if input.left_pressed() {
                if input.inside(78, 143, 67, 19) and length > 0 {
                    if entry_is_valid(ip_only) {
                        accepted = true
                        done = true
                    } else
                        show_invalid_ip()
                } else if input.inside(165, 143, 67, 19)
                    done = true
            }
        } until done or input.key == $1b
        input.key = 0
        return accepted
    }

    sub sync_lists() {
        receive_timer = 0
        copy_status(iso:"CONTACTING CHAT SERVER...", theme.GOLD)
        chat_draw_messages()
        if chat_sync() {
            copy_status(iso:"SERVER ONLINE", theme.GREEN)
            ; SYNC also refreshes the open conversation. Previously it only
            ; updated the sidebar, which made a newly arrived reply look lost.
            comms_data.selected_name(name_text)
            if name_text[0] != 0 {
                comms_data.set_message_offset(0)
                void chat_load_messages()
            }
        } else
            copy_status(iso:"SERVER UNREACHABLE", theme.RED)
        chat_draw_sidebar()
        chat_draw_messages()
    }

    sub configure_user() {
        if not edit_dialog(iso:"USERNAME", 16, false) { chat_draw() return }
        ; The username is one setting and is saved immediately. Changing it
        ; never makes the user retype the separately stored server address.
        comms_data.set_username(edit_text)
        if not comms_data.has_host() {
            copy_status(iso:"SET THE SERVER IP NEXT", theme.GOLD)
            chat_draw()
            return
        }
        if chat_create_account()
            copy_status(iso:"USER SAVED", theme.GREEN)
        else
            copy_status(iso:"USER SAVED - SERVER OFFLINE", theme.GOLD)
        sync_lists()
        chat_draw()
    }

    sub configure_host() {
        if not edit_dialog(iso:"CHAT SERVER LAN IP", 15, true) { chat_draw() return }
        ; set_host saves the validated address to DCSTATE.BIN immediately.
        ; It remains configured across power cycles until HOST changes it.
        comms_data.set_host(edit_text)
        if not comms_data.has_username() {
            copy_status(iso:"SERVER SAVED - SET USER", theme.GOLD)
            chat_draw()
            return
        }
        if chat_create_account()
            copy_status(iso:"SERVER SAVED", theme.GREEN)
        else
            copy_status(iso:"SERVER SAVED - UNREACHABLE", theme.RED)
        sync_lists()
        chat_draw()
    }

    sub add_friend() {
        if edit_dialog(iso:"FRIEND USERNAME", 16, false) {
            comms_data.set_action(edit_text)
            if chat_add_friend() {
                copy_status(iso:"FRIEND SAVED", theme.GREEN)
                sync_lists()
            } else
                copy_status(iso:"SAVE FAILED - SERVER OFFLINE", theme.RED)
        }
        chat_draw()
    }

    sub create_group() {
        if edit_dialog(iso:"NEW GROUP NAME", 16, false) {
            comms_data.set_action(edit_text)
            if chat_create_group()
                sync_lists()
            else
                copy_status(iso:"GROUP FAILED", theme.RED)
        }
        chat_draw()
    }

    sub add_group_member() {
        if comms_data.selected_kind() != GROUP_KIND {
            copy_status(iso:"SELECT A GROUP FIRST", theme.RED)
            chat_draw_messages()
            return
        }
        if edit_dialog(iso:"ADD FRIEND TO GROUP", 16, false) {
            comms_data.set_action(edit_text)
            if chat_add_group_member()
                copy_status(iso:"GROUP MEMBER ADDED", theme.GREEN)
            else
                copy_status(iso:"MEMBER ADD FAILED", theme.RED)
        }
        chat_draw()
    }

    sub select_direct(ubyte row) {
        receive_timer = 0
        ubyte item = comms_data.direct_scroll() + row
        if item >= comms_data.friend_count() return
        comms_data.copy_friend(item, name_text)
        comms_data.select_chat(DIRECT_KIND, name_text)
        comms_data.set_message_offset(0)
        comms_data.set_composer_focused(true)
        draft_text[0] = 0
        comms_data.set_message(draft_text)
        if not chat_load_messages()
            copy_status(iso:"MESSAGE LOAD FAILED", theme.RED)
        chat_draw_messages()
    }

    sub select_group(ubyte row) {
        receive_timer = 0
        ubyte item = comms_data.group_scroll() + row
        if item >= comms_data.group_count() return
        comms_data.copy_group(item, name_text)
        comms_data.select_chat(GROUP_KIND, name_text)
        comms_data.set_message_offset(0)
        comms_data.set_composer_focused(true)
        draft_text[0] = 0
        comms_data.set_message(draft_text)
        if not chat_load_messages()
            copy_status(iso:"MESSAGE LOAD FAILED", theme.RED)
        chat_draw_messages()
    }

    sub focus_composer() {
        comms_data.selected_name(name_text)
        if name_text[0] == 0 {
            copy_status(iso:"SELECT A CHAT FIRST", theme.RED)
            chat_draw_messages()
            return
        }
        comms_data.set_composer_focused(true)
        chat_draw_composer()
    }

    sub send_draft() {
        comms_data.selected_name(name_text)
        if name_text[0] == 0 or draft_text[0] == 0
            return

        receive_timer = 0
        comms_data.set_message_offset(0)
        comms_data.set_message(draft_text)
        copy_status(iso:"SENDING...", theme.GOLD)
        chat_draw_messages()
        if chat_send_message() {
            draft_text[0] = 0
            comms_data.set_message(draft_text)
            copy_status(iso:"MESSAGE SENT", theme.GREEN)
        } else
            copy_status(iso:"SEND FAILED", theme.RED)
        chat_draw_messages()
    }

    sub handle_composer_key() {
        if not comms_data.composer_focused()
            return

        ubyte length = strings.length(draft_text)
        ubyte typed = field_key(input.key)
        if input.key == $14 {
            if length > 0 {
                draft_text[length - 1] = 0
                comms_data.set_message(draft_text)
                chat_draw_composer()
            }
        } else if input.key == $0d
            send_draft()
        else if typed >= 32 and typed <= 126 and length < 32 {
            draft_text[length] = typed
            draft_text[length + 1] = 0
            comms_data.set_message(draft_text)
            chat_draw_composer()
        }
    }

    sub scroll_messages(byte direction) {
        receive_timer = 0
        comms_data.selected_name(name_text)
        if name_text[0] == 0 return

        ubyte old_offset = comms_data.message_offset()
        ubyte new_offset = old_offset
        if direction < 0 and old_offset < 96 and
           comms_data.message_count() == comms_data.MAX_MESSAGES
            new_offset++
        else if direction > 0 and old_offset > 0
            new_offset--
        if new_offset == old_offset return

        comms_data.set_message_offset(new_offset)
        if not chat_load_messages() or comms_data.message_count() == 0 {
            comms_data.set_message_offset(old_offset)
            void chat_load_messages()
        }
        chat_draw_messages()
    }

    sub poll_open_conversation() {
        ; AT&G is request/response rather than a push connection. Poll the open
        ; newest-message view about every five seconds and redraw only when its
        ; contents changed. Older-history browsing stays still until the user
        ; returns to NEW.
        receive_timer++
        if receive_timer < 300 or comms_data.message_offset() != 0
            return
        receive_timer = 0
        comms_data.selected_name(name_text)
        if name_text[0] == 0
            return

        uword before = comms_data.message_signature()
        if chat_load_messages() and comms_data.message_signature() != before
            chat_draw_messages()
    }

    sub scroll_direct(byte direction) {
        ubyte offset = comms_data.direct_scroll()
        if direction < 0 and offset > 0
            offset--
        else if direction > 0 and offset + DIRECT_ROWS < comms_data.friend_count()
            offset++
        comms_data.set_direct_scroll(offset)
        chat_draw_sidebar()
    }

    sub scroll_groups(byte direction) {
        ubyte offset = comms_data.group_scroll()
        if direction < 0 and offset > 0
            offset--
        else if direction > 0 and offset + GROUP_ROWS < comms_data.group_count()
            offset++
        comms_data.set_group_scroll(offset)
        chat_draw_sidebar()
    }

    sub open() {
        bool close_window = false
        comms_data.initialize()
        ; Clear volatile VERA state before any Comms renderer can inspect it.
        ; Physical X16 VRAM is not zero-filled at power-on.
        comms_data.reset_session()
        initialize_chat_network()
        initialize_comms_visual()
        comms_data.set_direct_scroll(0)
        comms_data.set_group_scroll(0)
        comms_data.set_message_offset(0)
        comms_data.set_composer_focused(false)
        receive_timer = 0
        draft_text[0] = 0
        comms_data.set_message(draft_text)
        copy_status(iso:"READY", theme.BLUE)
        chat_draw()
        if not comms_data.configured() {
            if not comms_data.has_username()
                configure_user()
            if not comms_data.has_host()
                configure_host()
        } else
            sync_lists()

        do {
            sys.waitvsync()
            input.poll()
            if input.left_pressed() {
                if input.inside(3, 40, 42, 17) configure_user()
                else if input.inside(48, 40, 42, 17) configure_host()
                else if input.inside(93, 40, 35, 17) add_friend()
                else if input.inside(131, 40, 42, 17) create_group()
                else if input.inside(176, 40, 38, 17) add_group_member()
                else if input.inside(217, 40, 45, 17) sync_lists()
                else if input.inside(265, 40, 42, 17) sync_lists()
                else if input.inside(7, 77, 96, 72)
                    select_direct(((input.mouse_y - 77) / 18) as ubyte)
                else if input.inside(7, 168, 96, 54)
                    select_group(((input.mouse_y - 168) / 18) as ubyte)
                else if input.inside(240, 59, 15, 25) scroll_messages(-1)
                else if input.inside(255, 59, 15, 25) scroll_messages(1)
                else if input.inside(111, 211, 145, 21) focus_composer()
                else if input.inside(261, 211, 51, 21) send_draft()
                else if input.inside(299, 21, 15, 13) close_window = true
            }
            handle_composer_key()
            poll_open_conversation()
            if input.wheel > 0 {
                if input.mouse_x >= 106 scroll_messages(-1)
                else if input.mouse_y < 154 scroll_direct(-1)
                else scroll_groups(-1)
            } else if input.wheel < 0 {
                if input.mouse_x >= 106 scroll_messages(1)
                else if input.mouse_y < 154 scroll_direct(1)
                else scroll_groups(1)
            }
        } until close_window or input.key == $1b
        input.key = 0
    }
}
