%address $a000
%memtop $c000
%output library

%import network_app

; Bank 7 app entry: startup/BSS initialization is $A000 and open is $A003.
main {
    %jmptable (network_app.open)

    sub start() { }
}
