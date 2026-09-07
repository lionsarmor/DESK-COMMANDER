%import comms_data
%import network_driver

; ZiModem HTTP client for the small LAN chat protocol. The browser uses JSON;
; the X16 receives short pipe-delimited lines that fit its 256-byte UART cache.
chat_network {
    ; ZiModem and the HTTP server speak 7-bit ASCII. Prog8's normal character
    ; literals follow the X16/PETSCII character set, where (for example) 'F'
    ; compiles as $c6 instead of ASCII $46. Keep every protocol marker numeric
    ; so sidebar sync and message parsing behave the same on real hardware.
    const ubyte ASCII_F = $46
    const ubyte ASCII_G = $47
    const ubyte ASCII_M = $4d
    const ubyte ASCII_X = $58
    const ubyte ASCII_PIPE = $7c

    ubyte[32] username
    ubyte[32] host
    ubyte[33] action
    ubyte[33] selected
    ubyte[33] message
    ubyte[241] command
    ubyte[33] field_one
    ubyte[33] field_two

    sub append(str source, ubyte output) -> ubyte {
        ubyte index = 0
        while source[index] != 0 and output < 239 {
            command[output] = source[index]
            output++
            index++
        }
        return output
    }

    sub hex_digit(ubyte value) -> ubyte {
        if value < 10
            return $30 + value
        return $41 + value - 10
    }

    sub append_encoded(str source, ubyte output) -> ubyte {
        ubyte index = 0
        while source[index] != 0 and output < 236 {
            ubyte value = source[index]
            if (value >= $41 and value <= $5a) or
                      (value >= $61 and value <= $7a) or
                      (value >= $30 and value <= $39) or
                      value == $2e or value == $2d or value == $5f {
                command[output] = value
                output++
            } else {
                ; Encode spaces and punctuation instead of dropping them. This
                ; makes the inline composer match what the server receives.
                command[output] = $25
                command[output + 1] = hex_digit(value >> 4)
                command[output + 2] = hex_digit(value & $0f)
                output += 3
            }
            index++
        }
        return output
    }

    sub begin_request(str endpoint) -> ubyte {
        ubyte output = 0
        comms_data.get_username(username)
        comms_data.get_host(host)
        ; ZiModem AT&G does not take a browser-style scheme here. Its native
        ; syntax is AT&G"HOST:PORT/path". Supplying "http://" makes some
        ; firmware builds parse "http" as the host and fail before our local
        ; server ever sees a request.
        output = append(iso:"AT&G\"", output)
        output = append(host, output)
        output = append(iso:":8088/x16/", output)
        output = append(endpoint, output)
        output = append(iso:"?user=", output)
        return append_encoded(username, output)
    }

    sub finish_request(ubyte output) -> bool {
        command[output] = '"'
        command[output + 1] = 0
        if not network_driver.modem_present and not network_driver.detect_modem()
            return false
        void network_driver.send_command(iso:"ATE0", 180)
        if not network_driver.send_command(command, 900)
            return false
        return not network_driver.response_contains(iso:"ERR")
    }

    sub simple_action(str endpoint) -> bool {
        ubyte output = begin_request(endpoint)
        comms_data.get_action(action)
        output = append(iso:"&target=", output)
        output = append_encoded(action, output)
        return finish_request(output)
    }

    sub create_account() -> bool {
        return finish_request(begin_request(iso:"account"))
    }
    sub add_friend() -> bool { return simple_action(iso:"friend") }
    sub create_group() -> bool { return simple_action(iso:"group") }

    sub add_group_member() -> bool {
        ubyte output = begin_request(iso:"groupadd")
        comms_data.selected_name(selected)
        comms_data.get_action(action)
        output = append(iso:"&target=", output)
        output = append_encoded(selected, output)
        output = append(iso:"&member=", output)
        output = append_encoded(action, output)
        return finish_request(output)
    }

    sub parse_name(ubyte source, str destination, ubyte maximum) -> ubyte {
        ubyte output = 0
        while source < network_driver.response_length and output < maximum {
            ubyte value = network_driver.response[source]
            if value == ASCII_PIPE or value == $0d or value == $0a or value == 0
                break
            destination[output] = value
            output++
            source++
        }
        destination[output] = 0
        return source
    }

    sub sync() -> bool {
        ubyte position = 0
        if not finish_request(begin_request(iso:"sync"))
            return false
        comms_data.clear_lists()
        while position + 2 < network_driver.response_length {
            ubyte kind = network_driver.response[position]
            if (kind == ASCII_F or kind == ASCII_G) and
               network_driver.response[position + 1] == ASCII_PIPE {
                position = parse_name(position + 2, field_one, 16)
                if kind == ASCII_F {
                    ubyte presence = ASCII_X
                    if network_driver.response[position] == ASCII_PIPE and
                       position + 1 < network_driver.response_length
                        presence = network_driver.response[position + 1]
                    comms_data.add_friend(presence, field_one)
                } else
                    comms_data.add_group(field_one)
            }
            position++
        }
        return true
    }

    sub load_messages() -> bool {
        ubyte output = begin_request(iso:"messages")
        ubyte position = 0
        ubyte offset = comms_data.message_offset()
        comms_data.selected_name(selected)
        command[output] = '&' output++
        command[output] = 'k' output++
        command[output] = 'i' output++
        command[output] = 'n' output++
        command[output] = 'd' output++
        command[output] = '=' output++
        command[output] = comms_data.selected_kind() output++
        output = append(iso:"&target=", output)
        output = append_encoded(selected, output)
        output = append(iso:"&offset=", output)
        if offset >= 10 {
            command[output] = $30 + offset / 10
            output++
        }
        command[output] = $30 + offset % 10
        output++
        if not finish_request(output)
            return false
        comms_data.clear_messages()
        while position + 2 < network_driver.response_length {
            if network_driver.response[position] == ASCII_M and
               network_driver.response[position + 1] == ASCII_PIPE {
                position = parse_name(position + 2, field_one, 16)
                if network_driver.response[position] == ASCII_PIPE
                    position++
                position = parse_name(position, field_two, 32)
                comms_data.add_message(field_one, field_two)
            }
            position++
        }
        return true
    }

    sub send_message() -> bool {
        ubyte output = begin_request(iso:"send")
        comms_data.selected_name(selected)
        comms_data.get_message(message)
        output = append(iso:"&kind=", output)
        command[output] = comms_data.selected_kind() output++
        output = append(iso:"&target=", output)
        output = append_encoded(selected, output)
        output = append(iso:"&text=", output)
        output = append_encoded(message, output)
        if not finish_request(output)
            return false
        return load_messages()
    }
}
