%import syslib
%import state_data

; -----------------------------------------------------------------------------
; Small preferences shared by every DESK COMMANDER application
; -----------------------------------------------------------------------------
;
; Values stay in ordinary RAM while the program runs and are mirrored into the
; shared device-8 state image whenever they change. Voice 15 is reserved for
; the quiet interface click.

preferences {
    bool sound_enabled = true
    bool use_24_hour_clock = true

    sub save() {
        state_data.write(state_data.PREF_SOUND, sound_enabled as ubyte)
        state_data.write(state_data.PREF_CLOCK, use_24_hour_clock as ubyte)
        state_data.save()
    }

    sub silence_click_voice() {
        cx16.vpoke(1, $f9fe, 0)
    }

    sub play_click() {
        if not sound_enabled
            return

        ; About 900 Hz, triangle wave, low volume, for one video frame.
        ; It is deliberately closer to a soft key tap than an arcade beep.
        cx16.vpoke(1, $f9fc, $70)
        cx16.vpoke(1, $f9fd, $09)
        cx16.vpoke(1, $f9fe, %11000110)
        cx16.vpoke(1, $f9ff, %10000000)
        sys.waitvsync()
        silence_click_voice()
    }

    sub toggle_sound() {
        sound_enabled = not sound_enabled
        if not sound_enabled
            silence_click_voice()
        else
            play_click()
        save()
    }
}
