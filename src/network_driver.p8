%import syslib
%import strings

; -----------------------------------------------------------------------------
; TexElec X16 Serial & ESP32 Network Card driver
; -----------------------------------------------------------------------------
;
; The card's first 16450-compatible UART is the ZiModem network port. This
; alpha intentionally supports the factory-default IO7-low address only.

network_driver {
    &ubyte DATA = $9fe0          ; receive buffer / transmit holding / DLL
    &ubyte IER = $9fe1           ; interrupt enable / divisor high
    &ubyte FCR = $9fe2           ; FIFO control
    &ubyte LCR = $9fe3           ; line control
    &ubyte MCR = $9fe4           ; modem control
    &ubyte LSR = $9fe5           ; line status
    &ubyte MSR = $9fe6           ; modem status
    &ubyte SCRATCH = $9fe7       ; safe read/write presence probe

    const ubyte RESPONSE_SIZE = 193

    ubyte[RESPONSE_SIZE] response
    ubyte response_length
    bool card_present
    bool modem_present
    ubyte[6] result_line
    ubyte result_line_length
    bool result_seen
    bool result_ok

    sub detect_card() -> bool {
        ubyte saved = SCRATCH

        ; A real 16450 scratch register retains both patterns. Empty expansion
        ; space does not. Restore the original byte before returning.
        SCRATCH = $55
        if SCRATCH != $55 {
            SCRATCH = saved
            card_present = false
            return false
        }
        SCRATCH = $aa
        if SCRATCH != $aa {
            SCRATCH = saved
            card_present = false
            return false
        }
        SCRATCH = saved
        card_present = true
        initialize_uart()
        return true
    }

    sub initialize_uart() {
        ; 14.7456 MHz / 16 gives a 921600 baud base. Divisor 8 is 115200.
        IER = 0
        LCR = $80                ; expose divisor registers
        DATA = 8
        IER = 0
        LCR = $03                ; 8 data bits, no parity, 1 stop bit
        FCR = $07                ; enable and clear both 16-byte FIFOs

        ; DTR + RTS are asserted and hardware auto-RTS/CTS is enabled. MCR bit
        ; 3 stays clear: on this UART that keeps Option Pin A high, as ZiModem
        ; requires for automatic command/stream transitions.
        MCR = $23
        flush_receiver()
    }

    sub flush_receiver() {
        ubyte discarded
        while LSR & 1 != 0
            discarded = DATA
    }

    sub transmit(ubyte character) -> bool {
        uword timeout = 0

        ; Bit 5 means the transmit holding register can accept a byte.
        while LSR & $20 == 0 and timeout < 60000
            timeout++
        if timeout == 60000
            return false
        DATA = character
        return true
    }

    sub set_response(str message) {
        ubyte index = 0
        while message[index] != 0 and index < RESPONSE_SIZE - 1 {
            response[index] = message[index]
            index++
        }
        response[index] = 0
        response_length = index
    }

    sub track_result(ubyte character) {
        ; ZiModem finishes an AT command with a line containing OK or ERROR.
        ; Track that line separately so a long Wi-Fi list can fill the visible
        ; response buffer without hiding the command's final result.
        if character == $0d or character == $0a {
            if result_line_length == 2 and
               result_line[0] == 'O' and result_line[1] == 'K' {
                result_seen = true
                result_ok = true
            } else if result_line_length == 5 and
                      result_line[0] == 'E' and result_line[1] == 'R' and
                      result_line[2] == 'R' and result_line[3] == 'O' and
                      result_line[4] == 'R' {
                result_seen = true
                result_ok = false
            }
            result_line_length = 0
        } else if result_line_length < 5 {
            result_line[result_line_length] = character
            result_line_length++
        } else
            result_line_length = 6
    }

    sub read_response(uword maximum_frames) {
        uword frame = 0
        ubyte quiet_frames = 0

        response_length = 0
        response[0] = 0
        result_line_length = 0
        result_seen = false
        result_ok = false
        while frame < maximum_frames {
            bool received_this_frame = false
            while LSR & 1 != 0 {
                ubyte character = DATA
                received_this_frame = true
                track_result(character)
                if response_length < RESPONSE_SIZE - 1 {
                    if character < 32 and character != $0d and character != $0a
                        character = ' '
                    response[response_length] = character
                    response_length++
                    response[response_length] = 0
                }
            }

            if received_this_frame
                quiet_frames = 0
            else
                quiet_frames++
            ; Do not stop on an echoed command. Wait for ZiModem's complete
            ; result line, then allow a few frames for the final characters.
            if result_seen and quiet_frames > 3
                return

            sys.waitvsync()
            frame++
        }
    }

    sub send_command(str command, uword wait_frames) -> bool {
        ubyte index = 0

        if not card_present {
            set_response(iso:"CARD NOT DETECTED")
            return false
        }

        flush_receiver()
        while command[index] != 0 {
            if not transmit(command[index]) {
                set_response(iso:"UART SEND TIMEOUT")
                return false
            }
            index++
        }
        if not transmit($0d) {
            set_response(iso:"UART SEND TIMEOUT")
            return false
        }
        read_response(wait_frames)
        return result_seen and result_ok
    }

    sub response_contains(str wanted) -> bool {
        ubyte wanted_length = strings.length(wanted)
        ubyte start = 0

        if wanted_length == 0
            return true
        while start + wanted_length <= response_length {
            ubyte offset = 0
            bool matches = true
            while offset < wanted_length {
                if response[start + offset] != wanted[offset]
                    matches = false
                offset++
            }
            if matches
                return true
            start++
        }
        return false
    }

    sub detect_modem() -> bool {
        modem_present = false
        if not detect_card()
            return false
        ; ATI4 identifies ZiModem and leaves its firmware/version response in
        ; the response buffer. A plain AT would also accept unrelated modems.
        modem_present = send_command(iso:"ATI4", 180)
        return modem_present
    }
}
