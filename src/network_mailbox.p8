; -----------------------------------------------------------------------------
; Shared Wi-Fi scan mailbox
; -----------------------------------------------------------------------------
;
; The network screen keeps this list in unbanked RAM so scan results survive
; UART work and remain available to the optional picker helper. The main build
; is capped below $9800; this reserved area stays below the X16 I/O window.

network_mailbox {
    const ubyte MAX_ACCESS_POINTS = 10
    const ubyte SSID_LENGTH = 33

    &ubyte[165] names_first = $9800
    &ubyte[165] names_second = $98a5
    &ubyte count = $994a
    &ubyte selected = $994b
    &bool accepted = $994c
    &bool picker_loaded = $994d
    &ubyte scroll = $994e

    sub clear() {
        count = 0
        selected = 0
        accepted = false
        scroll = 0
        names_first[0] = 0
        names_second[0] = 0
    }

    sub character(ubyte entry, ubyte index) -> ubyte {
        if entry < 5
            return names_first[entry * SSID_LENGTH + index]
        return names_second[(entry - 5) * SSID_LENGTH + index]
    }

    sub set_character(ubyte entry, ubyte index, ubyte value) {
        if entry < 5
            names_first[entry * SSID_LENGTH + index] = value
        else
            names_second[(entry - 5) * SSID_LENGTH + index] = value
    }
}
