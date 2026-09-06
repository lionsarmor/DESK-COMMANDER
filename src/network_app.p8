%import gfx_lores
%import input
%import network_driver
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
    ubyte[25] ssid
    ubyte[49] password
    ubyte[82] command
    ubyte[36] line_buffer
    bool wifi_connected

    sub load_saved_ssid() {
        ubyte index
        ssid[0] = 0
        if state_data.read(state_data.NETWORK) != $a5
            return
        for index in 0 to 24
            ssid[index] = state_data.read(state_data.NETWORK + 1 + index)
    }

    sub save_ssid() {
        ubyte index
        state_data.write(state_data.NETWORK, $a5)
        for index in 0 to 24
            state_data.write(state_data.NETWORK + 1 + index, ssid[index])
        state_data.save()
    }

    sub save_connection_state() {
        if wifi_connected
            state_data.write(state_data.NETWORK_CONNECTED, 1)
        else
            state_data.write(state_data.NETWORK_CONNECTED, 0)
        state_data.save()
    }

    sub draw_button(uword x, ubyte width, str label) {
        gfx_lores.fillrect(x + 1, 218, width, 17, theme.INK)
        gfx_lores.fillrect(x, 216, width, 17, theme.PAPER)
        gfx_lores.rect(x, 216, width, 17, theme.BLUE)
        gfx_lores.text(x + 5, 221, theme.INK, label)
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
        ubyte source = 0
        ubyte row

        gfx_lores.fillrect(14, 104, 292, 105, theme.NAVY)
        for row in 0 to 4 {
            ubyte column = 0
            while source < network_driver.response_length and column < 35 {
                ubyte character = network_driver.response[source]
                source++
                if character == $0d or character == $0a {
                    if column == 0
                        continue
                    break
                }
                line_buffer[column] = character
                column++
            }
            line_buffer[column] = 0
            gfx_lores.text(20, 111 + row * 18, theme.PAPER, line_buffer)
        }
    }

    sub draw_window() {
        gfx_lores.fillrect(0, 18, 320, 222, theme.PAPER)
        gfx_lores.fillrect(0, 18, 320, 22, theme.BLUE)
        gfx_lores.text(8, 25, theme.PAPER, iso:"TEXELEC NETWORK SETUP")
        gfx_lores.fillrect(299, 22, 15, 13, theme.RED)
        gfx_lores.text(303, 25, theme.PAPER, iso:"X")
        draw_state()
        draw_response()
        draw_button(8, 54, iso:"DETECT")
        draw_button(66, 44, iso:"SCAN")
        draw_button(114, 44, iso:"JOIN")
        draw_button(162, 62, iso:"STATUS")
        draw_button(254, 58, iso:"CLOSE")
    }

    sub valid_field_key(ubyte key) -> bool {
        return key >= 32 and key <= 126 and key != '"' and key != ','
    }

    sub draw_entry_field(str value, bool hidden) {
        ubyte length = strings.length(value)
        ubyte index

        gfx_lores.fillrect(44, 111, 232, 23, theme.INK)
        gfx_lores.fillrect(47, 114, 226, 17, theme.PAPER)
        if hidden {
            if length > 0 {
                for index in 0 to length - 1
                    line_buffer[index] = '*'
            }
            line_buffer[length] = 0
            gfx_lores.text(52, 118, theme.INK, line_buffer)
        } else
            gfx_lores.text(52, 118, theme.INK, value)
    }

    sub ask_field(str title, str value, ubyte maximum, bool hidden) -> bool {
        bool accepted = false
        bool done = false
        ubyte length

        gfx_lores.fillrect(35, 72, 250, 104, theme.INK)
        gfx_lores.fillrect(32, 69, 250, 104, theme.PAPER)
        gfx_lores.rect(32, 69, 250, 104, theme.INK)
        gfx_lores.fillrect(33, 70, 248, 18, theme.BLUE)
        gfx_lores.text(42, 75, theme.PAPER, title)
        draw_entry_field(value, hidden)
        gfx_lores.text(55, 148, theme.BLUE, iso:"ENTER OK   ESC CANCEL")

        do {
            sys.waitvsync()
            input.poll()
            length = strings.length(value)
            if input.key == $14 {
                if length > 0
                    value[length - 1] = 0
                draw_entry_field(value, hidden)
            } else if valid_field_key(input.key) and length < maximum {
                value[length] = input.key
                value[length + 1] = 0
                draw_entry_field(value, hidden)
            } else if input.key == $0d and length > 0 {
                accepted = true
                done = true
            }
        } until done or input.key == $1b

        input.key = 0
        return accepted
    }

    sub clear_secret() {
        ubyte index
        for index in 0 to 48
            password[index] = 0
        for index in 0 to 81
            command[index] = 0
    }

    sub detect() {
        bool found

        wifi_connected = false
        network_driver.set_response(iso:"PROBING IO7 LOW...")
        draw_window()
        found = network_driver.detect_modem()
        ; On success, keep ATI4's ZiModem firmware response visible.
        if not found and network_driver.card_present
            network_driver.set_response(iso:"CARD FOUND; ZIMODEM DID NOT ANSWER")
        else if not found
            network_driver.set_response(iso:"NO CARD AT $9FE0. CHECK DIP SETTING.")
        draw_window()
    }

    sub scan() {
        if not network_driver.modem_present {
            network_driver.set_response(iso:"DETECT THE CARD FIRST")
            draw_window()
            return
        }
        network_driver.set_response(iso:"SCANNING FOR WIFI...")
        draw_window()
        ; A hardware Wi-Fi scan can take several seconds.
        ; DESK COMMANDER uses the X16 ISO font, so use ZiModem's ASCII form.
        void network_driver.send_command(iso:"ATW5", 600)
        draw_window()
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
        if not network_driver.modem_present {
            network_driver.set_response(iso:"DETECT THE CARD FIRST")
            draw_window()
            return
        }
        if not ask_field(iso:"WIFI NETWORK NAME", ssid, 23, false) {
            draw_window()
            return
        }
        password[0] = 0
        if not ask_field(iso:"WIFI PASSWORD", password, 47, true) {
            clear_secret()
            draw_window()
            return
        }

        build_join_command()
        network_driver.set_response(iso:"CONNECTING...")
        draw_window()
        wifi_connected = network_driver.send_command(command, 900)
        clear_secret()
        if wifi_connected {
            ; Remember only the network name. ZiModem owns Wi-Fi credentials;
            ; Desk Commander never writes the password to the SD card.
            save_ssid()
            void network_driver.send_command(iso:"ATI2", 180)
        } else
            save_connection_state()
        draw_window()
    }

    sub status() {
        if not network_driver.modem_present {
            network_driver.set_response(iso:"DETECT THE CARD FIRST")
            draw_window()
            return
        }
        void network_driver.send_command(iso:"ATI2", 180)
        wifi_connected = network_driver.response_contains(iso:".") and
                         not network_driver.response_contains(iso:"0.0.0.0")
        save_connection_state()
        draw_window()
    }

    sub open() {
        bool close_window = false

        load_saved_ssid()
        password[0] = 0
        wifi_connected = false
        network_driver.card_present = false
        network_driver.modem_present = false
        network_driver.set_response(iso:"PRESS DETECT TO FIND THE CARD")
        draw_window()

        do {
            sys.waitvsync()
            input.poll()

            if input.left_pressed() {
                if input.inside(8, 216, 54, 17)
                    detect()
                else if input.inside(66, 216, 44, 17)
                    scan()
                else if input.inside(114, 216, 44, 17)
                    join_wifi()
                else if input.inside(162, 216, 62, 17)
                    status()
                else if input.inside(254, 216, 58, 17) or
                        input.inside(299, 22, 15, 13)
                    close_window = true
            }

            if input.key == 'D' or input.key == 'd'
                detect()
            else if input.key == 'W' or input.key == 'w'
                scan()
            else if input.key == 'J' or input.key == 'j'
                join_wifi()
            else if input.key == 'I' or input.key == 'i'
                status()
        } until close_window or input.key == $1b

        clear_secret()
        input.key = 0
    }
}
