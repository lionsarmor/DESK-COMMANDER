%import desktop
%import splash

; Keep the KERNAL and BASIC zero-page locations intact. DESK COMMANDER relies
; on ROM services for its keyboard, mouse, RTC, graphics, and future disk I/O.
%zeropage basicsafe

; -----------------------------------------------------------------------------
; DESK COMMANDER program entry point
; -----------------------------------------------------------------------------
;
; Keeping start() boring is deliberate. It should describe the life of the app
; at a glance while details stay inside small, named modules.

main {
    sub start() {
        splash.show()
        splash.wait_for_continue()

        desktop.show()
        desktop.run()
    }
}
