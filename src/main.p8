%import desktop
%import diskio
%import input
%import preferences
%import splash
%import state_data
%import syslib
%import theme

; Keep the KERNAL and BASIC zero-page locations intact. DESK COMMANDER relies
; on ROM services for keyboard, mouse, RTC, graphics, and device-8 disk I/O.
%zeropage basicsafe

; -----------------------------------------------------------------------------
; DESK COMMANDER program entry point
; -----------------------------------------------------------------------------
;
; Keeping start() boring is deliberate. It should describe the life of the app
; at a glance while details stay inside small, named modules.

main {
    extsub @bank 10 $a003 = initialize_state_image() clobbers(A, X, Y)

    sub load_persistent_state() {
        ; The state service stays resident in bank 10 so every app can save
        ; after a meaningful change without growing the already-full core PRG.
        cx16.rambank(10)
        cx16.r0 = diskio.loadlib(iso:"ZZSTATE.BIN", $a000)
        cx16.rambank(0)
        if cx16.r0 != 0
            initialize_state_image()
    }

    sub start() {
        ; Bank 0 contains executable code. Larger app data may use other banks,
        ; and every app restores this bank before returning to the desktop.
        load_persistent_state()
        preferences.sound_enabled = state_data.read(state_data.PREF_SOUND) != 0
        preferences.use_24_hour_clock = state_data.read(state_data.PREF_CLOCK) != 0
        theme.current_package = state_data.read(state_data.THEME_PACKAGE)
        input.mouse_preset = state_data.read(state_data.MOUSE_PRESET)
        splash.show()
        splash.wait_for_continue()

        desktop.show()
        desktop.run()
    }
}
