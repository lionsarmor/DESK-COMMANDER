%address $a000
%memtop $c000
%output library

%import chat_network

; Bank 15 chat-service jump table. Comms UI calls these through shared VERA.
main {
    %jmptable (chat_network.sync, chat_network.load_messages,
               chat_network.send_message, chat_network.create_account,
               chat_network.add_friend, chat_network.create_group,
               chat_network.group_action)
    sub start() { }
}
