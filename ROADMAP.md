# 🗺️ DESK COMMANDER — Version 1 Roadmap

> A fast, friendly, DeskMate-inspired organizer and connected desktop for the Commander X16.

## Current snapshot

| Item | Current target |
|---|---|
| Version | 0.3.0 alpha |
| Language | Prog8 12.3.2 |
| Assembler | 64tass 1.60.3243 |
| X16 target | ROM/emulator r49 |
| Display | 320×240, 256-color VERA bitmap |
| Hardware network | TexElec Serial & ESP32 card with ZiModem |
| Last reviewed | September 8, 2026 |

Desk Commander now builds and runs on a physical Commander X16. The TexElec
card can be detected, Wi-Fi networks can be scanned and joined, IP status is
available, and the connection test and public-alpha chat work. The desktop,
organizer applications, file tools, market display, settings, and Comms are
functional alpha software rather than static mockups.

The project is not V1 yet. Its largest remaining responsibilities are safe
power-loss-resistant storage, authenticated/encrypted public communication,
deeper editable organizer records, consistent keyboard operation, and long
real-hardware reliability testing.

### Status marks

- ✅ Complete in the current alpha
- 🟡 Working but incomplete or awaiting broader testing
- ⬜ Not implemented
- 🔬 Must be proven on physical Commander X16 hardware

## V1 product definition

V1 is a cohesive personal desktop, not a full office suite. A new user should
be able to boot into a responsive desktop and safely manage notes, appointments,
contacts, files, calculations, preferences, chat, and a small market watchlist.

The interface is intentionally based on one foreground application beneath a
persistent slim system bar. It uses an icon rail, glance panels, compact
toolbars, dialogs, mouse control, and keyboard navigation. The old decorative
`Desk / File / View` menu is not part of the product.

## What already works

| Area | Status | Current alpha result |
|---|---:|---|
| Build and launch | ✅ | One-command emulator run, SD package, root shortcut, `AUTOBOOT.X16`, and app-directory recovery |
| Splash and desktop | ✅ | Branded splash, icon rail, glance panels, clock, status icons, mouse and arrow-key launching |
| Themes and pointer | ✅ | Three saved themes and three saved pointer styles |
| Sound and clock | ✅ | Saved sound toggle, interface/chat sounds, and working 12/24-hour display |
| Notes | 🟡 | Six saved short notes with add/delete and dirty-region scrolling |
| Calendar | 🟡 | Month navigation and 24 saved editable color-coded events |
| Desk Directory | 🟡 | Searchable/scrollable cards, Add/Delete, and four persistent custom contacts |
| Calculator | ✅ | Mouse and keyboard arithmetic, decimals, backspace, and divide-by-zero handling |
| File Manager | 🟡 | Real device-8 browsing, file/folder creation, rename, move, delete, text open, and PRG launch |
| Text Editor ++ | 🟡 | 2 KB multiline editor, mouse placement, Save, Save As, and dirty-file warning |
| Deep Space Screensaver | ✅ | Full-screen parallax stars and a gently drifting, flicker-free green orb with instant keyboard/mouse exit |
| Network Setup | 🟡 | Real `$9FE0` UART detection, ZiModem, scrollable scan, join, IP status, disconnect, and connection test |
| Comms | 🟡 | Saved user/host, friends, groups, direct/group messaging, polling, history, presence, sounds, and five emoji |
| Browser chat | 🟡 | Public X16-style tester plus protected RODDY manager console |
| Market Watch | 🟡 | Saved 12-symbol list/cache, desktop rotation, keyless assets, and optional Finnhub equities |
| Persistence | 🟡 | Versioned `DCSTATE.BIN` survives normal restart; interrupted-write recovery is unfinished |
| Rendering stability | 🟡 | Dirty regions reduce flashing; banked emoji XOR/palette corruption is fixed; full overlay audit remains |
| Clipboard and printing | ⬜ | Not implemented |

## Priority order to reach V1

1. Protect user data and eliminate bank/memory corruption risks.
2. Secure public identities and messages.
3. Finish the core organizer record workflows.
4. Make mouse and keyboard behavior consistent everywhere.
5. Harden Files, Text Editor ++, networking, Comms, and Market Watch.
6. Complete real-hardware soak tests, documentation, and release packaging.

## P0 — Release blockers

### 1. Data integrity and SD-card recovery

