%address $a000
%memtop $c000
%output library

%import market_fetch

; Bank 9 entries: initialization $A000, one quote $A003, group refresh $A006.
main {
    %jmptable (market_fetch.refresh, market_fetch.refresh_group)

    sub start() { }
}
