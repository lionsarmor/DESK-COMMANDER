%import gfx_lores
%import input
%import theme

; -----------------------------------------------------------------------------
; COMMS chat mockup
; -----------------------------------------------------------------------------
;
; V1 networking is still future work, but this screen establishes a useful
; layout now: people the user has added live under Direct, while Discord-like
; group spaces live under Servers. The sample names are demo data only.

comms_app {
    const ubyte CHAT_COUNT = 5
    ubyte selected_chat

    sub draw() {
        ; COMMS owns every pixel beneath the persistent DESK COMMANDER bar.
        gfx_lores.fillrect(0, 18, 320, 222, theme.PAPER)
        gfx_lores.fillrect(0, 18, 320, 19, theme.BLUE)
        gfx_lores.text(8, 24, theme.PAPER, iso:"COMMS")
        gfx_lores.fillrect(299, 21, 15, 13, theme.RED)
        gfx_lores.text(303, 24, theme.PAPER, iso:"X")

        draw_sidebar()
        draw_conversation()
    }

    sub draw_sidebar() {
        ; Navy sidebar: direct contacts above group-chat servers.
        gfx_lores.fillrect(0, 37, 104, 203, theme.NAVY)
        gfx_lores.text(18, 48, theme.SOFT_BLUE, iso:"DIRECT")
        draw_chat_row(0, 60, iso:"RILEY")
        draw_chat_row(1, 78, iso:"SAM")
        draw_chat_row(2, 96, iso:"MIKA")

        gfx_lores.text(18, 119, theme.SOFT_BLUE, iso:"SERVERS")
        draw_chat_row(3, 131, iso:"X16 CLUB")
        draw_chat_row(4, 149, iso:"RETRO LAB")
    }

    sub draw_chat_row(ubyte chat, ubyte y, str name) {
        ubyte face = theme.NAVY
        if chat == selected_chat
            face = theme.BLUE
        gfx_lores.fillrect(10, y, 91, 16, face)

        ; A dot for a person and a small grid for a server keep the two kinds
        ; of conversations recognizable without adding more text.
        if chat < 3 {
            ubyte status_color = 5       ; bright online green
            if chat == 1
                status_color = 7         ; bright away yellow
            else if chat == 2
                status_color = 2         ; bright offline red
            gfx_lores.disc(18, y + 8, 3, status_color)
        }
        else {
            gfx_lores.rect(15, y + 5, 7, 7, 7)
        }
        gfx_lores.text(26, y + 5, theme.PAPER, name)
    }

    sub draw_conversation() {
        gfx_lores.fillrect(104, 37, 216, 203, theme.PAPER)
        gfx_lores.fillrect(104, 37, 216, 25, theme.SOFT_BLUE)
        gfx_lores.text(112, 46, theme.NAVY, conversation_name())

        ; The shared preview keeps this alpha light in memory. Choosing any
        ; person or server still changes the active conversation heading.
        incoming(74, iso:"NEW MESSAGE PREVIEW")
        outgoing(102, iso:"COMMS IS COMING TO X16.")

        ; Message composer is deliberately marked offline: this is a visual
        ; interaction mockup, not a claim that networking already works.
        gfx_lores.fillrect(110, 211, 147, 22, theme.PAPER)
        gfx_lores.rect(110, 211, 147, 22, theme.BLUE)
        gfx_lores.text(117, 218, theme.SOFT_BLUE, iso:"OFFLINE - TYPE...")
        gfx_lores.fillrect(263, 211, 49, 22, theme.BLUE)
        gfx_lores.text(271, 218, theme.PAPER, iso:"SEND")
    }

    sub conversation_name() -> str {
        when selected_chat {
            0 -> return iso:"RILEY - ONLINE"
            1 -> return iso:"SAM - AWAY"
            2 -> return iso:"MIKA - OFFLINE"
            3 -> return iso:"# X16 CLUB"
            4 -> return iso:"# RETRO LAB"
        }
        return iso:"COMMS"
    }

    sub incoming(ubyte y, str message) {
        gfx_lores.fillrect(110, y - 3, 190, 14, theme.SOFT_BLUE)
        gfx_lores.text(115, y, theme.INK, message)
    }

    sub outgoing(ubyte y, str message) {
        gfx_lores.fillrect(126, y - 3, 174, 14, theme.BLUE)
        gfx_lores.text(132, y, theme.PAPER, message)
    }

    sub chat_at_pointer() -> byte {
        if input.inside(14, 60, 85, 16)
            return 0
        if input.inside(14, 78, 85, 16)
            return 1
        if input.inside(14, 96, 85, 16)
            return 2
        if input.inside(14, 131, 85, 16)
            return 3
        if input.inside(14, 149, 85, 16)
            return 4
        return -1
    }

    sub open() {
        bool close_window = false
        draw()

        do {
            sys.waitvsync()
            input.poll()

            if input.left_pressed() {
                byte clicked_chat = chat_at_pointer()
                if clicked_chat >= 0 {
                    selected_chat = clicked_chat as ubyte
                    draw_sidebar()
                    draw_conversation()
                } else if input.inside(299, 21, 15, 13)
                    close_window = true
            }

            ; Up and down work here just as they do on the desktop.
            if input.key == $11 or input.key == $1d {
                selected_chat++
                if selected_chat == CHAT_COUNT
                    selected_chat = 0
                draw_sidebar()
                draw_conversation()
            } else if input.key == $91 or input.key == $9d {
                if selected_chat == 0
                    selected_chat = CHAT_COUNT - 1
                else
                    selected_chat--
                draw_sidebar()
                draw_conversation()
            }
        } until close_window or input.key == $1b

        input.key = 0
    }
}
