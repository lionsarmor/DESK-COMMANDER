%address $a000
%memtop $c000
%output library
%import comms_visual

main {
    %jmptable (comms_visual.draw, comms_visual.draw_sidebar,
               comms_visual.draw_messages)
    sub start() { }
}