- [x] Define a bounded, signed, versioned `DCSTATE.BIN` format.
- [x] Persist theme, cursor, sound, clock, Notes, Calendar, Desk Directory deletion
      state, network state, Market Watch, and Comms identity/host.
- [ ] Save to a temporary file before replacing the known-good state file.
- [ ] Keep one recoverable backup of important organizer data.
- [ ] Verify the completed temporary file before promoting it.
- [ ] Refuse unknown/newer state versions without modifying them.
- [ ] Handle missing, corrupt, removed, full, and write-protected media clearly.
- [ ] Add an in-app backup/restore workflow or document a safe manual procedure.
- [ ] 🔬 Interrupt saves and power-cycle hardware repeatedly; always recover the
      last known-good state.
- [ ] Remove personal/demo records from production first boot.
- [ ] Add an explicit optional **Load Demo Data** action.

### 2. Banked-memory and rendering safety

- [x] Keep the main PRG below the X16 I/O window and move large apps into banks.
- [x] Restore the starting directory so loadable app files do not become
      `MISSING` after File Manager navigation.
- [x] Fix Comms emoji palette corruption caused by uninitialized bank-17
      `gfx_lores.eor_mode`; every emoji entry point now selects replacement mode.
- [ ] Audit every loadable library for BSS/global values that the main startup
      cannot initialize.
- [ ] Explicitly initialize required graphics, input, parser, and state flags at
      every banked app entry point.
- [ ] Add guard values around shared golden-RAM and VERA buffers where practical.
- [ ] Exercise every app in changing orders and confirm no app disappears,
      inherits stale state, corrupts colors, or crashes.
- [ ] 🔬 Run multi-hour mouse, scroll, file, network, and Comms sessions on real
      hardware while watching for memory and bank corruption.

### 3. Public chat authentication and security

- [x] Deploy the public Ubuntu service under an unprivileged system user.
- [x] Use key-only SSH, firewall defaults, systemd, Caddy, and HTTPS for the web console.
- [x] Keep the X16 host editable for official, community, and private servers.
- [x] Document the bounded RetroWire protocol direction.
- [ ] Add real account creation, sign-in, recovery, and per-user credentials.
- [ ] Prevent username impersonation on every read and write endpoint.
- [ ] Enforce friendship, ownership, membership, and manager authorization server-side.
- [ ] Move state-changing operations and message bodies out of GET query strings.
- [ ] Implement device provisioning and challenge-response authentication.
- [ ] Implement ChaCha20-Poly1305 sessions, replay protection, key rotation, and revocation.
- [ ] Add request/body limits, rate limits, safe logs, moderation tools, and abuse controls.
- [ ] Add database backup, restore, migration, and malformed-record recovery tests.
- [ ] Remove wildcard CORS and expose only reviewed production endpoints.
- [ ] Keep the current plaintext port-8088 bridge clearly labeled test-only until replaced.
- [ ] Never store credentials, Wi-Fi passwords, or session secrets in unprotected logs.

## P1 — Core desktop completion

### 4. Shared input and interface

- [ ] Create one reusable focus model for buttons, lists, fields, dates, and dialogs.
- [ ] Support `Tab`, `Shift+Tab`, arrows, `Enter`, and `Esc` consistently.
- [ ] Draw visible keyboard focus on every interactive control.
- [ ] Create reusable fields with insertion, deletion, cursor movement, masking,
      horizontal scrolling, case preservation, and length limits.
- [ ] Standardize confirmation, warning, error, busy, and unsaved-change dialogs.
- [ ] Give pressed, busy, selected, and disabled controls clear visual states.
- [x] Add wheel/arrow scrolling and dirty-region redraws to major lists.
- [ ] Add missing scrollbars and wheel support wherever content can exceed a view.
- [ ] Audit every hit box after all themes and pointer styles.
- [ ] Remove remaining harsh full-screen redraws from routine interactions.
- [ ] 🔬 Measure pointer feel, click feedback, sound volume, and redraw latency.

### 5. Desktop shell and Settings

- [ ] Replace glance-note stand-ins with the user's actual Notes data.
- [x] Show cached Market Watch results and a small refresh control.
- [ ] Add loading time, last-update time, rate-limit, offline, and stale states.
- [x] Persist and apply theme, pointer, sound, clock, and Comms host/user settings.
- [ ] Make every desktop launcher and glance panel keyboard reachable.
- [ ] Add uniform return-to-desktop and unsaved-work handling.
- [ ] Add a confirmed **Restore Defaults** action.
- [ ] Decide whether a separate Storage settings page adds useful V1 behavior.
- [ ] Decide whether the system bar needs date/reminder indicators.
- [x] Shrink Market Watch and add a large illustrated Screensaver launcher
      while keeping the core safely below its reserved network workspace.
