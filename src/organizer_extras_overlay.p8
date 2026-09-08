%address $a000
%memtop $c000
%output library
%import organizer_extras

main {
    %jmptable (organizer_extras.open_note_reader,
               organizer_extras.edit_long_email,
               organizer_extras.migrate_directory_records,
               organizer_extras.show_contact,
               organizer_extras.show_contact_preview,
               organizer_extras.show_edit_body)
    sub start() { }
}
