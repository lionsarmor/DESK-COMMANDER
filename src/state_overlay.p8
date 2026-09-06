%address $a000
%memtop $c000
%output library

%import state_store

main {
    ; $A000 initializes this overlay's BSS. Public services follow at $A003.
    %jmptable (state_store.initialize, state_store.persist,
               state_store.memory_to_state, state_store.state_to_memory,
               state_store.calendar_to_state, state_store.state_to_calendar)

    sub start() { }
}
