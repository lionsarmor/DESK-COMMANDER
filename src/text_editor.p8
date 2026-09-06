%import app_mailbox
%import diskio
%import gfx_lores
%import input
%import strings
%import theme

; -----------------------------------------------------------------------------
; DESK COMMANDER Text Editor ++
; -----------------------------------------------------------------------------
;
; The document lives in otherwise-unused VERA RAM at $1:4000. That keeps a
; useful 2 KB editing area without consuming the editor's 8 KB code bank.

text_editor {
    const ubyte BUFFER_BANK = 1
    const uword BUFFER_ADDRESS = $4000
    const uword MAX_TEXT = 2047
    const ubyte TEXT_COLUMNS = 34
    const ubyte TEXT_ROWS = 14

    const ubyte STATUS_READY = 0
    const ubyte STATUS_SAVED = 1
    const ubyte STATUS_TRUNCATED = 2
    const ubyte STATUS_ERROR = 3

    uword text_length
    uword cursor_index
    uword view_start
    bool dirty
    ubyte status_message
    ubyte[65] io_buffer
    ubyte[35] line_buffer
    ubyte[29] display_name
    ubyte[51] name_buffer

    sub text_at(uword index) -> ubyte {
        return cx16.vpeek(BUFFER_BANK, BUFFER_ADDRESS + index)
    }

    sub set_text_at(uword index, ubyte value) {
        cx16.vpoke(BUFFER_BANK, BUFFER_ADDRESS + index, value)
    }

    sub copy_limited(str source, str destination, ubyte maximum) {
        ubyte index = 0
        while source[index] != 0 and index < maximum {
            destination[index] = source[index]
            index++
        }
        destination[index] = 0
    }

    sub load_document() {
        uword bytes_read
        ubyte index
        bool previous_was_return = false

        text_length = 0
        cursor_index = 0
        view_start = 0
        dirty = false
        status_message = STATUS_READY

        if not diskio.f_open(app_mailbox.filename) {
            status_message = STATUS_ERROR
            return
        }

        do {
            bytes_read = diskio.f_read(&io_buffer, 64)
            if bytes_read == 0
                break

            for index in 0 to lsb(bytes_read) - 1 {
                ubyte character = io_buffer[index]

                ; Store one newline for CR, LF, or CR/LF input files.
                if character == $0d {
                    character = $0a
                    previous_was_return = true
                } else if character == $0a and previous_was_return {
                    previous_was_return = false
                    continue
                } else
                    previous_was_return = false

                if text_length == MAX_TEXT {
                    status_message = STATUS_TRUNCATED
                    break
                }

                ; Keep binary control bytes from damaging the bitmap display.
                if character < 32 and character != $0a
                    character = ' '
                set_text_at(text_length, character)
                text_length++
            }
        } until bytes_read < 64 or text_length == MAX_TEXT

        diskio.f_close()
        cursor_index = text_length
        set_text_at(text_length, 0)
    }

    sub make_save_name(str filename) {
        name_buffer[0] = '@'
        name_buffer[1] = ':'
        copy_limited(filename, &name_buffer + 2, 48)
    }

    sub save_document() {
        uword written = 0
        uword chunk_size
        ubyte index

        make_save_name(app_mailbox.filename)
        if not diskio.f_open_w(name_buffer) {
            status_message = STATUS_ERROR
            return
        }

        while written < text_length {
            chunk_size = text_length - written
            if chunk_size > 64
                chunk_size = 64
            for index in 0 to lsb(chunk_size) - 1
                io_buffer[index] = text_at(written + index)
            if not diskio.f_write(&io_buffer, chunk_size) {
                status_message = STATUS_ERROR
                diskio.f_close_w()
                return
            }
            written += chunk_size
        }

        diskio.f_close_w()
        app_mailbox.dos_code = diskio.status_code()
        if app_mailbox.dos_code < 20 {
            dirty = false
            status_message = STATUS_SAVED
        } else
            status_message = STATUS_ERROR
    }

    sub valid_filename_key(ubyte key) -> bool {
        if key < 32 or key > 126
            return false
        return key != '"' and key != ':' and key != '=' and key != ',' and
               key != '*' and key != '?' and key != '/'
    }

    sub draw_filename_field() {
        gfx_lores.fillrect(58, 103, 204, 22, theme.INK)
        gfx_lores.fillrect(61, 106, 198, 16, theme.PAPER)
        gfx_lores.text(66, 110, theme.INK, name_buffer)
    }

    sub ask_save_as() -> bool {
        bool done = false
        bool accepted = false
        ubyte length

        copy_limited(app_mailbox.filename, name_buffer, 23)
        gfx_lores.fillrect(45, 70, 230, 105, theme.INK)
        gfx_lores.fillrect(42, 67, 230, 105, theme.PAPER)
        gfx_lores.rect(42, 67, 230, 105, theme.INK)
        gfx_lores.fillrect(43, 68, 228, 17, theme.BLUE)
        gfx_lores.text(51, 72, theme.PAPER, iso:"SAVE AS")
        gfx_lores.text(58, 91, theme.BLUE, iso:"NAME.EXT")
        draw_filename_field()
        gfx_lores.rect(61, 139, 76, 20, theme.BLUE)
        gfx_lores.text(85, 145, theme.INK, iso:"SAVE")
        gfx_lores.rect(165, 139, 88, 20, theme.BLUE)
        gfx_lores.text(180, 145, theme.INK, iso:"CANCEL")

        do {
            sys.waitvsync()
            input.poll()
            if input.key == $14 {
                length = strings.length(name_buffer)
                if length > 0
                    name_buffer[length - 1] = 0
                draw_filename_field()
            } else if valid_filename_key(input.key) {
                length = strings.length(name_buffer)
                if length < 23 {
                    name_buffer[length] = input.key
                    name_buffer[length + 1] = 0
                    draw_filename_field()
                }
            } else if input.key == $0d and strings.length(name_buffer) > 0 {
                accepted = true
                done = true
            }

            if input.left_pressed() {
                if input.inside(61, 139, 76, 20) and strings.length(name_buffer) > 0 {
                    accepted = true
                    done = true
                } else if input.inside(165, 139, 88, 20)
                    done = true
            }
        } until done or input.key == $1b

        if accepted
            copy_limited(name_buffer, app_mailbox.filename, 50)
        input.key = 0
        return accepted
    }

    sub save_as() {
        if ask_save_as()
            save_document()
        draw_window()
    }

    sub keep_cursor_visible() {
        const uword PAGE_TEXT = TEXT_COLUMNS * TEXT_ROWS

        if cursor_index < view_start
            view_start = (cursor_index / TEXT_COLUMNS) * TEXT_COLUMNS
        else if cursor_index >= view_start + PAGE_TEXT
            view_start = ((cursor_index - PAGE_TEXT + TEXT_COLUMNS) /
                          TEXT_COLUMNS) * TEXT_COLUMNS
    }

    sub insert_character(ubyte character) {
        uword index

        if text_length == MAX_TEXT {
            status_message = STATUS_TRUNCATED
            return
        }

        index = text_length
        while index > cursor_index {
            set_text_at(index, text_at(index - 1))
            index--
        }
        set_text_at(cursor_index, character)
        text_length++
        cursor_index++
        set_text_at(text_length, 0)
        dirty = true
        status_message = STATUS_READY
        keep_cursor_visible()
    }

    sub backspace() {
        uword index

        if cursor_index == 0
            return
        cursor_index--
        index = cursor_index
        while index < text_length - 1 {
            set_text_at(index, text_at(index + 1))
            index++
        }
        text_length--
        set_text_at(text_length, 0)
        dirty = true
        keep_cursor_visible()
    }

    sub draw_button(uword x, ubyte width, str label) {
        gfx_lores.fillrect(x + 2, 211, width, 18, theme.INK)
        gfx_lores.fillrect(x, 209, width, 18, theme.PAPER)
        gfx_lores.rect(x, 209, width, 18, theme.BLUE)
        gfx_lores.text(x + 7, 214, theme.INK, label)
    }

    sub draw_status() {
        gfx_lores.fillrect(17, 194, 286, 13, theme.PAPER)
        if dirty
            gfx_lores.text(22, 197, theme.RED, iso:"MODIFIED")
        else when status_message {
            STATUS_SAVED -> gfx_lores.text(22, 197, theme.GREEN, iso:"SAVED")
            STATUS_TRUNCATED -> gfx_lores.text(22, 197, theme.RED, iso:"2K LIMIT REACHED")
            STATUS_ERROR -> gfx_lores.text(22, 197, theme.RED, iso:"DISK ERROR")
        }
    }

    sub draw_document() {
        uword index = view_start
        ubyte row
        ubyte column
        ubyte cursor_row = 0
        ubyte cursor_column = 0
        bool cursor_on_screen = false

        gfx_lores.fillrect(17, 50, 286, 141, theme.PAPER)
        for row in 0 to TEXT_ROWS - 1 {
            column = 0
            while column < TEXT_COLUMNS and index < text_length {
                if index == cursor_index {
                    cursor_row = row
                    cursor_column = column
                    cursor_on_screen = true
                }
                ubyte character = text_at(index)
                if character == $0a {
                    index++
                    break
                }
                line_buffer[column] = character
                column++
                index++
            }
            if index == cursor_index and not cursor_on_screen {
                cursor_row = row
                cursor_column = column
                cursor_on_screen = true
            }
            line_buffer[column] = 0
            gfx_lores.text(22, 54 + row * 10, theme.INK, line_buffer)
        }

        ; The renderer records the exact visual position while it walks the
        ; text, so Return characters and wrapped lines cannot skew the cursor.
        if cursor_on_screen
            gfx_lores.horizontal_line(22 + cursor_column * 8,
                                       62 + cursor_row * 10, 7, theme.RED)
    }

    sub draw_editor_contents() {
        ; Redraw only the changing areas. Repainting the entire modal for every
        ; keystroke made the bitmap display flash much more than necessary.
        gfx_lores.fillrect(143, 22, 12, 16, theme.BLUE)
        if dirty
            gfx_lores.text(145, 25, theme.GOLD, iso:"*")
        draw_document()
        draw_status()
    }

    sub index_at_screen_position(ubyte target_row, ubyte target_column) -> uword {
        uword index = view_start
        ubyte row = 0
        ubyte column = 0

        ; Convert a visual click back into a document byte position, including
        ; explicit newlines and wrapped long lines.
        while index < text_length and row < TEXT_ROWS {
            if row == target_row and column >= target_column
                return index
            if text_at(index) == $0a {
                if row == target_row
                    return index
                row++
                column = 0
            } else {
                column++
                if column == TEXT_COLUMNS {
                    row++
                    column = 0
                }
            }
            index++
        }
        return index
    }

    sub draw_window() {
        gfx_lores.fillrect(11, 23, 302, 211, theme.INK)
        gfx_lores.fillrect(8, 20, 302, 211, theme.PAPER)
        gfx_lores.rect(8, 20, 302, 211, theme.INK)
        gfx_lores.fillrect(9, 21, 300, 18, theme.BLUE)
        gfx_lores.text(17, 25, theme.PAPER, iso:"TEXT EDITOR ++")
        if dirty
            gfx_lores.text(145, 25, theme.GOLD, iso:"*")
        gfx_lores.fillrect(288, 23, 15, 13, theme.RED)
        gfx_lores.text(292, 26, theme.PAPER, iso:"X")

        copy_limited(app_mailbox.filename, display_name, 28)
        gfx_lores.text(18, 42, theme.BLUE, display_name)
        draw_document()
        draw_status()
        draw_button(17, 58, iso:"SAVE")
        draw_button(81, 82, iso:"SAVE AS")
        draw_button(235, 68, iso:"CLOSE")
    }

    sub close_requested() -> bool {
        if not dirty
            return true

        gfx_lores.fillrect(53, 78, 214, 88, theme.INK)
        gfx_lores.fillrect(50, 75, 214, 88, theme.PAPER)
        gfx_lores.rect(50, 75, 214, 88, theme.INK)
        gfx_lores.fillrect(51, 76, 212, 17, theme.RED)
        gfx_lores.text(59, 80, theme.PAPER, iso:"UNSAVED CHANGES")
        gfx_lores.text(61, 106, theme.INK, iso:"S SAVE  D DISCARD")
        gfx_lores.text(61, 122, theme.BLUE, iso:"ESC CANCEL")

        do {
            sys.waitvsync()
            input.poll()
            if input.key == 'S' or input.key == 's' {
                save_document()
                return not dirty
            }
            if input.key == 'D' or input.key == 'd'
                return true
        } until input.key == $1b

        input.key = 0
        draw_window()
        return false
    }

    sub open() {
        bool close_editor = false

        diskio.drivenumber = 8
        load_document()
        draw_window()

        do {
            sys.waitvsync()
            input.poll()

            if input.left_pressed() {
                if input.inside(22, 54, 272, 140) {
                    ubyte clicked_column = lsb((input.mouse_x - 22) / 8)
                    ubyte clicked_row = lsb((input.mouse_y - 54) / 10)
                    cursor_index = index_at_screen_position(clicked_row,
                                                            clicked_column)
                    keep_cursor_visible()
                    draw_document()
                } else if input.inside(17, 209, 58, 18) {
                    save_document()
                    draw_editor_contents()
                } else if input.inside(81, 209, 82, 18)
                    save_as()
                else if input.inside(235, 209, 68, 18) or
                        input.inside(288, 23, 15, 13)
                    close_editor = close_requested()
            }

            if input.key == $14 {
                backspace()
                draw_editor_contents()
            } else if input.key == $0d {
                insert_character($0a)
                draw_editor_contents()
            } else if input.key == $9d and cursor_index > 0 {
                cursor_index--
                keep_cursor_visible()
                draw_document()
            } else if input.key == $1d and cursor_index < text_length {
                cursor_index++
                keep_cursor_visible()
                draw_document()
            } else if input.key == $91 {
                if cursor_index >= TEXT_COLUMNS
                    cursor_index -= TEXT_COLUMNS
                else
                    cursor_index = 0
                keep_cursor_visible()
                draw_document()
            } else if input.key == $11 {
                if cursor_index + TEXT_COLUMNS < text_length
                    cursor_index += TEXT_COLUMNS
                else
                    cursor_index = text_length
                keep_cursor_visible()
                draw_document()
            } else if input.key == $89 {
                save_document()
                draw_editor_contents()
            } else if input.key == $8a
                save_as()
            else if input.key >= 32 and input.key <= 126 {
                insert_character(input.key)
                draw_editor_contents()
            } else if input.key == $1b
                close_editor = close_requested()
        } until close_editor

        input.key = 0
    }
}
