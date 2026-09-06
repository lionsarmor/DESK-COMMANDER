; -----------------------------------------------------------------------------
; DESK COMMANDER application identity
; -----------------------------------------------------------------------------
;
; Keep names, version numbers, and copyright information in one place. That
; prevents the splash screen, About box, and future file headers from slowly
; disagreeing with each other.

appmeta {
    %option ignore_unused

    ; Prog8 strings are always mutable storage, so they are ordinary module
    ; variables rather than const values even though we treat them as read-only.
    str NAME = iso:"DESK COMMANDER"
    str VERSION = iso:"VERSION 0.3.0 - ALPHA"
    str CREATOR = iso:"A RODDY PRODUCTION"
    str COPYRIGHT = iso:"COPYRIGHT 2026 RODDY"
}
