; -----------------------------------------------------------------------------
; Shared persistent-state map
; -----------------------------------------------------------------------------
;
; Mutable organizer data is mirrored into one 2 KB block of VERA RAM. The
; bank-10 storage service writes that block to DCSTATE.BIN on device 8. Keeping
; the map here lets the desktop and every loadable app use the same offsets.

state_data {
    const ubyte VRAM_BANK = 1
    const uword BASE = $6000
    const uword SIZE = 2048

    const uword PREF_MARKER = BASE + 8
    const uword PREF_SOUND = BASE + 9
    const uword PREF_CLOCK = BASE + 10
    const uword THEME_MARKER = BASE + 11
    const uword THEME_PACKAGE = BASE + 12
    const uword MOUSE_MARKER = BASE + 13
    const uword MOUSE_PRESET = BASE + 14

    ; Fixed, non-overlapping ownership ranges. Keep these offsets stable within
    ; a format version; changing a range requires a migration or version bump.
    const uword NOTES = BASE + 16       ; 144 bytes: offsets 16..159
    const uword CALENDAR = BASE + 160   ; 620 bytes: offsets 160..779
    const uword ROLODEX = BASE + 780    ; 20 bytes: offsets 780..799
    const uword NETWORK = BASE + 800    ; network data begins at offset 800
    ; Last confirmed link state. This is a boot-time indicator, not a live
    ; hardware probe; opening Network Setup and pressing STATUS refreshes it.
    const uword NETWORK_CONNECTED = NETWORK + 26

    ; Market Watch owns the final 768 bytes, offsets 1280..2047.
    const uword MARKET = BASE + $0500

    ; Fixed golden-RAM mailbox used by the banked bulk-copy routines.
    &uword transfer_memory = $0750
    &uword transfer_vram = $0752
    &uword transfer_length = $0754
    &uword transfer_memory_2 = $0762
    &uword transfer_memory_3 = $0764
    &uword transfer_memory_4 = $0766
    &uword transfer_memory_5 = $0768
    &uword transfer_memory_6 = $076a
    &uword transfer_memory_7 = $076c
    &uword transfer_memory_8 = $076e

    extsub @bank 10 $a006 = persist_state_image() clobbers(A, X, Y)
    extsub @bank 10 $a009 = copy_memory_to_state() clobbers(A, X, Y)
    extsub @bank 10 $a00c = copy_state_to_memory() clobbers(A, X, Y)
    extsub @bank 10 $a00f = store_calendar_arrays() clobbers(A, X, Y)
    extsub @bank 10 $a012 = restore_calendar_arrays() clobbers(A, X, Y)

    sub read(uword address) -> ubyte {
        return cx16.vpeek(VRAM_BANK, address)
    }

    sub write(uword address, ubyte value) {
        cx16.vpoke(VRAM_BANK, address, value)
    }

    sub save() {
        persist_state_image()
    }

    sub store(uword memory_address, uword vram, uword length) {
        transfer_memory = memory_address
        transfer_vram = vram
        transfer_length = length
        copy_memory_to_state()
    }

    sub restore(uword vram, uword memory_address, uword length) {
        transfer_memory = memory_address
        transfer_vram = vram
        transfer_length = length
        copy_state_to_memory()
    }
}
