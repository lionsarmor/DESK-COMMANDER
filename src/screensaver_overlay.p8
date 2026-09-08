%address $a000
%memtop $c000
%output library

%import screensaver

; Bank 18 entry table: initialize BSS, run the saver, and draw the two compact
; desktop cards that share this graphics bank.
main {
    %jmptable (screensaver.open)

    sub start() { }
}
