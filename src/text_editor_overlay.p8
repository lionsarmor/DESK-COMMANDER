%address $a000
%memtop $c000
%output library

%import text_editor

; Bank 6 app entry: startup/BSS initialization is $A000 and open is $A003.
main {
    %jmptable (text_editor.open)

    sub start() { }
}
