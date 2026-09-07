# DESK COMMANDER — Version 1 Roadmap

> A fast, friendly, DeskMate-inspired organizer and connected desktop for the Commander X16.

## Current status

**Version:** 0.3.0 alpha

**Toolchain:** Prog8 12.3.2, 64tass 1.60.3243, X16 ROM/emulator r49

**Display:** 320×240, 256-color VERA bitmap

**Launch:** `./run.sh`

**Last reviewed:** September 6, 2026

The visual shell and several interaction prototypes work, and a versioned
device-8 state image now survives normal restarts. DESK COMMANDER has now
booted and run successfully on a physical Commander X16. General text-file
opening/editing works, the physical TexElec UART is detected at `$9FE0`, and a
real ZiModem `OK` response and ESP32 Firmware v4.0.2 banner have now been
received. A bad secondary-identification gate kept Scan/Join disabled despite
that proof, while a cold modem required a second manual Detect. The current
build removes that gate and performs the settled retry automatically.
Completing Scan/Join/Status testing remains the immediate P0 priority; connected apps,
reminders, printing, and release packaging remain unfinished. Alpha builds
intentionally contain sample records; V1 must start blank unless the user
explicitly enables demo data.

Status marks used below:

- ✅ Working in the current alpha
- 🟡 Partially implemented or represented by a functional prototype
- ⬜ Not implemented
- 🔬 Must be verified on real Commander X16 hardware

## V1 product definition

V1 is a cohesive personal desktop, not a full office suite. It should boot
quickly and provide useful Notes, Calendar, Contacts, Files, Calculator,
Settings, Comms, and Market Watch experiences through one consistent visual
language.

The desktop deliberately does **not** restore the decorative `Desk / File /
View` menu strip. The slim top identity bar, icon rail, app windows, contextual
buttons, and Settings page are the intended interface.

### Release priorities

1. Fix ZiModem communication on the detected physical TexElec card.
2. Protect the user's data and survive interrupted SD-card writes.
3. Make mouse and keyboard operation equally dependable.
4. Finish the organizer applications before expanding their scope.
5. Share the stable network service between Comms and Market Watch.
6. Remain responsive and readable during long real-hardware sessions.

## What works today

| Area | Status | Current alpha behavior |
|---|---:|---|
| Build and launch | ✅ | Pinned toolchain plus confirmed SD-card launch on a physical Commander X16 |
| Splash and branding | ✅ | Native VERA splash, version, creator, keyboard/mouse dismissal |
| Desktop | ✅ | Icon rail, Notes/Calendar glance cards, rotating Market Watch cache, RTC clock, sound/Wi-Fi indicators |
| Mouse | ✅ | Hardware pointer, click edges, hit testing, three themed pointer styles |
| Keyboard | 🟡 | Desktop arrow selection and app-specific keys work; universal focus does not |
| Rendering | 🟡 | Desktop and apps render on physical hardware; long-session and edge-case testing remains |
| Notes | 🟡 | Six short saved notes with Add, Delete, wheel/arrow scrolling, and scrollbar |
| Calendar | 🟡 | Month navigation and 24 editable, color-coded saved events with a title-field dirty region |
| Rolodex | 🟡 | Search, dirty-region scrolling, contact details, and persistent deletion state over demo contacts |
| Calculator | ✅ | Mouse and keyboard arithmetic, decimals, backspace, and divide-by-zero handling |
| File Manager | 🟡 | Device-8 listing, file/folder icons, paging, file operations, stable directory restoration, text editing, and external PRG launch |
| Text Editor ++ | 🟡 | 2 KB multiline editor with pointer placement, Save, Save As, dirty state, and clean return to Files |
| Settings | 🟡 | Theme, pointer, sound, and clock persist; Network and About open |
| Comms | 🟡 | Multi-bank public-alpha chat plus manager console; inline composition, automatic receive polling, rolling 100-message history, ASCII-safe parsing, saved identity/host, persistent contacts, presence colors, diagnostics, and two-way messages |
| Market Watch | 🟡 | Saved watchlist/quotes, cross-power-cycle public-asset comparison, Finnhub HTTPS, and three-row rotation |
| TexElec network | 🟡 | Physical UART, scan, selectable SSIDs, join, and link status work; the R13 screen adds flicker-free list scrolling and immediate action feedback |
| Persistence | 🟡 | Versioned `DCSTATE.BIN` preserves relevant alpha state after normal shutdown; atomic recovery remains |
| Printing and clipboard | ⬜ | Not implemented |

