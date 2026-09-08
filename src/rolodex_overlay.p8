%address $a000
%memtop $c000
%output library

%import rolodex_app

; Bank 19 keeps the contact database UI out of conventional program RAM.
; Entry: initialization $A000, open Desk Directory $A003.
main {
    %jmptable (rolodex_app.open)

    sub start() { }
}