- [ ] Decide whether an optional idle timer should start the Screensaver;
      manual launch is complete.

### 6. Notes

- [x] Provide six saved slots with Add, Delete, scrolling, and a scrollbar.
- [ ] Add titles and longer multiline note bodies.
- [ ] Add New, Open, Save, Save As, Rename, and confirmed Delete.
- [ ] Track dirty notes and warn before discarding changes.
- [ ] Add word wrap, Find, and at least one level of Undo.
- [ ] Add plain-text import/export with documented character conversion.
- [ ] Decide whether Quick Notes and full Notes share one record model.

### 7. Calendar, appointments, and tasks

- [x] Navigate months with visible previous/next controls.
- [x] Add, view, edit, color-code, delete, save, and reload titled events.
- [x] Reflect saved appointments in the desktop glance calendar.
- [x] Restrict event-title editing to its dirty region.
- [ ] Read Today from the RTC instead of fixed alpha defaults.
- [ ] Store more than one event on the same date.
- [ ] Add start/end time, location, linked contact, and longer description.
- [ ] Add a day-agenda view for all events on the selected date.
- [ ] Add task completion and reopening.
- [ ] Add daily, weekly, monthly, and yearly recurrence.
- [ ] Add visible and optional audible reminder dialogs.
- [ ] Poll reminders safely while any application is open.
- [ ] Test leap years, month/year boundaries, recurrence, and midnight rollover.

### 8. Desk Directory and contacts

- [x] Start blank; search, scroll, inspect, and delete saved contacts.
- [x] Add and immediately save four complete user-created contact cards.
- [x] Store name, role/organization, phone, email, and social handle.
- [ ] Add Edit, Duplicate, and confirmed Delete workflows.
- [ ] Expand user-created capacity and add address and notes.
- [ ] Sort alphabetically and preserve selection while filtering.
- [ ] Search every visible field.
- [ ] Add documented CSV or delimited-text import/export.
- [ ] Allow Calendar to attach a contact where useful.

### 9. File Manager and Text Editor ++

- [x] Enumerate real device-8 directories with file/folder icons and scrolling.
- [x] Create files with user-selected extensions and create folders.
- [x] Open, rename, move, and confirm deletion.
- [x] Recognize `.PRG` and `.X16` entries and launch them through a protected
      Golden-RAM loader that cannot be overwritten by the incoming program.
- [x] Open ordinary files in Text Editor ++ and return cleanly to Files.
- [x] Support multiline editing, mouse placement, Save, Save As, and dirty warnings.
- [ ] Add Copy.
- [ ] Add destination browsing instead of typed Move paths.
- [ ] Add sorting, filtering, file-type details, and default-app rules.
- [ ] Add Find, clipboard actions, and Undo to Text Editor ++.
- [ ] Support larger documents with bounded paging or streaming.
- [ ] Use temporary replacement and backup for edited files.
- [ ] Explain DOS and media failures in plain language.

### 10. Calculator and shared accessories

- [x] Implement basic arithmetic, decimals, keyboard entry, and mouse entry.
- [ ] Add `MC`, `MR`, `M+`, and `M-`.
- [ ] Define rounding, overflow, negative-number, and display-length behavior.
- [ ] Decide whether calculator state should persist when closed.
- [ ] Add a bounded clipboard shared by Notes, Calendar, Desk Directory, and the editor.
- [ ] Define PETSCII/ASCII conversion and truncation behavior.
- [ ] Consider basic printer support only after core V1 stability.

## P2 — Connected applications and polish

### 11. TexElec/ZiModem networking

- [x] Probe the default network UART at IO7-low `$9FE0` without hanging if absent.
- [x] Initialize 115200 baud, 8N1, RTS/CTS, and required option-pin behavior.
- [x] Accept verbose `OK`, terse `0`, banners ending in `READY`, and final replies
      without CR/LF.
