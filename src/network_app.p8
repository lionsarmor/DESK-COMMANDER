%import gfx_lores
%import input
%import network_driver
%import network_mailbox
%import state_data
%import strings
%import theme

; -----------------------------------------------------------------------------
; DESK COMMANDER Network Setup
; -----------------------------------------------------------------------------
;
; This is a real front end for the TexElec card's ZiModem UART. Credentials are
; held only for the join attempt and are erased immediately afterward.

network_app {
    extsub @bank 13 $a003 = draw_network_list() clobbers(A, X, Y)
    extsub @bank 13 $a006 = draw_network_controls() clobbers(A, X, Y)

    ; Wi-Fi allows a 32-byte SSID and a 63-byte WPA passphrase. The extra byte
    ; in each array is the terminating zero used by Prog8 strings.
    ubyte[33] ssid
    ubyte[64] password
    ubyte[104] command
    ubyte[36] line_buffer
    bool wifi_connected

    const ubyte VISIBLE_NETWORKS = 5

    sub prepare_uart() -> bool {
        ; Never trust a flag left behind by an earlier mouse click. The
        ; network app lives in a loadable RAM bank, and physical testing showed
        ; that an older build could display a detected card yet reject the very
        ; next action with "PRESS DETECT FIRST". Re-probing the harmless UART
        ; scratch register takes almost no time and proves that $9FE0 is still
        ; available before every real operation.
        ;
        ; detect_card() also reapplies the documented 115200/8N1/FIFO/RTS-CTS
        ; configuration. Therefore Scan, Join, and Status are self-contained:
        ; the user may press any of them without pressing Detect first.
        if network_driver.detect_card()
            return true

        network_driver.modem_present = false
        network_driver.set_response(
            iso:"NO UART AT $9FE0. CHECK CARD/DIP.")
        draw_state()
        draw_response()
        return false
    }

    sub save_connection_state() {
        state_data.write(state_data.NETWORK_CONNECTED, wifi_connected as ubyte)
        state_data.save()
    }

    sub draw_state() {
        gfx_lores.fillrect(14, 45, 292, 55, theme.PAPER)
        gfx_lores.text(20, 48, theme.BLUE, iso:"CARD")
        if network_driver.card_present
            gfx_lores.text(88, 48, theme.GREEN, iso:"TEXELEC AT $9FE0")
        else
            gfx_lores.text(88, 48, theme.RED, iso:"NOT DETECTED")

        gfx_lores.text(20, 65, theme.BLUE, iso:"MODEM")
        if network_driver.modem_present
            gfx_lores.text(88, 65, theme.GREEN, iso:"ZIMODEM READY")
        else
            gfx_lores.text(88, 65, theme.RED, iso:"NO RESPONSE")

        gfx_lores.text(20, 82, theme.BLUE, iso:"WIFI")
        if wifi_connected
            gfx_lores.text(88, 82, theme.GREEN, iso:"CONNECTED")
        else
            gfx_lores.text(88, 82, theme.RED, iso:"OFFLINE")
    }

    sub draw_response() {
        ; After a successful scan this panel becomes the actual selector.
        ; Keeping selection in the main window is simpler than opening a
        ; second list over the first one, and it lets the mouse and arrow keys
        ; behave like a small desktop list box.
        if network_mailbox.count > 0 {
            draw_network_list()
            return
        }

        ; Clip diagnostics before drawing. Raw CR/LF bytes previously appeared
        ; as junk such as "OKMJ" and a long reply could overrun the panel.
        gfx_lores.fillrect(14, 104, 292, 105, theme.NAVY)
        ubyte source = 0
        while source < network_driver.response_length and
              (network_driver.response[source] == $0d or
               network_driver.response[source] == $0a)
            source++
        ubyte column = 0
        while source < network_driver.response_length and column < 35 and
              network_driver.response[source] >= 32 {
            line_buffer[column] = network_driver.response[source]
            source++
            column++
        }
        line_buffer[column] = 0
        gfx_lores.text(20, 111, theme.PAPER, line_buffer)
    }

    sub draw_window() {
        gfx_lores.fillrect(0, 18, 320, 222, theme.PAPER)
        gfx_lores.fillrect(0, 18, 320, 22, theme.BLUE)
        ; Visible hardware-test revision: if R13 is absent, an older overlay is
        ; being loaded from the SD card.
        gfx_lores.text(8, 25, theme.PAPER, iso:"TEXELEC NET SETUP R13")
        gfx_lores.fillrect(299, 22, 15, 13, theme.RED)
        gfx_lores.text(303, 25, theme.PAPER, iso:"X")
        draw_state()
        draw_response()
        draw_network_controls()
    }

    sub valid_password_key(ubyte key) -> bool {
        return ((key >= 32 and key <= 126) or
                (key >= $c1 and key <= $da)) and key != '"'
    }

    sub iso_field_key(ubyte key) -> ubyte {
        ; GETIN reports ordinary letters as PETSCII A-Z and shifted letters as
        ; $C1-$DA. In an ISO text field those mean lowercase and uppercase.
        ; This preserves the exact case required by WPA passwords.
        if key >= $c1 and key <= $da
            return key - $80
        if key >= $41 and key <= $5a
            return key + 32
        return key
    }

    sub draw_password_field() {
        ubyte length = strings.length(password)
        ubyte index
        ubyte visible_length = length

        gfx_lores.fillrect(44, 111, 232, 23, theme.INK)
        gfx_lores.fillrect(47, 114, 226, 17, theme.PAPER)

        ; The field is 27 characters wide. Show the newest end of a long value
        ; while typing and never write more mask characters than line_buffer
        ; can hold.
        if visible_length > 27
            visible_length = 27
        if visible_length > 0 {
            for index in 0 to visible_length - 1
                line_buffer[index] = '*'
        }
        line_buffer[visible_length] = 0
        gfx_lores.text(52, 118, theme.INK, line_buffer)
    }

    sub ask_password() -> bool {
        bool accepted = false
        bool done = false
        ubyte length

        gfx_lores.fillrect(35, 72, 250, 112, theme.INK)
        gfx_lores.fillrect(32, 69, 250, 112, theme.PAPER)
        gfx_lores.rect(32, 69, 250, 112, theme.INK)
        gfx_lores.fillrect(33, 70, 248, 18, theme.BLUE)
        gfx_lores.text(42, 75, theme.PAPER, iso:"WIFI PASSWORD")
        draw_password_field()
        gfx_lores.fillrect(119, 142, 64, 17, theme.GREEN)
        gfx_lores.rect(119, 142, 64, 17, theme.INK)
        gfx_lores.text(144, 147, theme.INK, iso:"OK")
        gfx_lores.text(96, 164, theme.BLUE, iso:"ESC CANCEL")

        do {
            sys.waitvsync()
            input.poll()
            length = strings.length(password)
            if input.key == $14 {
                if length > 0
                    password[length - 1] = 0
                draw_password_field()
            } else if valid_password_key(input.key) and length < 63 {
                password[length] = iso_field_key(input.key)
                password[length + 1] = 0
                draw_password_field()
            } else if input.key == $0d {
                ; An empty password is valid for an open access point.
                accepted = true
                done = true
            }

            if input.left_pressed() {
                if input.inside(119, 142, 64, 17) {
                    accepted = true
                    done = true
                }
            }
        } until done or input.key == $1b

        input.key = 0
        return accepted
    }

    sub clear_secret() {
        ubyte index
        for index in 0 to 63
            password[index] = 0
        for index in 0 to 103
            command[index] = 0
    }

    sub read_connection_status() -> bool {
        void network_driver.send_command(iso:"ATI2", 180)

        ; ATI2 returns only the current local IP followed by the result code.
        ; A successful command is not enough: 0.0.0.0 means DHCP has not
        ; produced a usable connection.
        ; A dotted ATI2 result is itself stronger evidence than its sometimes
        ; malformed trailing result line on physical firmware 4.0.2.
        return network_driver.response_contains(iso:".") and
               not network_driver.response_contains(iso:"0.0.0.0")
    }

    sub choose_access_point() -> bool {
        if network_mailbox.count == 0 {
            network_driver.set_response(iso:"SCAN FIRST - NO NETWORK LIST")
            draw_response()
            return false
        }

        ; SCAN already left one row highlighted. JOIN uses that selection
        ; directly, then asks only for the password.
        ubyte index = 0
        while index < 32 and
              network_mailbox.character(network_mailbox.selected, index) != 0 {
            ssid[index] = network_mailbox.character(network_mailbox.selected, index)
            index++
        }
        ssid[index] = 0
        return true
    }

    sub detect() {
        bool found

        wifi_connected = false
        network_mailbox.clear()
        network_driver.set_response(iso:"DETECTING MODEM... PLEASE WAIT")
        draw_response()
        sys.waitvsync()
        found = network_driver.detect_modem()
        if found
            network_driver.set_response(iso:"MODEM READY - PRESS SCAN")
        else
            network_driver.set_response(iso:"MODEM NOT READY")
        draw_state()
        draw_response()
    }

    sub scan() {
        network_mailbox.clear()
        network_driver.set_response(iso:"SCANNING... PLEASE WAIT")
        draw_response()
        sys.waitvsync()

        ; Re-probe on every action. This deliberately removes the old
        ; state-dependent "PRESS DETECT FIRST" path.
        if not prepare_uart()
            return
        ; A hardware Wi-Fi scan can take several seconds.
        ; DESK COMMANDER uses the X16 ISO font, so use ZiModem's ASCII form.
        ; Allow the ESP32 up to 15 seconds for a crowded-band scan.
        network_driver.begin_network_capture()
        bool answered = network_driver.send_command(iso:"ATW10", 900)
        network_driver.end_network_capture()
        if answered or network_driver.response_length > 0
            network_driver.modem_present = true
        network_mailbox.scroll = 0
        draw_state()
        draw_response()
    }

    sub build_join_command() {
        ubyte output = 0
        ubyte index = 0

        command[output] = 'A'
        output++
        command[output] = 'T'
        output++
        command[output] = 'W'
        output++
        command[output] = '"'
        output++
        while ssid[index] != 0 {
            command[output] = ssid[index]
            output++
            index++
        }
        command[output] = ','
        output++
        index = 0
        while password[index] != 0 {
            command[output] = password[index]
            output++
            index++
        }
        command[output] = '"'
        output++
        command[output] = 0
    }

    sub join_wifi() {
        if not prepare_uart()
            return
        if not choose_access_point() {
            draw_window()
            return
        }
        password[0] = 0
        if not ask_password() {
            clear_secret()
            draw_window()
            return
        }

        build_join_command()
        network_driver.set_response(iso:"CONNECTING... PLEASE WAIT")
        draw_window()
        sys.waitvsync()
        ; ZiModem performs association and DHCP inside ATW. Regardless of its
        ; result-line formatting, query ATI2 afterward and trust the actual IP.
        bool answered = network_driver.send_command(command, 900)
        if answered or network_driver.response_length > 0
            network_driver.modem_present = true
        clear_secret()
        wifi_connected = read_connection_status()
        ; Persist both success and failure so the desktop header agrees with
        ; the verified live state as soon as this overlay closes.
        save_connection_state()
        network_mailbox.clear()
        draw_state()
        draw_response()
    }

    sub status() {
        network_mailbox.clear()
        network_driver.set_response(iso:"CHECKING CONNECTION... PLEASE WAIT")
        draw_response()
        sys.waitvsync()
        if not prepare_uart()
            return
        wifi_connected = read_connection_status()
        if network_driver.response_length > 0
            network_driver.modem_present = true
        save_connection_state()
        draw_state()
        draw_response()
    }

    sub disconnect() {
        ; ZiModem has no non-destructive command that forgets only the current
        ; access point. ATH safely closes every open network socket; Desk
        ; Commander then goes offline without erasing saved modem credentials.
        network_mailbox.clear()
        network_driver.set_response(iso:"DISCONNECTING... PLEASE WAIT")
        draw_response()
        sys.waitvsync()
        if network_driver.detect_card()
            void network_driver.send_command(iso:"ATH", 180)
        wifi_connected = false
        save_connection_state()
        network_driver.set_response(iso:"DISCONNECTED - WIFI IS OFFLINE")
        draw_state()
        draw_response()
    }

    sub open() {
        bool close_window = false

        ssid[0] = 0
        password[0] = 0
        wifi_connected = false
        network_driver.card_present = false
        network_driver.modem_present = false
        network_mailbox.clear()
        network_driver.set_response(iso:"READY - USE THE COLORED CONTROLS")
        draw_window()

        do {
            sys.waitvsync()
            input.poll()

            if input.left_pressed() {
                if network_mailbox.count > 0 and
                   input.inside(18, 108, 280, 95) {
                    ubyte row = (lsb(input.mouse_y) - 108) / 19
                    ubyte entry = network_mailbox.scroll + row
                    if row < VISIBLE_NETWORKS and
                       entry < network_mailbox.count {
                        network_mailbox.selected = entry
                        draw_response()
                    }
                } else if input.inside(4, 214, 50, 20)
                    detect()
                else if input.inside(57, 214, 40, 20)
                    scan()
                else if input.inside(100, 214, 40, 20)
                    join_wifi()
                else if input.inside(143, 214, 50, 20)
                    status()
                else if input.inside(196, 214, 50, 20)
                    disconnect()
                else if input.inside(249, 214, 50, 20) or
                        input.inside(299, 22, 15, 13)
                    close_window = true
            }

            if input.key == $91 and network_mailbox.count > 0 {
                if network_mailbox.selected > 0 {
                    network_mailbox.selected--
                    if network_mailbox.selected < network_mailbox.scroll
                        network_mailbox.scroll = network_mailbox.selected
                    draw_response()
                }
            } else if input.key == $11 and network_mailbox.count > 0 {
                if network_mailbox.selected + 1 < network_mailbox.count {
                    network_mailbox.selected++
                    if network_mailbox.selected >=
                       network_mailbox.scroll + VISIBLE_NETWORKS
                        network_mailbox.scroll++
                    draw_response()
                }
            } else if input.wheel > 0 and network_mailbox.count > 0 {
                if network_mailbox.selected > 0 {
                    network_mailbox.selected--
                    if network_mailbox.selected < network_mailbox.scroll
                        network_mailbox.scroll = network_mailbox.selected
                    draw_response()
                }
            } else if input.wheel < 0 and network_mailbox.count > 0 {
                if network_mailbox.selected + 1 < network_mailbox.count {
                    network_mailbox.selected++
                    if network_mailbox.selected >=
                       network_mailbox.scroll + VISIBLE_NETWORKS
                        network_mailbox.scroll++
                    draw_response()
                }
            }
        } until close_window or input.key == $1b

        clear_secret()
        input.key = 0
    }
}
