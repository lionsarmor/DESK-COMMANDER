%address $a000
%memtop $c000
%output library

%import notes_app

; Notes has its own bank so its saved list and scrolling UI can grow without
; pushing the conventional-memory desktop into the X16 I/O registers.
main {
    %jmptable (notes_app.open)

    sub start() { }
}
