%address $a000
%memtop $c000
%output library

%import comms_app

; Bank 12 app entry: startup/BSS initialization is $A000 and open is $A003.
; Comms is isolated now so its eventual networking UI can grow safely.
main {
    %jmptable (comms_app.open)

    sub start() { }
}