## Unfinished V1 work

### 0. P0 — Stabilize physical ZiModem communication

The TexElec card now detects, joins Wi-Fi, completes the connection test, and
reaches the LAN chat server on physical hardware. Reliability remains P0.

- [ ] Run the official ROMTERM at `$9FE0`, 115200 baud, 8N1, and RTS/CTS; record
      the exact working configuration and ZiModem firmware reported by `ATI`.
- [x] Compare a working X16 UART implementation with `network_driver.p8` and
      align divisor, FIFO, modem-control, CTS/RTS, and Option Pin A state.
- [x] Force a known ZiModem command state before identification: command mode,
      responses enabled, verbose replies, ASCII translation, and known line endings.
- [x] Accept both verbose `OK` and terse numeric `0` success replies.
- [x] Accept a final `OK` without CR/LF after the UART becomes quiet.
- [ ] Detect and explain quiet mode, unexpected baud, stream mode, PETSCII mode,
      transmit timeout, receive timeout, and malformed responses.
- [x] Show a bounded raw-response diagnostic view instead of replacing every
      failure with `ZIMODEM DID NOT ANSWER`.
- [ ] Add selectable baud rates for recovery, while keeping 115200 the default.
- [ ] Verify `ATI4`, Wi-Fi scan, join, saved configuration, IP status, DNS ping,
      reconnect after restart, and recovery after Wi-Fi loss.
- [ ] Verify ZiModem HTTPS download and one Finnhub quote on the physical card.
- [ ] Run sustained transfers and confirm the mouse, clock, sound, and screen do
      not freeze or corrupt while UART traffic is active.
- [ ] If ROMTERM also fails, check card revision/riser hardware and follow
      TexElec's pre-October-2024 replacement guidance before changing app code.

### 1. Shared input and interface

- [ ] Create one reusable focus model for buttons, lists, fields, dates, and dialogs.
- [ ] Make `Tab`, `Shift+Tab`, arrows, `Enter`, and `Esc` consistent in every app.
- [ ] Add visible keyboard focus to every interactive control.
- [ ] Add reusable text fields with cursor movement, insertion, deletion, masking,
      horizontal scrolling, and maximum-length handling.
- [ ] Add reusable confirmation, warning, error, and unsaved-change dialogs.
- [ ] Give pressed and disabled buttons distinct visual states across every app. Network Setup now gives immediate in-panel progress feedback.
- [ ] Add wheel scrolling where lists exceed the visible area.
- [ ] Decide whether double-click and right-click add enough value for V1.
- [ ] Audit hit boxes at screen edges and after every theme/pointer change.
- [ ] Remove remaining full-screen redraws from routine interactions.
- [ ] 🔬 Check cursor appearance, redraw flicker, sound volume, and input latency on hardware.

### 2. Desktop shell

- [ ] Replace hard-coded glance-note samples with the user's real Notes data.
- [x] Replace demo market values with cached network results.
- [ ] Expand the current offline/error display with loading, timestamps, rate-limit, and richer stale-data states.
- [x] Preserve desktop theme, pointer, sound, and clock preferences after restart.
- [ ] Decide whether restoring the last selected desktop section improves startup.
- [ ] Make every launcher and glance panel keyboard reachable.
- [ ] Add consistent return-to-desktop behavior and unsaved-work checks.
- [x] Show compact sound and last-known Wi-Fi status indicators in the top bar.
- [ ] Decide whether the top bar should also show date and alarm indicators.

### 3. Storage and file safety

- [x] Build a small CMDR-DOS/KERNAL file service for device 8.
- [x] Enumerate real directory entries instead of displaying sample rows.
- [x] Implement paged directory navigation.
- [x] Implement New Folder, Rename, and confirmed file/empty-folder Delete.
- [x] Implement New File with user-selected names and extensions.
- [x] Implement same-volume Move using CMDR-DOS rename-to-path behavior.
- [x] Implement general file Open plus Text Editor ++ Save and Save As.
- [x] Launch CMDR-DOS PRG/AUTOBOOT entries and leave ordinary files in Text Editor++.
- [x] Restore the starting directory when Files closes so app overlays do not become `MISSING`.
- [ ] Implement Copy and optional file-type filtering/default-app rules.
- [ ] Add destination browsing to Move instead of requiring a typed path.
- [ ] Confirm destructive operations and explain failures in plain language.
- [x] Define a versioned bounded state image for preferences, notes, calendar, contacts, network, and market data.
- [ ] Use temporary-file writes before replacing the last known-good file.
- [ ] Keep a recoverable backup for important organizer data.
- [ ] Reject unknown/newer formats without modifying them.
- [ ] Handle missing, removed, full, corrupt, and write-protected media.
- [ ] Provide an explicit Demo Data command; normal first launch must be blank.
- [ ] 🔬 Test repeated saves and power-loss recovery on a real SD card.

