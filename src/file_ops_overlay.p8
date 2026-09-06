%address $a000
%memtop $c000
%output library

%import file_ops

; Bank 5 service table. $A000 initializes BSS; callable dialogs begin at $A003
; and must remain in this order because File Manager uses fixed far addresses.
main {
    %jmptable (
        file_ops.new_folder,
        file_ops.new_file,
        file_ops.rename_item,
        file_ops.move_item,
        file_ops.delete_item
    )

    sub start() { }
}
