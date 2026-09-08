%address $a000
%memtop $c000
%output library

%import program_launcher

; Bank 14 entry: initialization is $A000 and launch is $A003.
main {
    %jmptable (program_launcher.launch, program_launcher.validate_text)

    sub start() { }
}