### 4. Notes

- [x] Expand the short-note list to six saved records with a four-row scrolling viewport.
- [ ] Add note titles, longer bodies, and multiline body editing.
- [ ] Add New, Open, Save, Save As, Rename, and Delete confirmation.
- [ ] Track dirty notes and warn before discarding edits.
- [ ] Add word wrap, Find, and at least one-level Undo.
- [ ] Add shared Cut, Copy, and Paste.
- [ ] Decide between one full editor plus Quick Notes or a unified note model.
- [ ] Add plain-text import/export and character-conversion rules.

### 5. Calendar, appointments, and tasks

- [x] Limit event-title typing redraws to the input-field dirty region.
- [ ] Read today's month/year/day from the RTC rather than fixed alpha defaults.
- [ ] Support more than one event on the same date.
- [ ] Add optional start time, end time, location, contact, and longer description.
- [ ] Add a day-agenda view for viewing all events on a selected date.
- [ ] Add task completion/reopen state.
- [ ] Add daily, weekly, monthly, and yearly recurrence.
- [ ] Add reminder times and visible/audible alarm dialogs.
- [ ] Poll alarms safely while any application is open.
- [x] Persist and reload events; rebuild the at-a-glance highlights from saved data.
- [ ] Add capacity-full and invalid-date messages.
- [ ] Test leap years, month/year boundaries, recurrence, and midnight rollover.

### 6. Rolodex and contacts

- [ ] Replace compiled demo contacts with editable user records.
- [ ] Add New, Edit, Duplicate, Save, and confirmed Delete.
- [ ] Store name, organization/role, phone, email, social handle, address, and notes.
- [ ] Sort alphabetically and preserve selection while filtering.
- [ ] Make search cover every visible field.
- [ ] Add shared clipboard actions for individual fields and complete addresses.
- [ ] Add documented CSV or delimited-text import/export.
- [ ] Let Calendar choose a contact where useful.
- [ ] Persist contacts and start with an empty Rolodex in production builds.

### 7. Calculator and desk accessories

- [ ] Add calculator memory keys (`MC`, `MR`, `M+`, and `M-`).
- [ ] Define rounding, display-length, overflow, and negative-number behavior.
- [ ] Preserve or intentionally reset calculator state when the overlay closes.
- [ ] Add an alarm-status accessory once Calendar reminders exist.
- [ ] Test all calculator input from both keyboard and mouse.

### 8. Settings and preferences

- [x] Save theme, cursor style, sound, and 12/24-hour selection.
- [x] Apply saved settings before the splash/desktop becomes visible.
- [ ] Add keyboard focus and activation inside Settings and its dialogs.
- [ ] Add a Restore Defaults action with confirmation.
- [ ] Decide whether Storage needs a separate settings page after File Manager works.
- [x] Add the default card address and connection controls described below.
- [x] Keep About and splash version/copyright text synchronized through `appmeta.p8`.

### 9. TexElec X16 Serial & ESP32 networking

