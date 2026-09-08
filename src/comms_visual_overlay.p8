%address $a000
%memtop $c000
%output library
%import comms_visual

main {
    %jmptable (comms_visual.draw, comms_visual.draw_sidebar,
               comms_visual.draw_messages, comms_visual.draw_composer,
               comms_visual.insert_emoji, comms_visual.draw_emoji_picker)
    sub start() { }
}
