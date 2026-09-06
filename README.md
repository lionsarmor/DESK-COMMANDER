# 🖥️ DESK COMMANDER

> A friendly, DeskMate-inspired personal desktop for the Commander X16.

![DESK COMMANDER splash screen](docs/images/splash.png)

DESK COMMANDER is an original retro organizer written in readable
[Prog8](https://prog8.readthedocs.io/) for the Commander X16. It combines
Notes, Calendar, Rolodex, Files, Calculator, Settings, Comms, and Market Watch
inside a crisp mouse-and-keyboard desktop.

> [!IMPORTANT]
> This is **version 0.3.0 alpha**. Several screens are working prototypes and
> persistence still needs power-loss hardening. The application now boots and
> runs on a physical Commander X16, but completing the ZiModem connection is
> the top-priority defect. See the [V1 roadmap](ROADMAP.md) for the complete,
> honest list of unfinished work.

## ✨ Current highlights

- 🖱️ Hardware mouse support with small blue, large red, and normal black pointers
- ⌨️ Arrow-key desktop selection with `Enter` to launch
- 🕐 Live RTC clock with working 12/24-hour formats
- 📝 Six saved Notes with Add, Delete, wheel/arrow scrolling, and a scrollbar
- 📅 Month navigation and 24 saved, editable, color-coded Calendar events
- 📇 Searchable, scrollable Rolodex with phone, email, and social fields
- 🧮 Functional mouse-and-keyboard Calculator
- 📁 Real device-8 File Manager with distinct file/folder icons, New File,
  New Folder, Open, Rename, Move, paging, and confirmed Delete
- ✍️ Text Editor ++ with multiline editing, mouse placement, Save, Save As,
  dirty-file warnings, and a clean return to the File Manager
- 🎨 X16, Amber, and Night theme packages
- 🔊 Subtle optional interface sounds
- 💬 Full-screen Comms prototype with direct chats, servers, and presence colors
- 📈 Saved twelve-symbol Market Watch, defaulting to GOOG, MSFT, and TSLA
- 📡 Physical TexElec UART detection at `$9FE0`; ZiModem communication is the
  current top-priority hardware issue
- ⚡ Dirty-region redraws that reduce flashing while lists and documents scroll

## 🖼️ Screenshots

| Desktop | TexElec network setup |
|---|---|
| ![DESK COMMANDER desktop](docs/images/desktop.png) | ![TexElec X16 network settings](docs/images/network-settings.png) |

The Network screen is designed for the
[TexElec Commander X16 921.6Kbps Serial & ESP32 Network Card](https://texelec.com/product/commander-x16-serial-network-card/).
It reflects the card's preinstalled
[ZiModem](https://github.com/bozimmerman/Zimodem) interface, default IO7-low
network UART at `$9FE0`, 115200 baud, and RTS/CTS flow control. On physical
hardware, DESK COMMANDER successfully detects the card's UART at `$9FE0`, but
the current `ATI4` probe does not yet receive/recognize ZiModem's response.
Wi-Fi scanning, joining, status, Market Watch updates, and Comms networking
therefore remain blocked until that transport issue is fixed and retested.

## 🚧 Road to 100%

The complete task breakdown lives in the [V1 roadmap](ROADMAP.md). Work should
proceed in this order:

- [ ] **P0 — Fix physical ZiModem communication.** Compare against ROMTERM,
  normalize baud/flow-control/command mode, accept verbose and numeric replies,
  expose raw diagnostics, then verify detect, scan, join, IP, DNS, and HTTPS.
- [ ] **P1 — Make persistence power-loss safe.** Use temporary and backup state
  files, handle full/removed/write-protected media, and prove recovery on SD.
- [ ] **P1 — Finish the organizer.** Add long Notes, editable Contacts,
  multi-event Calendar days, tasks, recurrence, reminders, and RTC-based Today.
- [ ] **P1 — Finish keyboard and field behavior.** Add universal focus,
  consistent navigation, reusable text editing, and polished error dialogs.
- [ ] **P2 — Finish Files and Text Editor ++.** Add Copy, destination browsing,
  Find, clipboard, Undo, larger documents, and safer replacement writes.
- [ ] **P2 — Complete connected apps.** Harden Finnhub refreshes and replace the
  Comms mockup with one documented, working messaging service.
- [ ] **P2 — Release hardening.** Remove default demo records, complete licenses
  and manuals, run long hardware tests, and publish a reproducible V1 archive.

## 🚀 Run it

From the project directory:

```bash
./run.sh
```

The first run downloads the pinned development tools into `.tools/`; it does
not install anything system-wide. Later runs rebuild changed source files and
launch the emulator directly.

On the splash screen, press any key or click. On the desktop, click an app or
use the arrow keys and press `Enter`. Press `Esc` to close the current app or
return to BASIC.

### Build without launching

```bash
# Check the Prog8 source.
make check

# Compile build/main.prg and all nine loadable components.
make

# Remove generated build files.
make clean
```

### Put it on a real Commander X16

Build a clean runtime folder:

```bash
make sdcard
```

Copy every file inside `dist/sdcard/` to one directory on a FAT32 SD card.
Do not copy a development `DCSTATE.BIN` unless you deliberately want that
profile. At the X16 BASIC prompt, enter:

```basic
LOAD "DESKCMD.PRG",8,1
RUN
```

The device number is 8 and the secondary address `1` honors the PRG's encoded
load address, matching the official [CMDR-DOS LOAD documentation](https://github.com/X16Community/x16-docs/blob/master/X16%20Reference%20-%2013%20-%20Working%20with%20CMDR-DOS.md#load).
DESK COMMANDER currently targets ROM r49. The official
[ROM r49 release notes](https://github.com/X16Community/x16-rom/releases/tag/r49)
recommend VERA 48.0.1 and SMC 48.0.0 or 47.2.3 for hardware.

For networking, use the revised TexElec card at its default IO7-low address.
The manufacturer's documentation confirms `$9FE0-$9FEF`, 115200 baud,
RTS/CTS, ZiModem, and Option Pin A high. Owners of cards purchased before
October 2024 should read TexElec's replacement notice on the
[official product page](https://texelec.com/product/commander-x16-serial-network-card/).

## 🧭 App guide

| App | What works now | Still to come |
|---|---|---|
| Notes | Six saved slots; select, type, add, delete, wheel/arrow scroll | Long-form bodies, files, clipboard, undo |
| Calendar | Browse months; add/edit/delete saved typed events | Multiple daily events, agenda, recurrence, reminders |
| Rolodex | Search, flicker-reduced scroll, inspect, and persist deletions | Create/edit contacts, sorting, import/export |
| Calculator | Basic arithmetic, decimals, keyboard input | Memory keys and final edge-case testing |
| Files | Browse device 8; create files with any extension and folders; open text; rename, move, and confirmed delete | Copy, sorting/filtering, richer errors |
| Text Editor ++ | Open files, multiline edit, mouse cursor placement, Save, Save As, unsaved-work warning | Find, clipboard, undo, larger documents, safer replacement writes |
| Settings | Saved theme, mouse, sound, clock; Network diagnostics; About | Fix physical ZiModem response and add richer storage tools |
| Comms | Direct/server layout and selection | Accounts, transport, messages, history, real presence |
| Market Watch | Add/delete 12 saved symbols, quote/cache UI, and rotate groups every 30 seconds | Restore physical ZiModem transport, then validate Finnhub and add richer stale/rate-limit states |

## 🧰 Project layout

```text
src/main.p8          Program entry point
src/appmeta.p8       Version, creator, and copyright strings
src/preferences.p8   Saved sound and clock preferences plus click audio
src/theme.p8         Shared palette and theme packages
src/input.p8         Keyboard, mouse, cursor, and click-sound handling
src/font5x7.p8       Scalable splash-title font
src/splash.p8        Splash screen drawing and dismissal
src/desktop.p8       Desktop, Calculator, Settings, and overlay launchers
src/app_mailbox.p8   Shared low-memory handoff between loadable apps
src/file_manager.p8  Real CMDR-DOS browser, icons, paging, and navigation
src/file_manager_overlay.p8  Loadable high-RAM app entry point
src/file_ops.p8      New File/Folder, Rename, Move, and Delete dialogs
src/file_ops_overlay.p8      Loadable file-operation entry point
src/text_editor.p8   Text Editor ++ load, edit, save, and close behavior
src/text_editor_overlay.p8   Loadable editor entry point
src/network_driver.p8        TexElec UART and ZiModem command transport
src/network_app.p8           Detect, scan, join, and status interface
src/network_overlay.p8       Loadable Network Setup entry point
src/market_data.p8           Shared VERA watchlist and quote cache
src/market_app.p8            Scrollable watchlist and API-key interface
src/market_overlay.p8        Loadable Market Watch interface
src/market_fetch.p8          ZiModem HTTPS and Finnhub JSON worker
src/market_fetch_overlay.p8  Loadable quote-fetch service
src/state_data.p8    Versioned shared persistent-state map
src/state_store.p8   Device-8 load/save service
src/state_overlay.p8 Loadable persistence service in bank 10
src/notes_app.p8     Saved, scrollable Notes application
src/notes_overlay.p8 Loadable Notes entry point in bank 11
src/comms_overlay.p8 Loadable Comms entry point in bank 12
src/calendar_app.p8  Month view and event editor
src/rolodex_app.p8   Searchable contact-card application
src/comms_app.p8     Direct-message and server-chat prototype
docs/images/         GitHub screenshots
```

Generated files live in `build/`. `ZZFILEMAN.BIN`, `ZZFILEOPS.BIN`,
`ZZEDITOR.BIN`, `ZZNETWORK.BIN`, `ZZMARKET.BIN`, `ZZMARKETNET.BIN`,
`ZZSTATE.BIN`, `ZZNOTES.BIN`, and `ZZCOMMS.BIN` are also emitted beside the
launcher so HostFS and an SD-card copy can load them. Keep all nine beside
`main.prg`.
Downloaded tools live in `.tools/`. Generated artifacts are excluded from
source control.

Ordinary core variables live in the X16's non-banked golden RAM. The File
Manager browser uses bank 4, its operation dialogs use bank 5, and Text Editor
++ uses bank 6 plus a separate 2 KB document buffer in VERA RAM. Network Setup
uses bank 7, Market Watch uses bank 8, and its network worker uses bank 9. The
persistent-state service uses bank 10, Notes uses bank 11, and Comms uses bank
12. The shared 2 KB state image—including Calendar titles and the Market
cache—lives in VERA bank 1.
This keeps the core PRG safely below `$9F00` and establishes the overlay pattern
that future large apps can follow.

### File shortcuts

- File Manager: use the wheel, scrollbar, or arrows to browse; double-click or
  press `Enter`/`O` to open; `N` makes a file, `F` makes a folder, `R` renames,
  `M` moves, `D` deletes, `U` goes up, and `Esc` closes.
- Text Editor ++: type normally, use arrows and Backspace, `F2` saves, `F4`
  opens Save As, and `Esc` closes. Unsaved documents ask whether to save or
  discard changes.
- Network Setup: `D` detects the card/ZiModem, `W` scans, `J` joins a network,
  `I` refreshes IP status, and `Esc` closes. Every action also has a button.
- Market Watch: Add up to 12 symbols, choose **API KEY** to enter your own
  [Finnhub](https://finnhub.io/) key, select any row, and choose **UPDATE 3**.
  Arrows or the wheel scroll the list. Cached groups of three rotate on the
  desktop every 30 seconds; rotation does not spend additional API calls.
- Notes: click a visible row and type. Use the wheel or Up/Down cursor keys to
  move through all six slots. Changes are committed when Notes closes.

Market Watch sends Finnhub's compact quote request over HTTPS using ZiModem's
`AT&G` downloader. No shared service key is bundled. The key is masked and
omitted from command echo. It is stored unencrypted in `DCSTATE.BIN`, so users
should treat that SD-card file as private.
Quote availability, delay, and usage limits depend on the user's Finnhub plan
and exchange permissions; the display is informational, not trading guidance.

## 🧪 Toolchain

- Prog8 12.3.2
- 64tass 1.60.3243
- Commander X16 emulator r49
- Matching Commander X16 ROM r49
- Eclipse Temurin Java 21 runtime

Versions are pinned by `tools/setup-toolchain.sh` so a future upstream update
cannot silently change the build.

## 💾 Alpha persistence and data policy

Settings, Notes, Calendar events and view, Rolodex deletion state, the last
successful SSID/link state, Market Watch symbols/API key/cached quotes, and
other relevant preferences are stored in the versioned `DCSTATE.BIN` file on
device 8. Files edited in Text Editor ++ are naturally saved separately. Wi-Fi
passwords are deliberately never written by DESK COMMANDER.

`DCSTATE.BIN` begins with a format signature and version. A missing or invalid
alpha file produces a fresh state image. Current saves replace that file
directly; temporary-file replacement, backup recovery, full-media handling,
and physical power-loss tests remain release requirements rather than hidden
claims. Copy `DCSTATE.BIN` while Desk Commander is closed to back it up.

| Data | Alpha persistence behavior |
|---|---|
| Theme, pointer, sound, clock | Saved immediately when changed |
| Notes | Six slots of up to 21 characters; saved when Notes closes |
| Calendar | Current view and up to 24 titled events; saved when Calendar closes |
| Rolodex | Active/deleted state for the compiled sample cards |
| Network | Last SSID and last-confirmed link state; never the Wi-Fi password |
| Market Watch | Symbols, cached quotes, page, and user API key |
| Files | Saved as normal device-8 files by Text Editor ++ |
| Calculator and Comms | Deliberately temporary in the current alpha |

The current alpha includes sample notes, contacts, and events so unfinished
features are easy to evaluate. The requested Market Watch defaults are GOOG,
MSFT, and TSLA. Calculator input and mock Comms selection are intentionally
temporary because they are not user records.

The production V1 first-run experience will contain **blank personal data**.
Sample records will only appear when the user deliberately chooses a Demo Data
option.

## 🗺️ Where development goes next

The immediate priorities are power-loss-safe storage, complete keyboard focus,
finished organizer records, and physical-hardware validation of the new
TexElec/ZiModem and Market Watch paths. After that, Comms can move into its own
banked app and share a non-blocking connection service.

Read [ROADMAP.md](ROADMAP.md) for milestones, networking commands, acceptance
tests, and every known unfinished V1 area.

---

Made by **Roddy** for the Commander X16. ❤️