Target hardware: [TexElec Commander X16 921.6Kbps Serial & ESP32 Network Card](https://texelec.com/product/commander-x16-serial-network-card/), using its preinstalled [ZiModem firmware](https://github.com/bozimmerman/Zimodem).

- [x] Implement TL16C2550/16450-compatible UART register access.
- [x] Probe the default network UART at IO7-low `$9FE0` without hanging when absent.
- [ ] Allow manual selection of the card's other DIP-switch I/O ranges.
- [x] Initialize the network port at 115200 baud with RTS/CTS flow control.
- [x] Keep ZiModem option pin A high as required for normal command/stream behavior.
- [ ] Build bounded transmit/receive ring buffers and line parsing.
- [ ] Add cancellation, a response log, and stronger overflow/error handling beyond the current bounded timeouts.
- [x] Use `ATI4` to identify ZiModem and read its firmware/version response.
- [ ] Make the identification probe tolerate/reset saved ZiModem modes and
      succeed on the physically detected card.
- [ ] Add parsed signal-strength and security indicators to scanned access points.
- [x] Parse up to ten scan results into one highlighted, scrollable SSID list
      with mouse, arrow-key, and wheel selection; keep a masked,
      case-preserving password field.
- [x] Limit SSID scrolling and selection redraws to the black list-panel dirty
      region, avoiding the harsh full-window flash seen on real hardware.
- [x] Replace overflowing Network button labels with distinct colored action
      icons and show Detecting, Scanning, Connecting, Checking, and
      Disconnecting feedback before bounded modem operations begin.
- [x] Connect with the appropriate `ATW"SSID,PASSWORD"` command.
- [x] Remember the last successful SSID and last-confirmed link indicator without storing the password.
- [ ] Expand the working `ATI2` IP check to show router and richer connection state.
- [x] Test connectivity from Comms with a disposable TCP connection to
      Cloudflare's numeric `1.1.1.1:443` endpoint, then close it with `ATH`.
- [x] Separate missing modem, connection failure, and UART timeout results;
      avoid treating an unreliable ICMP response as Wi-Fi status.
- [ ] Save successful modem configuration with `AT&W` only after confirmation.
- [x] Never save or display the Wi-Fi password in DESK COMMANDER's own plain-text files.
- [ ] Complete clear Card Missing, Modem Not Ready, Wi-Fi Failed, DNS Failed,
      Timed Out, and Offline states.
- [ ] Expose one shared connection API to Comms and Market Watch.
- [x] Preserve/restore X16 RAM-bank state around the loadable Network Setup app.
- [ ] 🔬 Soak-test repeated scan, reconnect, Comms sync/send, and Market Watch
      traffic on the physical card without UI freezes or stale sessions.

### 10. Comms

- [x] Replace compiled demo people/rooms with server-backed entries.
- [x] Save offline friend names without requiring an active account first.
- [ ] Add X16-side friend removal/group leave, editing, and ordering.
- [x] Add friend, group, and group-member creation flows.
- [x] Add a working composer with keyboard editing and Send behavior.
- [x] Define and implement the first bounded LAN HTTP chat protocol/server contract.
- [ ] Implement connect, authentication, reconnect, disconnect, and logout flows.
- [x] Route network traffic through the TexElec/ZiModem HTTP service.
- [x] Persist bounded conversation history atomically on the alpha Python server.
- [x] Save the X16 username and server address in `DCSTATE.BIN`.
- [x] Consolidate duplicate Servers and group chats into one Groups model, with
      automatic migration of existing server data.
- [x] Add scrollable Friend and Group lists with manual Sync/Test feedback.
- [x] Implement online, away, offline, and connection-error colors.
- [ ] Add unread indicators and a background presence heartbeat on the X16.
- [ ] Prevent a slow connection from freezing mouse, clock, alarms, or redraws.
- [ ] Keep credentials out of logs and unprotected organizer files.
- [x] Choose one bounded V1 room model: Groups.
- [x] Add browser-side friend removal and group-leave controls.
- [x] Add browser X16 activity monitoring and compact-protocol preview.

#### Public connectivity and server hardening

- [x] Fix ZiModem LAN downloads to use native `AT&G"HOST:PORT/path"` syntax.
- [x] Keep local server data atomic and persistent in `server/chat-data.json`.
- [x] Provision the public Ubuntu Droplet and a non-root `deskcmd` service user.
- [x] Deploy the modular FastAPI/SQLite backend foundation under systemd.
- [x] Enable key-only SSH and a deny-by-default firewall; keep unfinished app
      ports private during development.
- [x] Draft the bounded RetroWire v1 handshake, limits, and command families.
- [ ] Implement and test device provisioning, challenge-response authentication,
      ChaCha20-Poly1305 sessions, replay protection, and revocation.
- [ ] Open the RetroWire TCP port only after the security acceptance tests pass.
- [ ] Replace the temporary hostname with a permanent branded domain while
      retaining Caddy-managed HTTPS for the maintenance console.
- [x] Deploy the authenticated RODDY master console through Caddy/HTTPS at the
      temporary `sslip.io` hostname.
- [x] Publish the bounded port-8088 X16 compatibility bridge for physical
      end-to-end chat testing, with a visible plaintext-alpha warning.
- [x] Keep the X16 HOST value editable so official, community, and private
      compatible servers remain possible.
- [x] Let the manager enumerate every user/friend/group and initiate a direct
      conversation that automatically appears on the recipient retro client.
- [x] Add a compact manager-console group tester that creates test users, adds
      them to the selected group, and sends messages under each test name.
- [ ] Migrate validated LAN-server chat records into the public database.
- [ ] Accept a saved hostname/HTTPS origin in addition to a 15-character IPv4
      LAN address; do not append port 8088 when an HTTPS origin supplies 443.
- [ ] Add authenticated sessions so a remote caller cannot impersonate any
      username merely by putting it in a URL.
- [ ] Enforce owner/member authorization for friend, group, and delete
      operations on every server endpoint.
- [ ] Move state-changing operations and message text out of GET query strings.
- [ ] Put the public service behind TLS and remove wildcard CORS.
- [ ] Add request-size limits, rate limits, audit-safe logs, backup/restore, and
      malformed-data recovery before exposing the service to the internet.
- [ ] Add authenticated delete/leave flows for friends, groups, and accounts.
- [ ] Choose a stable deployment: a public VPS with a fixed address, or a named
      tunnel/domain. Use a temporary tunnel only for short hardware tests.
- [ ] Test local hotspot, isolated guest Wi-Fi, lost-link, reconnect, server
      restart, and power-cycle behavior on the physical Commander X16.

### 11. Market Watch

- [x] Choose and document Finnhub's compact quote endpoint; users supply keys subject to their own plan limits.
- [x] Add keyless whole-dollar prices for Gold (`XAU`), Silver (`XAG`), and Bitcoin (`BTC`) through Gold API, with numeric movement measured from the previous refresh.
- [ ] 🔬 Confirm ZiModem HTTPS and the Finnhub endpoint on the physical TexElec card.
- [x] Add a saved 12-symbol watchlist with Add and Remove; preserve existing entries and suggest GOOG, MSFT, TSLA, XAU, XAG, and BTC.
- [x] Fetch and parse symbol, last price, and percentage change.
- [x] Cache the latest result in VERA RAM and show explicit offline values on failure.
- [x] Add manual three-quote refresh, a compact desktop refresh control with busy feedback, and cached 30-second page rotation.
- [ ] 🔬 Confirm the XAU/XAG/BTC keyless HTTPS responses on the physical TexElec card.
- [ ] Add quote timestamps and an optional conservative automatic network-refresh interval.
- [ ] Handle malformed replies, unavailable symbols, rate limits, and long values.
- [x] Label potentially delayed data honestly and document that it is not trading guidance.
- [ ] Keep the desktop glance view readable when fewer or more symbols are configured.

### 12. Shared clipboard and printing

- [ ] Implement a bounded text clipboard shared by Notes, Calendar, and Rolodex.
- [ ] Define PETSCII/ASCII conversion and truncation behavior.
- [ ] Add Copy/Paste commands to applicable fields.
- [ ] Select a basic printer output path and supported character set.
- [ ] Add basic Notes printing.
- [ ] Add calendar/contact printing only if the core release is stable.

### 13. Documentation, packaging, and release

- [x] Write installation instructions for emulator and SD-card use.
- [ ] Document every keyboard shortcut and mouse action.
- [ ] Document data locations, formats, backup, recovery, and upgrades.
- [ ] Document TexElec card DIP-switch, antenna, Wi-Fi, and troubleshooting steps.
- [ ] Add licenses and attribution for code, fonts, art, and third-party firmware links.
- [ ] Add automated smoke checks where practical and a manual regression checklist.
- [ ] Test minimum/current supported ROMs and record the final requirement.
- [ ] Test clean first run, upgrade, missing data, demo data, and corrupt data.
- [x] Produce an SD-card-ready runtime folder with `make sdcard`.
- [ ] Produce signed/versioned release archives.
- [ ] Publish known limitations and tag a reproducible V1 source/binary release.

## Milestones

### M0 — Foundation ✅

Prog8 toolchain, VERA mode, splash, desktop, clock, pointer, palette, and one-command
build/run are established.

### M1 — Interaction-complete alpha

Finish common focus, text fields, dialogs, scrolling, keyboard parity, and remaining
dirty-region rendering. Exit when every current alpha screen can be operated without
the mouse and normal edits do not flash the entire display.

### M2 — Safe persistent organizer

Implement file services and versioned formats, then persist Settings, Notes,
Calendar, and Rolodex. Exit when a restart preserves data and interrupted-save tests
retain the last known-good copy.

### M3 — Organizer feature completion

Finish long Notes, multi-event Calendar/day agenda/tasks/reminders, editable Contacts,
shared clipboard, and calculator memory. Exit when the complete offline organizer
journey works on emulator and hardware.

### M4 — TexElec network foundation

Detect and initialize the TexElec card, configure Wi-Fi through ZiModem, and expose a
non-blocking shared connection service. Exit when the app can reconnect after restart,
report its IP/status, and recover cleanly from absent hardware or lost Wi-Fi.
The physical UART-detection half is confirmed; modem command/response is the active
P0 blocker for completing this milestone.

### M5 — Connected applications

Connect Market Watch to its selected feed and Comms to its defined service. Exit when
both share the card safely, show honest offline/stale states, and cannot freeze the UI.

### M6 — Integration and real-hardware hardening

Unify input and errors, exercise alarms during every app, measure memory/performance,
and run long sessions on a real X16. Fix all crash, data-loss, navigation, networking,
and alarm defects.

### M7 — V1 release candidate

Freeze file formats and visible behavior, remove unintended demo data/placeholders,
finish documentation, package releases, publish known limitations, and complete the
acceptance journey below.

## V1 acceptance journey

A first-time user must be able to:

1. Install and reach a blank, responsive desktop.
2. Configure mouse, theme, sound, and clock, then see those choices survive restart.
3. Create and save a note, contact, appointment, and task.
4. Restart and recover every saved record intact.
5. Edit and delete those records with confirmations where destructive.
6. Receive a visible and audible calendar reminder.
7. Navigate every required workflow by keyboard and normal workflows by mouse.
8. Create, open, edit, move, copy, rename, and delete a file safely.
9. Recover the last known-good data after a simulated interrupted save.
10. Detect the TexElec card, configure Wi-Fi, reconnect, and report network status.
11. Refresh Market Watch and send/receive one Comms message without freezing the UI.
12. Return cleanly to the desktop and then to BASIC.

## Release gates

V1 does not ship until:

- The physical TexElec card completes ZiModem detect, Wi-Fi join, IP/DNS, and
  HTTPS tests using the documented default configuration.
- No known defect can silently corrupt or discard user data.
- Production first run contains no personal/demo records by default.
- No visible V1 control is a nonfunctional placeholder.
- Every modal window has an obvious mouse and keyboard exit.
- Keyboard focus is visible and complete across required workflows.
- Mouse hit targets and cursor rendering are reliable on real hardware.
- Calendar date math and reminders pass boundary tests.
- Missing storage, missing network hardware, and lost Wi-Fi fail safely.
- Network activity never blocks clock, pointer, alarms, or screen updates indefinitely.
- Long-session testing does not exhaust memory or corrupt banked state.
- The release works from a clean SD-card installation.
- Installation, controls, backup, recovery, network setup, and limitations are documented.

## Locked technical decisions

- Language: **Prog8 12.3.2**
- Assembler: **64tass 1.60.3243**
- Alpha ROM target: **Commander X16 r49**
- Graphics: **320×240, 256-color VERA bitmap**
- Program load area: conventional RAM below the X16 I/O window
- Persistent application state: **2 KB versioned image in VERA bank 1**, saved as `DCSTATE.BIN`
- Network card: **TexElec Commander X16 Serial & ESP32 Network Card**
- Network firmware/API: **ZiModem AT commands over the card's network UART**
- Default network UART: **IO7-low `$9FE0`, 115200 baud, RTS/CTS**
- Window model: one foreground app/overlay beneath the persistent top bar
- Loadable apps: Files in bank 4, file operations in bank 5, editor in bank 6,
  Network Setup in bank 7, its SSID picker in bank 13, Market Watch in bank 8,
  quote fetching in bank 9,
  persistence in bank 10, Notes in bank 11, Comms interaction in bank 12, the
  external PRG handoff in bank 14, chat HTTP in bank 15, and chat rendering in
  bank 16
- Text buffer: 2 KB in VERA RAM for the current alpha
- Desktop navigation: icon rail and glance panels; no decorative menu strip

## Deferred beyond V1

- Paint/Draw and music composition
- Rich desktop publishing and spell checking
- Full spreadsheet compatibility
- Email client
- Multiple overlapping live applications or preemptive multitasking
- External-program task switching
- Third-party application SDK
- Advanced encrypted credential vault
- Multiple network-card drivers beyond the TexElec/ZiModem target

V1 succeeds when DESK COMMANDER is a pleasant place to begin an X16 session,
a trustworthy home for everyday information, and a reliable bridge from the
TexElec network card to its first connected applications.
