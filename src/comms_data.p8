%import state_data

; Shared Comms data lives in VERA so the UI bank and network bank can exchange
; bounded lists without pointing into one another's hidden high RAM.
comms_data {
    const ubyte VRAM_BANK = 1
    const uword CACHE = $7000
    const uword FRIENDS = CACHE + 16
    const uword GROUPS = CACHE + 160
    const uword MESSAGES = CACHE + 320
    const uword ACTION = CACHE + 560
    const uword SELECTED_KIND = CACHE + 593
    const uword SELECTED_NAME = CACHE + 594
    const uword MESSAGE_TEXT = CACHE + 611
    const uword STATUS = CACHE + 708
    const ubyte MAX_FRIENDS = 8
    const ubyte MAX_GROUPS = 4
    const ubyte MAX_MESSAGE_LENGTH = 96
    const ubyte MESSAGE_RECORD_SIZE = 114 ; 17-byte sender + 97-byte text
    ; Two 96-character messages plus their senders fit safely in both this
    ; cache and ZiModem's 255-byte response transcript.
    const ubyte MAX_MESSAGES = 2

    const uword USERNAME = state_data.COMMS + 4
    const uword HOST = state_data.COMMS + 21
    const uword SECRET = state_data.COMMS_SECRET

    sub read(uword address) -> ubyte { return cx16.vpeek(VRAM_BANK, address) }
    sub write(uword address, ubyte value) { cx16.vpoke(VRAM_BANK, address, value) }

    sub clear(uword address, ubyte length) {
        ubyte index
        for index in 0 to length - 1
            write(address + index, 0)
    }

    sub copy_to(uword address, str source, ubyte maximum) {
        ubyte index = 0
        while source[index] != 0 and index < maximum {
            write(address + index, source[index])
            index++
        }
        write(address + index, 0)
    }

    sub copy_from(uword address, str destination, ubyte maximum) {
        ubyte index = 0
        while read(address + index) != 0 and index < maximum {
            destination[index] = read(address + index)
            index++
        }
        destination[index] = 0
    }

    sub initialize() {
        if state_data.read(state_data.COMMS) == 'C' and
           state_data.read(state_data.COMMS + 1) == 'H' and
           state_data.read(state_data.COMMS + 2) == 'A' and
           state_data.read(state_data.COMMS + 3) == 'T'
            return
        state_data.write(state_data.COMMS, 'C')
        state_data.write(state_data.COMMS + 1, 'H')
        state_data.write(state_data.COMMS + 2, 'A')
        state_data.write(state_data.COMMS + 3, 'T')
        clear(USERNAME, 17)
        clear(HOST, 32)
        clear(SECRET, 25)
        state_data.save()
    }

    sub reset_session() {
        ; VERA RAM is not guaranteed to contain zeroes after power-on. Comms
        ; must clear its entire temporary cache before the first frame reads
        ; counts or strings from it. Without this, a random message count can
        ; make the renderer walk hundreds of bogus rows on real hardware.
        clear(CACHE, 16)
        clear(FRIENDS, 144)
        clear(GROUPS, 160)
        clear(MESSAGES, 228)
        clear(ACTION, 192)
    }

    sub set_username(str value) { copy_to(USERNAME, value, 16) state_data.save() }
    sub get_username(str value) { copy_from(USERNAME, value, 16) }
    sub set_host(str value) { copy_to(HOST, value, 31) state_data.save() }
    sub get_host(str value) { copy_from(HOST, value, 31) }
    sub set_secret(str value) { copy_to(SECRET, value, 24) state_data.save() }
    sub get_secret(str value) { copy_from(SECRET, value, 24) }
    sub has_username() -> bool { return read(USERNAME) != 0 }
    sub has_host() -> bool { return read(HOST) != 0 }
    sub has_secret() -> bool { return read(SECRET) != 0 }
    sub configured() -> bool {
        return read(USERNAME) != 0 and read(HOST) != 0 and read(SECRET) != 0
    }

    sub clear_lists() { clear(CACHE, 3) clear(FRIENDS, 144) clear(GROUPS, 68) }
    sub friend_count() -> ubyte {
        ubyte value = read(CACHE)
        if value > MAX_FRIENDS return 0
        return value
    }
    sub group_count() -> ubyte {
        ubyte value = read(CACHE + 1)
        if value > MAX_GROUPS return 0
        return value
    }
    sub message_count() -> ubyte {
        ubyte value = read(CACHE + 2)
        if value > MAX_MESSAGES return 0
        return value
    }
    sub direct_scroll() -> ubyte { return read(CACHE + 3) }
    sub group_scroll() -> ubyte { return read(CACHE + 4) }
    sub message_offset() -> ubyte { return read(CACHE + 5) }
    sub composer_focused() -> bool { return read(CACHE + 6) != 0 }
    sub set_direct_scroll(ubyte value) { write(CACHE + 3, value) }
    sub set_group_scroll(ubyte value) { write(CACHE + 4, value) }
    sub set_message_offset(ubyte value) { write(CACHE + 5, value) }
    sub set_composer_focused(bool value) { write(CACHE + 6, value as ubyte) }
    sub set_emoji_choice(ubyte value) { write(CACHE + 7, value) }
    sub emoji_choice() -> ubyte { return read(CACHE + 7) }
    sub set_face_draw(uword x, ubyte y, ubyte face) {
        write(CACHE + 8, lsb(x))
        write(CACHE + 9, msb(x))
        write(CACHE + 10, y)
        write(CACHE + 11, face)
    }
    sub face_x() -> uword { return read(CACHE + 8) | (read(CACHE + 9) as uword) << 8 }
    sub face_y() -> ubyte { return read(CACHE + 10) }
    sub face_kind() -> ubyte { return read(CACHE + 11) }
    sub set_status(str value, ubyte color) {
        copy_to(STATUS, value, 28)
        write(STATUS + 29, color)
    }
    sub get_status(str value) { copy_from(STATUS, value, 28) }
    sub status_color() -> ubyte { return read(STATUS + 29) }

    sub add_friend(ubyte presence, str name) {
        ubyte count = friend_count()
        if count >= MAX_FRIENDS return
        ; O = online, A = away, X = offline. The server supplies this status
        ; during SYNC; the friend name remains listed regardless of status.
        write(FRIENDS + (count as uword) * 18, presence)
        copy_to(FRIENDS + (count as uword) * 18 + 1, name, 16)
        write(CACHE, count + 1)
    }

    sub add_group(str name) {
        ubyte count = group_count()
        if count >= MAX_GROUPS return
        copy_to(GROUPS + (count as uword) * 17, name, 16)
        write(CACHE + 1, count + 1)
    }

    sub copy_friend(ubyte index, str name) {
        copy_from(FRIENDS + (index as uword) * 18 + 1, name, 16)
    }
    sub friend_presence(ubyte index) -> ubyte { return read(FRIENDS + (index as uword) * 18) }
    sub copy_group(ubyte index, str name) { copy_from(GROUPS + (index as uword) * 17, name, 16) }

    sub select_chat(ubyte kind, str name) {
        write(SELECTED_KIND, kind)
        copy_to(SELECTED_NAME, name, 16)
    }
    sub selected_kind() -> ubyte { return read(SELECTED_KIND) }
    sub selected_name(str name) { copy_from(SELECTED_NAME, name, 16) }

    sub set_action(str value) { copy_to(ACTION, value, 32) }
    sub get_action(str value) { copy_from(ACTION, value, 32) }
    sub set_message(str value) { copy_to(MESSAGE_TEXT, value, MAX_MESSAGE_LENGTH) }
    sub get_message(str value) { copy_from(MESSAGE_TEXT, value, MAX_MESSAGE_LENGTH) }

    sub clear_messages() { write(CACHE + 2, 0) clear(MESSAGES, 228) }
    sub add_message(str sender, str text) {
        ubyte count = message_count()
        if count >= MAX_MESSAGES return
        copy_to(MESSAGES + (count as uword) * MESSAGE_RECORD_SIZE, sender, 16)
        copy_to(MESSAGES + (count as uword) * MESSAGE_RECORD_SIZE + 17,
                text, MAX_MESSAGE_LENGTH)
        write(CACHE + 2, count + 1)
    }
    sub copy_sender(ubyte index, str value) { copy_from(MESSAGES + (index as uword) * MESSAGE_RECORD_SIZE, value, 16) }
    sub copy_message(ubyte index, str value) { copy_from(MESSAGES + (index as uword) * MESSAGE_RECORD_SIZE + 17, value, MAX_MESSAGE_LENGTH) }

    sub message_signature() -> uword {
        ; Cheap change detector for background receive polling. It lets Comms
        ; skip a redraw when the same two visible messages come back, avoiding
        ; a periodic flash on real hardware.
        uword signature = message_count()
        ubyte index = 0
        while index < 228 {
            signature += read(MESSAGES + index)
            index++
        }
        return signature
    }
}
