%import app_mailbox
%import diskio
%import gfx_lores
%import input
%import strings
%import theme

; -----------------------------------------------------------------------------
; File Manager operation dialogs
; -----------------------------------------------------------------------------
;
; This code lives in its own high-RAM bank. Keeping dialogs and write commands
; out of the browser bank leaves room for better icons and more visible files.

file_ops {
    ubyte[51] edit_text

    sub copy_text(str source, str destination, ubyte maximum) {
        ubyte index = 0
        while source[index] != 0 and index < maximum {
            destination[index] = source[index]
            index++
        }
        destination[index] = 0
    }

    sub valid_key(ubyte key, bool allow_path) -> bool {
        if key < 32 or key > 126
            return false
        if key == '"' or key == '=' or key == ',' or key == '*' or key == '?' or
           key == ':'
            return false
        if key == '/' and not allow_path
            return false
        return true
    }

    sub draw_field() {
        gfx_lores.fillrect(55, 103, 210, 22, theme.INK)
        gfx_lores.fillrect(58, 106, 204, 16, theme.PAPER)
        gfx_lores.text(63, 110, theme.INK, edit_text)
    }

    sub ask(str title, str hint, str initial, bool allow_path) -> bool {
        bool done = false
        bool accepted = false
        ubyte length

        copy_text(initial, edit_text, 24)
        gfx_lores.fillrect(45, 70, 230, 105, theme.INK)
        gfx_lores.fillrect(42, 67, 230, 105, theme.PAPER)
        gfx_lores.rect(42, 67, 230, 105, theme.INK)
        gfx_lores.fillrect(43, 68, 228, 17, theme.BLUE)
        gfx_lores.text(51, 72, theme.PAPER, title)
        gfx_lores.text(55, 91, theme.BLUE, hint)
        draw_field()
        gfx_lores.rect(61, 139, 76, 20, theme.BLUE)
        gfx_lores.text(85, 145, theme.INK, iso:"OK")
        gfx_lores.rect(165, 139, 88, 20, theme.BLUE)
        gfx_lores.text(180, 145, theme.INK, iso:"CANCEL")

        do {
            sys.waitvsync()
            input.poll()

            if input.key == $14 {
                length = strings.length(edit_text)
                if length > 0
                    edit_text[length - 1] = 0
                draw_field()
            } else if valid_key(input.key, allow_path) {
                length = strings.length(edit_text)
                if length < 24 {
                    edit_text[length] = input.key
                    edit_text[length + 1] = 0
                    draw_field()
                }
            } else if input.key == $0d and strings.length(edit_text) > 0 {
                accepted = true
                done = true
            }

            if input.left_pressed() {
                if input.inside(61, 139, 76, 20) and strings.length(edit_text) > 0 {
                    accepted = true
                    done = true
                } else if input.inside(165, 139, 88, 20)
                    done = true
            }
        } until done or input.key == $1b

        input.key = 0
        return accepted
    }

    sub finish_command() {
        app_mailbox.dos_code = diskio.status_code()
        if app_mailbox.dos_code < 20
            app_mailbox.result = app_mailbox.RESULT_OK
        else
            app_mailbox.result = app_mailbox.RESULT_ERROR
    }

    sub new_folder() {
        app_mailbox.result = app_mailbox.RESULT_CANCEL
        if ask(iso:"NEW FOLDER", iso:"FOLDER NAME", iso:"", false) {
            diskio.mkdir(edit_text)
            finish_command()
        }
    }

    sub new_file() {
        app_mailbox.result = app_mailbox.RESULT_CANCEL
        if ask(iso:"NEW FILE", iso:"NAME.EXT", iso:"", false) {
            if diskio.f_open_w(edit_text) {
                diskio.f_close_w()
                finish_command()
            } else {
                app_mailbox.result = app_mailbox.RESULT_ERROR
                app_mailbox.dos_code = 255
            }
        }
    }

    sub rename_item() {
        app_mailbox.result = app_mailbox.RESULT_CANCEL
        if ask(iso:"RENAME ITEM", iso:"NEW NAME", app_mailbox.filename, false) {
            diskio.rename(app_mailbox.filename, edit_text)
            finish_command()
        }
    }

    sub move_item() {
        app_mailbox.result = app_mailbox.RESULT_CANCEL
        if ask(iso:"MOVE ITEM", iso:"PATH/NAME", iso:"", true) {
            copy_text(edit_text, app_mailbox.destination, 50)
            diskio.rename(app_mailbox.filename, app_mailbox.destination)
            finish_command()
        }
    }

    sub delete_item() {
        bool done = false
        bool confirmed = false

        app_mailbox.result = app_mailbox.RESULT_CANCEL
        gfx_lores.fillrect(50, 76, 220, 95, theme.INK)
        gfx_lores.fillrect(47, 73, 220, 95, theme.PAPER)
        gfx_lores.rect(47, 73, 220, 95, theme.INK)
        gfx_lores.fillrect(48, 74, 218, 17, theme.RED)
        gfx_lores.text(56, 78, theme.PAPER, iso:"DELETE ITEM?")
        copy_text(app_mailbox.filename, edit_text, 23)
        gfx_lores.text(58, 106, theme.INK, edit_text)
        gfx_lores.rect(61, 136, 82, 20, theme.RED)
        gfx_lores.text(73, 142, theme.INK, iso:"DELETE")
        gfx_lores.rect(165, 136, 88, 20, theme.BLUE)
        gfx_lores.text(180, 142, theme.INK, iso:"CANCEL")

        do {
            sys.waitvsync()
            input.poll()
            if input.key == 'Y' or input.key == 'y' {
                confirmed = true
                done = true
            } else if input.key == 'N' or input.key == 'n'
                done = true

            if input.left_pressed() {
                if input.inside(61, 136, 82, 20) {
                    confirmed = true
                    done = true
                } else if input.inside(165, 136, 88, 20)
                    done = true
            }
        } until done or input.key == $1b

        if confirmed {
            if app_mailbox.item_is_directory
                diskio.rmdir(app_mailbox.filename)
            else
                diskio.delete(app_mailbox.filename)
            finish_command()
        }
        input.key = 0
    }
}
