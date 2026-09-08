%address $a000
%memtop $c000
%output library
%import comms_emoji

main {
    %jmptable (comms_emoji.draw_small, comms_emoji.draw_big,
               comms_emoji.draw_picker, comms_emoji.draw_invalid_ip,
               comms_emoji.draw_conversation_button,
               comms_emoji.secret_dialog)
    sub start() { }
}
