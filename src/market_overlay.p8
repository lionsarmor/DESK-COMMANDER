%address $a000
%memtop $c000
%output library

%import market_app

; Bank 8 app entry: startup/BSS initialization is $A000 and open is $A003.
main {
    %jmptable (market_app.open)

    sub start() { }
}
