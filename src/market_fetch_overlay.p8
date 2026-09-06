%address $a000
%memtop $c000
%output library

%import market_fetch

; Bank 9 network worker entry: initialization is $A000 and refresh is $A003.
main {
    %jmptable (market_fetch.refresh)

    sub start() { }
}
