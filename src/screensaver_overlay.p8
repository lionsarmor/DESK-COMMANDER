%address $a000
%memtop $c000
%output library

%import screensaver

; Bank 18 entry table: initialize the library and run the screensaver.
main {
    %jmptable (screensaver.open)

    sub start() { }
}
