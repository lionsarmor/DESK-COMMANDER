%import app_mailbox
%import diskio
%import input
%import syslib

; -----------------------------------------------------------------------------
; External PRG launcher
; -----------------------------------------------------------------------------
;
; This code lives in high-RAM bank 14, safely outside the normal $0801 X16 PRG
; load area. That lets the KERNAL replace Desk Commander and still return here
; long enough to enter BASIC and run the newly loaded program.

program_launcher {
    sub launch() -> bool {
        diskio.drivenumber = 8
        input.disable_mouse()

        ; Address zero tells LOAD to honor the two-byte address stored in the
        ; PRG. Standard X16 programs include a short BASIC launcher at $0801.
        cx16.r0 = diskio.load(app_mailbox.filename, 0)
        if cx16.r0 == 0 {
            input.enable_mouse()
            return false
        }

        cbm.CLALL()
        cbm.kbdbuf_clear()

        ; OLD rebuilds BASIC's program pointers after the direct KERNAL LOAD;
        ; RUN starts either a BASIC program or its conventional SYS stub. The
        ; eight characters fit the X16 keyboard buffer exactly.
        cx16.kbdbuf_put('O')
        cx16.kbdbuf_put('L')
        cx16.kbdbuf_put('D')
        cx16.kbdbuf_put(':')
        cx16.kbdbuf_put('R')
        cx16.kbdbuf_put('U')
        cx16.kbdbuf_put('N')
        cx16.kbdbuf_put($0d)

        ; Carry clear requests the documented warm entry. This does not return.
        cx16.enter_basic(false)
        return true
    }
}
