%address $a000
%memtop $c000
%output library
%import organizer_extras

main {
    %jmptable (organizer_extras.open_note_reader,
               organizer_extras.edit_long_email,
               organizer_extras.migrate_directory_records)
    sub start() { }
}