- [x] Recover from the cold-start banner without requiring a second Detect press.
- [x] Parse up to ten SSIDs into a highlighted scrollable dirty-region list.
- [x] Preserve password case during entry and never save/display the password.
- [x] Join Wi-Fi, report IP status, disconnect, and run a useful pass/fail test.
- [x] Show immediate Detecting/Scanning/Connecting/Checking/Disconnecting feedback.
- [ ] Add selectable recovery baud rates while keeping 115200 as the default.
- [ ] Detect quiet, stream, PETSCII, saved-baud, and malformed-response states.
- [ ] Add bounded ring buffers, cancellation, fuller logs, and overflow handling.
- [ ] Show signal strength, security, gateway, and richer connection details.
- [ ] Allow manual selection of supported alternate card DIP-switch addresses.
- [ ] Expose one nonblocking shared connection service to Comms and Market Watch.
- [ ] 🔬 Verify reconnect after boot, Wi-Fi loss/recovery, repeated scan/join,
      sustained transfers, DNS, HTTPS, chat, and quote traffic.

### 12. Comms

- [x] Save username/host locally and friends/groups/history on the selected server.
- [x] Add persistent offline friends, group creation, member addition, removal,
      group leave, and protected WELCOME membership.
- [x] Provide a pop-up scrollable conversation chooser and full-width transcript.
- [x] Send and receive direct and group messages in the same bounded scrollable view.
- [x] Poll on conversation selection, Send, Sync, and approximately every five seconds.
- [x] Assign the local user green and other senders stable non-black colors.
- [x] Play optional click/send/receive sounds.
- [x] Support 96-character composition with word-aware wrapping.
- [x] Draw smile, frown, wink, angry, and extra-happy faces locally and translate
      them to Unicode in web clients.
- [x] Provide the X16-style public tester and RODDY master console.
- [x] Bound ordinary alpha accounts to 8 friends, 4 groups, 32 group members,
      and 100 retained messages per conversation.
- [ ] Add authenticated connect, reconnect, disconnect, and logout flows.
- [ ] Add unread counts, background presence heartbeat, and message timestamps.
- [ ] Add friend/group editing and ordering.
- [ ] Prevent slow network calls from blocking mouse, clock, reminders, and redraws.
- [ ] Migrate validated alpha records into the production database safely.
- [ ] Support a saved hostname/HTTPS origin after the secure X16 transport is ready.
- [ ] Replace the temporary `sslip.io` address with a branded domain.

### 13. Market Watch

- [x] Save up to 12 symbols and default alpha testing to GOOG, MSFT, and TSLA.
- [x] Add/remove symbols, scroll the list, and rotate desktop groups of three.
- [x] Fetch and parse symbol, whole price, and movement.
- [x] Preserve the last successful numeric baseline across power cycles.
- [x] Support keyless XAU, XAG, and BTC plus a user-supplied Finnhub key.
- [x] Add manual refresh and a compact desktop refresh button with busy feedback.
- [ ] 🔬 Verify keyless and Finnhub HTTPS responses on the physical TexElec card.
- [ ] Add timestamps and an optional conservative automatic refresh interval.
- [ ] Handle invalid symbols, malformed replies, unavailable values, rate limits,
      long numbers, and stale caches clearly.
- [ ] Keep the glance panel balanced with fewer than three configured symbols.
- [x] Label market information as potentially delayed and not trading guidance.

### 14. Documentation, packaging, and release

- [x] Provide emulator, build, SD deployment, BASIC launch, and app-launcher instructions.
- [x] Produce a complete SD-ready directory with `make sdcard` and verified `deskbuild` deployment.
- [ ] Document every keyboard shortcut and mouse action in one compact manual.
- [ ] Document data files, backups, recovery, migration, and clean uninstall.
- [ ] Document TexElec switches, antenna, Wi-Fi setup, firmware recovery, and troubleshooting.
- [ ] Add complete licenses and attribution for code, fonts, art, services, and firmware links.
- [ ] Add automated smoke tests where practical and a manual regression checklist.
- [ ] Record final supported ROM, VERA, and SMC versions after hardware testing.
- [ ] Test clean first boot, upgrades, missing state, corrupt state, and optional demo data.
- [ ] Publish known limitations and reproducible signed/versioned archives.

## Milestones

### M0 — Foundation ✅

Prog8 toolchain, graphics mode, splash, desktop, palette, mouse, clock, build,
emulator, and physical SD launch are established.

### M1 — Functional alpha ✅

