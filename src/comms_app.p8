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
    extsub @bank 15 $a015 = chat_group_action() clobbers(X, Y) -> bool @A
    extsub @bank 16 $a000 = initialize_comms_visual() clobbers(A, X, Y)
    extsub @bank 16 $a003 = chat_draw() clobbers(A, X, Y)
    extsub @bank 16 $a006 = chat_draw_sidebar() clobbers(A, X, Y)
    extsub @bank 16 $a009 = chat_draw_messages() clobbers(A, X, Y)
    extsub @bank 16 $a00c = chat_draw_composer() clobbers(A, X, Y)
    extsub @bank 16 $a00f = chat_insert_emoji() clobbers(A, X, Y)
    extsub @bank 16 $a012 = chat_draw_emoji_picker() clobbers(A, X, Y)
    extsub @bank 17 $a00f = chat_secret_dialog() clobbers(X, Y) -> bool @A

    ubyte[17] name_text
    ; edit_text doubles as the inline message draft. Dialogs and the composer
    ; are never active together, which saves precious bank-12 working RAM.
    ubyte[97] edit_text
    uword receive_timer
    bool chooser_open
    bool emoji_picker_open

    sub copy_status(str value, ubyte color) {
        comms_data.set_status(value, color)
    }

    sub field_key(ubyte key) -> ubyte {
        if key >= $c1 and key <= $da
            return key - $80
        return key
    }

    sub draw_edit_field() {
        gfx_lores.fillrect(61, 111, 198, 24, theme.INK)
        gfx_lores.fillrect(64, 114, 192, 18, theme.PAPER)
        gfx_lores.text(69, 120, theme.INK, edit_text)
    }

    sub edit_dialog(str heading, ubyte maximum, bool host_only) -> bool {
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
                accepted = true
                done = true
            } else if typed >= 32 and typed <= 126 and length < maximum {
                ; General chat fields accept printable ASCII. The server-IP
                ; field is deliberately stricter: digits and periods only.
                if not host_only or
                   (typed >= '0' and typed <= '9') or typed == '.' or
                   typed == '-' or (typed >= 'A' and typed <= 'Z') or
                   (typed >= 'a' and typed <= 'z') {
                    edit_text[length] = typed
                    edit_text[length + 1] = 0
                    draw_edit_field()
                }
            }
            if input.left_pressed() {
                if input.inside(78, 143, 67, 19) and length > 0 {
                    accepted = true
                    done = true
                } else if input.inside(165, 143, 67, 19)
                    done = true
            }
        } until done or input.key == $1b
        input.key = 0
        return accepted
    }

    sub sync_lists() {
        receive_timer = 0
        copy_status(iso:"CONTACTING SERVER...", theme.GOLD)
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
        chat_draw_messages()
    }

    sub configure_user() {
        if not edit_dialog(iso:"USERNAME", 16, false) { chat_draw() return }
        ubyte copy_index = 0
        while edit_text[copy_index] != 0 and copy_index < 16 {
            name_text[copy_index] = edit_text[copy_index]
            copy_index++
        }
        name_text[copy_index] = 0
        if not chat_secret_dialog() {
            chat_draw()
            return
        }
        ; The username is one setting and is saved immediately. Changing it
        ; never makes the user retype the separately stored server address.
        comms_data.set_username(name_text)
        if not comms_data.has_host() {
            copy_status(iso:"SET THE SERVER IP NEXT", theme.GOLD)
            chat_draw()
            return
        }
        if chat_create_account()
            copy_status(iso:"USER SAVED", theme.GREEN)
        else
            copy_status(iso:"USER SAVED - OFFLINE", theme.GOLD)
        sync_lists()
        chat_draw()
    }

    sub configure_host() {
        if not edit_dialog(iso:"HTTPS CHAT HOST", 31, true) { chat_draw() return }
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
            copy_status(iso:"SERVER UNREACHABLE", theme.RED)
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
                copy_status(iso:"SAVE FAILED - OFFLINE", theme.RED)
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
            if chat_group_action()
                copy_status(iso:"MEMBER ADDED", theme.GREEN)
            else
                copy_status(iso:"MEMBER FAILED", theme.RED)
        }
        chat_draw()
    }

    sub select_direct(ubyte row) {
        receive_timer = 0
        ubyte item = comms_data.direct_scroll() + row
        if item >= comms_data.friend_count() return
        comms_data.copy_friend(item, name_text)
        comms_data.select_chat(DIRECT_KIND, name_text)
        chooser_open = false
        comms_data.set_message_offset(0)
        comms_data.set_composer_focused(true)
        edit_text[0] = 0
        comms_data.set_message(edit_text)
        if not chat_load_messages()
            copy_status(iso:"LOAD FAILED", theme.RED)
        else if comms_data.message_count() == 0
            copy_status(iso:"CHAT READY", theme.BLUE)
        else
            copy_status(iso:"CHAT LOADED", theme.GREEN)
        chat_draw_messages()
    }

    sub select_group(ubyte row) {
        receive_timer = 0
        ubyte item = comms_data.group_scroll() + row
        if item >= comms_data.group_count() return
        comms_data.copy_group(item, name_text)
        comms_data.select_chat(GROUP_KIND, name_text)
        chooser_open = false
        comms_data.set_message_offset(0)
        comms_data.set_composer_focused(true)
        edit_text[0] = 0
        comms_data.set_message(edit_text)
        if not chat_load_messages()
            copy_status(iso:"LOAD FAILED", theme.RED)
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

    sub open_chooser() {
        chooser_open = true
        comms_data.set_composer_focused(false)
        chat_draw_messages()
        chat_draw_sidebar()
    }

    sub close_chooser() {
        chooser_open = false
        comms_data.selected_name(name_text)
        comms_data.set_composer_focused(name_text[0] != 0)
        chat_draw_messages()
    }

    sub send_draft() {
        comms_data.selected_name(name_text)
        if name_text[0] == 0 or edit_text[0] == 0
            return

        receive_timer = 0
        chooser_open = false
        comms_data.set_message_offset(0)
        comms_data.set_message(edit_text)
        copy_status(iso:"SENDING...", theme.GOLD)
        chat_draw_messages()
        if chat_send_message() {
            edit_text[0] = 0
            comms_data.set_message(edit_text)
            copy_status(iso:"MESSAGE SENT", theme.GREEN)
        } else
            copy_status(iso:"SEND FAILED", theme.RED)
        chat_draw_messages()
    }

    sub handle_composer_key() {
        if not comms_data.composer_focused()
            return

        ubyte length = strings.length(edit_text)
        ubyte typed = field_key(input.key)
        if input.key == $14 {
            if length > 0 {
                edit_text[length - 1] = 0
                comms_data.set_message(edit_text)
                chat_draw_composer()
            }
        } else if input.key == $0d
            send_draft()
        else if typed >= 32 and typed <= 126 and
                length < comms_data.MAX_MESSAGE_LENGTH {
            edit_text[length] = typed
            edit_text[length + 1] = 0
            comms_data.set_message(edit_text)
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
        if chat_load_messages() and comms_data.message_signature() != before {
            copy_status(iso:"NEW MESSAGE", theme.GREEN)
            chat_draw_messages()
        }
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
        emoji_picker_open = false
        edit_text[0] = 0
        comms_data.set_message(edit_text)
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
                if emoji_picker_open {
                    if input.inside(55, 136, 210, 42) {
                        ubyte choice = ((input.mouse_x - 55) / 42) as ubyte
                        comms_data.set_emoji_choice(choice)
                        chat_insert_emoji()
                        comms_data.get_message(edit_text)
                    }
                    emoji_picker_open = false
                    chat_draw_messages()
                } else if chooser_open {
                    if input.inside(281, 65, 16, 14)
                        close_chooser()
                    else if input.inside(23, 96, 126, 104)
                        select_direct(((input.mouse_y - 96) / 13) as ubyte)
                    else if input.inside(169, 96, 126, 80)
                        select_group(((input.mouse_y - 96) / 20) as ubyte)
                } else if input.inside(2, 20, 43, 17) configure_user()
                else if input.inside(47, 20, 43, 17) configure_host()
                else if input.inside(92, 20, 35, 17) add_friend()
                else if input.inside(129, 20, 43, 17) create_group()
                else if input.inside(174, 20, 35, 17) add_group_member()
                else if input.inside(211, 20, 35, 17) {
                    name_text[0] = 0
                    comms_data.set_action(name_text)
                    void chat_group_action()
                    chat_draw()
                }
                else if input.inside(248, 20, 43, 17) sync_lists()
                else if input.inside(245, 39, 15, 25) scroll_messages(-1)
                else if input.inside(260, 39, 15, 25) scroll_messages(1)
                else if input.inside(4, 41, 21, 21) open_chooser()
                else if input.inside(6, 211, 175, 21) focus_composer()
                else if input.inside(188, 210, 27, 23) {
                    emoji_picker_open = true
                    chat_draw_messages()
                    chat_draw_emoji_picker()
                }
                else if input.inside(220, 211, 92, 21) send_draft()
                else if input.inside(293, 20, 25, 17) close_window = true
            }
            if not chooser_open and not emoji_picker_open {
                handle_composer_key()
                poll_open_conversation()
                if input.wheel > 0
                    scroll_messages(-1)
                else if input.wheel < 0
                    scroll_messages(1)
            }
        } until close_window or input.key == $1b
        input.key = 0
    }
}
