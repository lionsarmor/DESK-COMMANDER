; -----------------------------------------------------------------------------
; Shared low-memory mailbox for loadable Desk Commander apps
; -----------------------------------------------------------------------------
;
; Golden RAM is visible no matter which high-RAM bank is selected. These small
; fields let the File Manager, file-operation dialogs, and Text Editor exchange
; a filename without depending on one another's private variables.

app_mailbox {
    const ubyte RESULT_CANCEL = 0
    const ubyte RESULT_OK = 1
    const ubyte RESULT_ERROR = 2

    &ubyte[51] filename = $0780
    &ubyte[51] destination = $07b3
    &ubyte result = $07e6
    &ubyte dos_code = $07e7
    &bool item_is_directory = $07e8
}
