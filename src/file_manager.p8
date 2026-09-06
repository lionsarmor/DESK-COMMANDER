%import app_mailbox
%import conv
%import diskio
%import gfx_lores
%import input
%import theme

; -----------------------------------------------------------------------------
; DESK COMMANDER File Manager
; -----------------------------------------------------------------------------
;
; The browser occupies high-RAM bank 4. File-operation dialogs load into bank 5
; and Text Editor ++ loads into bank 6. This is deliberately modular: the apps
; can grow without pushing the desktop through the X16's conventional-RAM limit.

file_manager {
    const ubyte VISIBLE_ROWS = 5
    const ubyte NO_SELECTION = 255
    const ubyte NAME_SIZE = 51

    const ubyte MESSAGE_READY = 0
    const ubyte MESSAGE_EMPTY = 1
    const ubyte MESSAGE_ERROR = 2
    const ubyte MESSAGE_APP_MISSING = 3

    ; Bank 5: file-operation dialog jump table.
    extsub @bank 5 $a000 = initialize_file_ops() clobbers(A, X, Y)
    extsub @bank 5 $a003 = new_folder_dialog() clobbers(A, X, Y)
    extsub @bank 5 $a006 = new_file_dialog() clobbers(A, X, Y)
    extsub @bank 5 $a009 = rename_dialog() clobbers(A, X, Y)
    extsub @bank 5 $a00c = move_dialog() clobbers(A, X, Y)
    extsub @bank 5 $a00f = delete_dialog() clobbers(A, X, Y)

    ; Bank 6: Text Editor ++ jump table.
    extsub @bank 6 $a000 = initialize_text_editor() clobbers(A, X, Y)
    extsub @bank 6 $a003 = open_text_editor() clobbers(A, X, Y)

    ; Five full CMDR-DOS names are retained. Display text is shortened only in
    ; the scratch buffer, so file operations always receive the real name.
    ubyte[255] entry_names
    ubyte directory_flags
    ubyte[29] display_text

    ubyte entry_count
    ubyte selected_row
    uword page_start
    bool has_more_entries
    ubyte last_clicked_row
    ubyte double_click_frames
    ubyte message
    ubyte last_dos_code

    sub name_for_row(ubyte row) -> str {
        return &entry_names + (row as uword) * NAME_SIZE
    }

    sub copy_limited(str source, str destination, ubyte maximum) {
        ubyte index = 0
        while source[index] != 0 and index < maximum {
            destination[index] = source[index]
            index++
        }
        destination[index] = 0
    }

    sub row_is_directory(ubyte row) -> bool {
        return (directory_flags & (1 << row)) != 0
    }

    sub load_directory_page() {
        uword skipped = 0

        entry_count = 0
        directory_flags = 0
        selected_row = NO_SELECTION
        has_more_entries = false
        last_clicked_row = NO_SELECTION
        double_click_frames = 0

        if diskio.lf_start_list(0) {
            while diskio.lf_next_entry() {
                if skipped < page_start {
                    skipped++
                    continue
                }
                if entry_count == VISIBLE_ROWS {
                    has_more_entries = true
                    break
                }

                copy_limited(diskio.list_filename,
                             name_for_row(entry_count), NAME_SIZE - 1)
                if diskio.list_filetype == "dir"
                    directory_flags |= 1 << entry_count
                entry_count++
            }
            diskio.lf_end_list()

            if entry_count > 0 {
                selected_row = 0
                message = MESSAGE_READY
            } else
                message = MESSAGE_EMPTY
        } else {
            message = MESSAGE_ERROR
            last_dos_code = 255
        }
    }

    sub draw_folder_icon(ubyte y) {
        ; A small tabbed folder with a dark one-pixel outline.
        gfx_lores.fillrect(37, y + 4, 9, 4, theme.INK)
        gfx_lores.fillrect(36, y + 7, 18, 9, theme.INK)
        gfx_lores.fillrect(38, y + 5, 7, 3, theme.GOLD)
        gfx_lores.fillrect(38, y + 8, 14, 6, theme.BLUE)
    }

    sub draw_file_icon(ubyte y) {
        ; Page outline, folded corner, and two tiny lines of "text."
        gfx_lores.fillrect(39, y + 2, 14, 14, theme.INK)
        gfx_lores.fillrect(41, y + 4, 10, 10, theme.PAPER)
        gfx_lores.fillrect(48, y + 4, 3, 3, theme.SOFT_BLUE)
        gfx_lores.horizontal_line(42, y + 9, 7, theme.BLUE)
        gfx_lores.horizontal_line(42, y + 12, 6, theme.BLUE)
    }

    sub draw_row(ubyte row) {
        ubyte y = 79 + row * 17
        ubyte face = theme.PAPER
        ubyte ink = theme.INK

        if row == selected_row {
            face = theme.SOFT_BLUE
            ink = theme.NAVY
        }

        gfx_lores.fillrect(28, y, 250, 16, face)
        if row_is_directory(row)
            draw_folder_icon(y)
        else
            draw_file_icon(y)
        copy_limited(name_for_row(row), display_text, 27)
        gfx_lores.text(59, y + 4, ink, display_text)
    }

    sub draw_rows() {
        ubyte row

        gfx_lores.fillrect(28, 79, 250, 85, theme.PAPER)
        if entry_count == 0 {
            gfx_lores.text(48, 105, theme.SOFT_BLUE,
                           iso:"NO FILES IN THIS FOLDER")
            return
        }
        for row in 0 to entry_count - 1
            draw_row(row)
    }

    sub draw_scrollbar() {
        ; Two arrow buttons and a three-position thumb make the existing page
        ; navigation visible without pulling a large division routine into
        ; this tightly packed 8 KB application bank.
        gfx_lores.fillrect(280, 79, 12, 85, theme.PAPER)
        gfx_lores.rect(280, 79, 12, 85, theme.BLUE)
        gfx_lores.fillrect(281, 80, 10, 11, theme.SOFT_BLUE)
        gfx_lores.fillrect(281, 152, 10, 11, theme.SOFT_BLUE)
        gfx_lores.text(283, 82, theme.INK, iso:"^")
        gfx_lores.text(283, 154, theme.INK, iso:"v")
        gfx_lores.fillrect(282, 92, 8, 59, theme.SOFT_BLUE)

        if page_start == 0 and not has_more_entries
            gfx_lores.fillrect(282, 92, 8, 59, theme.BLUE)
        else if page_start == 0
            gfx_lores.fillrect(282, 92, 8, 12, theme.BLUE)
        else if has_more_entries
            gfx_lores.fillrect(282, 116, 8, 12, theme.BLUE)
        else
            gfx_lores.fillrect(282, 139, 8, 12, theme.BLUE)
    }

    sub draw_message() {
        gfx_lores.fillrect(28, 165, 264, 13, theme.PAPER)
        when message {
            MESSAGE_READY -> {
                if has_more_entries
                    gfx_lores.text(32, 168, theme.BLUE, iso:"MORE ITEMS BELOW")
                else
                    gfx_lores.text(32, 168, theme.BLUE, iso:"DEVICE 8 READY")
            }
            MESSAGE_EMPTY -> gfx_lores.text(32, 168, theme.SOFT_BLUE,
                                             iso:"EMPTY FOLDER")
            MESSAGE_ERROR -> {
                gfx_lores.text(32, 168, theme.RED, iso:"DISK ERROR")
                gfx_lores.text(122, 168, theme.RED, conv.str_ub(last_dos_code))
            }
            MESSAGE_APP_MISSING -> gfx_lores.text(32, 168, theme.RED,
                                                   iso:"APP FILE IS MISSING")
        }
    }

    sub draw_button(uword x, ubyte y, ubyte width, str label) {
        gfx_lores.fillrect(x + 1, y + 1, width, 16, theme.INK)
        gfx_lores.fillrect(x, y, width, 16, theme.PAPER)
        gfx_lores.rect(x, y, width, 16, theme.BLUE)
        gfx_lores.text(x + 5, y + 4, theme.INK, label)
    }

    sub draw_window() {
        gfx_lores.fillrect(17, 24, 292, 211, theme.INK)
        gfx_lores.fillrect(14, 21, 292, 211, theme.PAPER)
        gfx_lores.rect(14, 21, 292, 211, theme.INK)
        gfx_lores.fillrect(15, 22, 290, 18, theme.BLUE)
        gfx_lores.text(23, 26, theme.PAPER, iso:"FILE MANAGER")
        gfx_lores.fillrect(284, 24, 15, 13, theme.RED)
        gfx_lores.text(288, 27, theme.PAPER, iso:"X")

        gfx_lores.fillrect(28, 46, 264, 17, theme.INK)
        gfx_lores.fillrect(30, 48, 260, 13, theme.PAPER)
        gfx_lores.text(36, 51, theme.INK, iso:"DEVICE 8 / CURRENT FOLDER")
        gfx_lores.fillrect(28, 65, 264, 13, theme.BLUE)
        gfx_lores.text(59, 68, theme.PAPER, iso:"NAME")

        draw_rows()
        draw_scrollbar()
        draw_message()

        draw_button(20, 181, 33, iso:"UP")
        draw_button(56, 181, 45, iso:"OPEN")
        draw_button(104, 181, 75, iso:"NEW FILE")
        draw_button(182, 181, 69, iso:"NEW DIR")
        draw_button(20, 204, 63, iso:"RENAME")
        draw_button(86, 204, 48, iso:"MOVE")
        draw_button(137, 204, 63, iso:"DELETE")
        draw_button(203, 204, 72, iso:"REFRESH")
    }

    sub row_at_pointer() -> ubyte {
        if input.inside(28, 79, 250, 85) {
            ubyte row = lsb((input.mouse_y - 79) / 17)
            if row < entry_count
                return row
        }
        return NO_SELECTION
    }

    sub move_down() {
        if entry_count == 0
            return
        if selected_row + 1 < entry_count {
            selected_row++
            draw_rows()
        } else if has_more_entries {
            page_start += entry_count
            load_directory_page()
            draw_rows()
            draw_scrollbar()
            draw_message()
        }
    }

    sub move_up() {
        if entry_count == 0
            return
        if selected_row > 0 {
            selected_row--
            draw_rows()
        } else if page_start >= VISIBLE_ROWS {
            page_start -= VISIBLE_ROWS
            load_directory_page()
            selected_row = entry_count - 1
            draw_rows()
            draw_scrollbar()
            draw_message()
        }
    }

    sub scroll_page_down() {
        if has_more_entries {
            selected_row = entry_count - 1
            move_down()
        }
    }

    sub scroll_page_up() {
        if page_start >= VISIBLE_ROWS {
            selected_row = 0
            move_up()
        }
    }

    sub use_scrollbar() {
        if input.mouse_y < 92
            scroll_page_up()
        else if input.mouse_y >= 152
            scroll_page_down()
        else if input.mouse_y < 122
            scroll_page_up()
        else
            scroll_page_down()
    }

    sub selected_to_mailbox() {
        if selected_row == NO_SELECTION
            return
        copy_limited(name_for_row(selected_row), app_mailbox.filename, 50)
        app_mailbox.item_is_directory = row_is_directory(selected_row)
    }

    sub operation_finished() {
        if app_mailbox.result == app_mailbox.RESULT_ERROR {
            message = MESSAGE_ERROR
            last_dos_code = app_mailbox.dos_code
        } else if app_mailbox.result == app_mailbox.RESULT_OK {
            page_start = 0
            load_directory_page()
        }
        draw_window()
    }

    sub run_new_file() {
        new_file_dialog()
        operation_finished()
    }

    sub run_new_folder() {
        new_folder_dialog()
        operation_finished()
    }

    sub run_selected_operation(ubyte operation) {
        if selected_row == NO_SELECTION
            return
        selected_to_mailbox()
        when operation {
            1 -> rename_dialog()
            2 -> move_dialog()
            3 -> delete_dialog()
        }
        operation_finished()
    }

    sub open_selected() {
        if selected_row == NO_SELECTION
            return

        if row_is_directory(selected_row) {
            diskio.chdir(name_for_row(selected_row))
            last_dos_code = diskio.status_code()
            page_start = 0
            load_directory_page()
            if last_dos_code >= 20
                message = MESSAGE_ERROR
            draw_window()
            return
        }

        selected_to_mailbox()
        initialize_text_editor()
        open_text_editor()
        load_directory_page()
        draw_window()
    }

    sub go_up() {
        diskio.chdir(iso:"_")
        last_dos_code = diskio.status_code()
        page_start = 0
        load_directory_page()
        if last_dos_code >= 20
            message = MESSAGE_ERROR
        draw_window()
    }

    sub refresh() {
        load_directory_page()
        draw_window()
    }

    sub open() {
        bool close_window = false
        ubyte clicked_row

        diskio.drivenumber = 8
        ; The desktop preloads all three file-suite banks while its low-memory
        ; loader is visible. Calling LOADLIB from this bank after switching to
        ; another bank would hide the code that is currently executing.
        initialize_file_ops()
        page_start = 0
        load_directory_page()
        draw_window()

        do {
            sys.waitvsync()
            input.poll()

            if double_click_frames > 0
                double_click_frames--

            if input.wheel > 0
                scroll_page_up()
            else if input.wheel < 0
                scroll_page_down()

            if input.left_pressed() {
                clicked_row = row_at_pointer()
                if clicked_row != NO_SELECTION {
                    if clicked_row == last_clicked_row and
                       double_click_frames > 0
                        open_selected()
                    else {
                        selected_row = clicked_row
                        draw_rows()
                        draw_scrollbar()
                        last_clicked_row = clicked_row
                        double_click_frames = 20
                    }
                } else if input.inside(280, 79, 12, 85)
                    use_scrollbar()
                else if input.inside(20, 181, 33, 16)
                    go_up()
                else if input.inside(56, 181, 45, 16)
                    open_selected()
                else if input.inside(104, 181, 75, 16)
                    run_new_file()
                else if input.inside(182, 181, 69, 16)
                    run_new_folder()
                else if input.inside(20, 204, 63, 16)
                    run_selected_operation(1)
                else if input.inside(86, 204, 48, 16)
                    run_selected_operation(2)
                else if input.inside(137, 204, 63, 16)
                    run_selected_operation(3)
                else if input.inside(203, 204, 72, 16)
                    refresh()
                else if input.inside(284, 24, 15, 13)
                    close_window = true
            }

            if input.key == $11 or input.key == $1d
                move_down()
            else if input.key == $91 or input.key == $9d
                move_up()
            else if input.key == $0d or input.key == 'O' or input.key == 'o'
                open_selected()
            else if input.key == 'N' or input.key == 'n'
                run_new_file()
            else if input.key == 'F' or input.key == 'f'
                run_new_folder()
            else if input.key == 'R' or input.key == 'r'
                run_selected_operation(1)
            else if input.key == 'M' or input.key == 'm'
                run_selected_operation(2)
            else if input.key == 'D' or input.key == 'd'
                run_selected_operation(3)
            else if input.key == 'U' or input.key == 'u'
                go_up()
            else if input.key == $12
                refresh()
        } until close_window or input.key == $1b

        diskio.lf_end_list()
        input.key = 0
    }
}
