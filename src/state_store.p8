%import diskio
%import state_data

; -----------------------------------------------------------------------------
; Device-8 persistence service
; -----------------------------------------------------------------------------
;
; This code runs from bank 10. It loads and saves one versioned VERA image so
; applications do not each need their own disk protocol or large RAM buffer.
; Alpha saves replace DCSTATE.BIN directly; temporary-file recovery is tracked
; explicitly in ROADMAP.md before this storage layer can be called V1-safe.

state_store {
    const ubyte FORMAT_VERSION = 1
    ubyte[65] io_buffer

    sub has_valid_header() -> bool {
        return state_data.read(state_data.BASE) == 'D' and
               state_data.read(state_data.BASE + 1) == 'C' and
               state_data.read(state_data.BASE + 2) == 'S' and
               state_data.read(state_data.BASE + 3) == 'T' and
               state_data.read(state_data.BASE + 4) == FORMAT_VERSION
    }

    sub clear_image() {
        uword offset
        for offset in 0 to state_data.SIZE - 1
            state_data.write(state_data.BASE + offset, 0)

        state_data.write(state_data.BASE, 'D')
        state_data.write(state_data.BASE + 1, 'C')
        state_data.write(state_data.BASE + 2, 'S')
        state_data.write(state_data.BASE + 3, 'T')
        state_data.write(state_data.BASE + 4, FORMAT_VERSION)
        state_data.write(state_data.PREF_MARKER, $a5)
        state_data.write(state_data.PREF_SOUND, 1)
        state_data.write(state_data.PREF_CLOCK, 1)
        state_data.write(state_data.THEME_MARKER, $a5)
        state_data.write(state_data.THEME_PACKAGE, 0)
        state_data.write(state_data.MOUSE_MARKER, $a5)
        state_data.write(state_data.MOUSE_PRESET, 0)
    }

    sub initialize() {
        diskio.drivenumber = 8

        ; Headerless VLOAD writes directly to VERA without consuming main RAM.
        if diskio.vload_raw(iso:"DCSTATE.BIN", state_data.VRAM_BANK,
                            state_data.BASE) and has_valid_header()
            return

        ; Missing, truncated, or newer/unknown data starts a clean state image.
        clear_image()
        persist()
    }

    sub persist() {
        uword offset = 0
        uword chunk
        ubyte index

        diskio.drivenumber = 8
        if not diskio.f_open_w(iso:"@:DCSTATE.BIN")
            return

        while offset < state_data.SIZE {
            chunk = state_data.SIZE - offset
            if chunk > 64
                chunk = 64
            for index in 0 to lsb(chunk) - 1
                io_buffer[index] = state_data.read(state_data.BASE + offset + index)
            if not diskio.f_write(&io_buffer, chunk) {
                diskio.f_close_w()
                return
            }
            offset += chunk
        }
        diskio.f_close_w()
    }

    sub memory_to_state() {
        uword index
        for index in 0 to state_data.transfer_length - 1
            state_data.write(state_data.transfer_vram + index,
                             state_data.transfer_memory[index])
    }

    sub state_to_memory() {
        uword index
        for index in 0 to state_data.transfer_length - 1
            state_data.transfer_memory[index] = state_data.read(
                state_data.transfer_vram + index)
    }

    sub calendar_to_state() {
        ubyte index
        state_data.write(state_data.CALENDAR + 1, state_data.transfer_memory_5[0])
        state_data.write(state_data.CALENDAR + 2, state_data.transfer_memory_6[0])
        state_data.write(state_data.CALENDAR + 3, state_data.transfer_memory_6[1])
        state_data.write(state_data.CALENDAR + 4, state_data.transfer_memory_7[0])
        state_data.write(state_data.CALENDAR + 5, state_data.transfer_memory_8[0])
        for index in 0 to 23 {
            state_data.write(state_data.CALENDAR + 6 + index,
                             state_data.transfer_memory[index])
            state_data.write(state_data.CALENDAR + 30 + index,
                             state_data.transfer_memory_2[index])
            state_data.write(state_data.CALENDAR + 54 + index,
                             state_data.transfer_memory_3[index])
        }
        for index in 0 to 47
            state_data.write(state_data.CALENDAR + 78 + index,
                             state_data.transfer_memory_4[index])
    }

    sub state_to_calendar() {
        ubyte index
        state_data.transfer_memory_5[0] = state_data.read(state_data.CALENDAR + 1)
        state_data.transfer_memory_6[0] = state_data.read(state_data.CALENDAR + 2)
        state_data.transfer_memory_6[1] = state_data.read(state_data.CALENDAR + 3)
        state_data.transfer_memory_7[0] = state_data.read(state_data.CALENDAR + 4)
        state_data.transfer_memory_8[0] = state_data.read(state_data.CALENDAR + 5)
        for index in 0 to 23 {
            state_data.transfer_memory[index] = state_data.read(
                state_data.CALENDAR + 6 + index)
            state_data.transfer_memory_2[index] = state_data.read(
                state_data.CALENDAR + 30 + index)
            state_data.transfer_memory_3[index] = state_data.read(
                state_data.CALENDAR + 54 + index)
        }
        for index in 0 to 47
            state_data.transfer_memory_4[index] = state_data.read(
                state_data.CALENDAR + 78 + index)
    }
}