Every major V1 application exists and performs a useful workflow. Physical
TexElec Wi-Fi and two-way public-alpha chat are demonstrated.

### M2 — Safe persistent organizer

Complete atomic writes, backups, recovery, blank first boot, and editable
Notes/Calendar/Contacts. Exit when interrupted-save tests retain a known-good copy.

### M3 — Interaction-complete desktop

Finish common focus, fields, dialogs, scrolling, keyboard parity, and remaining
dirty regions. Exit when every required workflow works without a mouse and
ordinary edits do not flash the display.

### M4 — Secure connected services

Finish authenticated accounts, authorization, encrypted RetroWire sessions,
nonblocking shared networking, and hardened server storage.

### M5 — Feature-complete V1 beta

Finish file/editor safety, organizer depth, reminders, Comms polish, and Market
Watch error states. Freeze visible behavior and data formats.

### M6 — Hardware release candidate

Run full regression and long soak tests on physical X16 hardware, repair every
crash/data-loss/network/bank defect, finish documentation, and package the release.

## V1 acceptance journey

A first-time user must be able to:

1. Install Desk Commander and reach a blank, responsive desktop.
2. Configure theme, pointer, sound, and clock and retain those choices.
3. Create, edit, save, find, and delete a note, contact, appointment, and task.
4. Restart and recover every record intact.
5. Recover the last known-good data after an interrupted save.
6. Receive and dismiss a visible and optional audible reminder.
7. Complete every required workflow by keyboard and normal workflows by mouse.
8. Create, open, edit, copy, move, rename, and delete files safely.
9. Launch an external PRG and later relaunch Desk Commander normally.
10. Detect the TexElec card, join Wi-Fi, reconnect, and understand its status.
11. Authenticate and exchange a private and group message securely.
12. Refresh Market Watch without freezing the clock, pointer, or interface.
13. Open and close applications repeatedly without missing banks, corrupted
    colors, stale state, or memory failure.
14. Return cleanly to the desktop and then to BASIC.

## Release gates

V1 does not ship until:

- No known defect can silently corrupt or discard user data.
- Interrupted state and document saves recover a known-good copy.
- Production first boot contains no personal or demo records by default.
- Public users cannot impersonate another username or modify unauthorized data.
- Private messages and credentials are protected by the reviewed production transport.
- No visible V1 control is an unexplained placeholder.
- Every dialog has an obvious mouse and keyboard exit.
- Keyboard focus is visible and complete across required workflows.
- Mouse hit targets, cursor rendering, emoji colors, and scrolling are reliable on hardware.
- Calendar date math and reminders pass boundary tests.
- Missing storage, absent network hardware, lost Wi-Fi, and server failure fail safely.
- Network activity cannot block the clock, pointer, reminders, or UI indefinitely.
- Long sessions do not exhaust memory or corrupt banked/global state.
- A clean SD-card installation passes the full acceptance journey.
- Installation, controls, data, backup, recovery, network setup, security, and
  limitations are documented.

## Locked technical decisions

- Language: **Prog8 12.3.2**
- Assembler: **64tass 1.60.3243**
- Current ROM target: **Commander X16 r49**
- Graphics: **320×240, 256-color VERA bitmap**
- Persistent local state: **2 KB versioned `DCSTATE.BIN` image**
- Network card: **TexElec Commander X16 Serial & ESP32 Network Card**
- Network interface: **ZiModem AT commands over `$9FE0`, 115200 baud, RTS/CTS**
- Window model: **one foreground app below the persistent system bar**
- Desktop model: **icon rail and glance panels; no decorative menu strip**
- Runtime model: **8.3-safe main PRG plus loadable banks 4–18**
- Current text buffer: **2 KB in VERA RAM**
- Chat room model: **friends for direct messages and groups for shared chat**
- Host policy: **official host is suggested, but compatible private/community hosts remain allowed**

## Deferred beyond V1

- Email client
- Paint/drawing and music composition
- Spreadsheet and desktop publishing suites
- Preemptive multitasking or overlapping live applications
- External-program task switching
- Third-party app SDK
- Advanced encrypted local credential vault
- Additional network-card drivers
- Spectrum Next and Commodore 64 Ultimate clients; the backend remains modular so
  these can follow after the X16 protocol is stable

V1 succeeds when Desk Commander is a pleasant place to begin an X16 session, a
trustworthy home for everyday information, and a reliable, secure bridge from
real retro hardware to useful connected services.
