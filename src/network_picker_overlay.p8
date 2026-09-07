%address $a000
%memtop $c000
%output library

%import network_picker

; Bank 13 entry points: initialize BSS, draw SSID dirty region, draw toolbar.
main {
    %jmptable (network_picker.draw_list, network_picker.draw_controls)

    sub start() { }
}
