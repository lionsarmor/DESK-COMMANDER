%address $a000
%memtop $c000
%output library

%import file_manager

; A loadable Desk Commander app. $A000 initializes its private variables and
; $A003 opens the window; those addresses stay stable as implementation grows.
main {
    %jmptable (file_manager.open)

    sub start() { }
}
