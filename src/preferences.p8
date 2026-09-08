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
        ; Loadable apps have their own ordinary-RAM variables, but the saved
        ; preference lives in shared VERA RAM. Read that shared byte so Comms
        ; obeys the same mute switch as the desktop.
        if state_data.read(state_data.PREF_SOUND) == 0
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

    sub play_send() {
        if state_data.read(state_data.PREF_SOUND) == 0
            return

        ; A short rising acknowledgement for a delivered outgoing message.
        cx16.vpoke(1, $f9fc, $20)
        cx16.vpoke(1, $f9fd, $0c)
        cx16.vpoke(1, $f9fe, %11000111)
        cx16.vpoke(1, $f9ff, %10000000)
        sys.waitvsync()
        silence_click_voice()
    }

    sub play_receive() {
        if state_data.read(state_data.PREF_SOUND) == 0
            return

        ; A different, slightly higher chirp identifies incoming chat.
        cx16.vpoke(1, $f9fc, $60)
        cx16.vpoke(1, $f9fd, $11)
        cx16.vpoke(1, $f9fe, %11000111)
        cx16.vpoke(1, $f9ff, %10000000)
        sys.waitvsync()
        silence_click_voice()
    }

    sub toggle_sound() {
        sound_enabled = not sound_enabled
        ; Save first: all sound routines deliberately read the shared byte.
        save()
        if not sound_enabled
            silence_click_voice()
        else
            play_click()
    }
}
