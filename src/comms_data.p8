%import state_data

; Shared Comms data lives in VERA so the UI bank and network bank can exchange
; bounded lists without pointing into one another's hidden high RAM.
comms_data {
    const ubyte VRAM_BANK = 1
    const uword CACHE = $7000
    const uword FRIENDS = CACHE + 16
    const uword GROUPS = CACHE + 160
    const uword MESSAGES = CACHE + 320
    const uword ACTION = CACHE + 540
    const uword SELECTED_KIND = CACHE + 575
    const uword SELECTED_NAME = CACHE + 576
    const uword MESSAGE_TEXT = CACHE + 594
    const uword STATUS = CACHE + 630
    const ubyte MAX_FRIENDS = 8
    const ubyte MAX_GROUPS = 4
    const ubyte MAX_MESSAGES = 4

    const uword USERNAME = state_data.COMMS + 4
    const uword HOST = state_data.COMMS + 21

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
        clear(MESSAGES, 220)
        clear(ACTION, 124)
    }

    sub set_username(str value) { copy_to(USERNAME, value, 16) state_data.save() }
    sub get_username(str value) { copy_from(USERNAME, value, 16) }
    sub set_host(str value) { copy_to(HOST, value, 31) state_data.save() }
    sub get_host(str value) { copy_from(HOST, value, 31) }
    sub has_username() -> bool { return read(USERNAME) != 0 }
    sub has_host() -> bool { return read(HOST) != 0 }
    sub configured() -> bool { return read(USERNAME) != 0 and read(HOST) != 0 }

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
    sub set_direct_scroll(ubyte value) { write(CACHE + 3, value) }
    sub set_group_scroll(ubyte value) { write(CACHE + 4, value) }
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
    sub set_message(str value) { copy_to(MESSAGE_TEXT, value, 32) }
    sub get_message(str value) { copy_from(MESSAGE_TEXT, value, 32) }

    sub clear_messages() { write(CACHE + 2, 0) clear(MESSAGES, 200) }
    sub add_message(str sender, str text) {
        ubyte count = message_count()
        if count >= MAX_MESSAGES return
        copy_to(MESSAGES + (count as uword) * 50, sender, 16)
        copy_to(MESSAGES + (count as uword) * 50 + 17, text, 32)
        write(CACHE + 2, count + 1)
    }
    sub copy_sender(ubyte index, str value) { copy_from(MESSAGES + (index as uword) * 50, value, 16) }
    sub copy_message(ubyte index, str value) { copy_from(MESSAGES + (index as uword) * 50 + 17, value, 32) }
}
