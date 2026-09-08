# 🖥️ DESK COMMANDER

> A friendly, DeskMate-inspired desktop and personal organizer for the Commander X16.

![DESK COMMANDER splash screen](docs/images/splash.png)

DESK COMMANDER is an original application written in readable
[Prog8](https://prog8.readthedocs.io/) for the Commander X16. It brings notes,
appointments, contacts, files, calculations, market information, settings,
and internet chat together behind one mouse-and-keyboard desktop.

The goal is not to copy a modern PC. It is to make the X16 feel like a useful,
cohesive personal computer while keeping the design fast, colorful, and
distinctly retro.

> [!IMPORTANT]
> The current release is **version 0.3.0 alpha**. It builds, boots, and runs on
> a real Commander X16 with ROM r49. Core features are usable, but data-safety,
> storage recovery, organizer depth, and long hardware testing must be completed
> before V1. See the [V1 roadmap](ROADMAP.md) for the honest remaining work.

## ✨ What it can do

### Desktop and controls

- Use a hardware mouse or keyboard to operate the desktop.
- Select desktop apps with the arrow keys and open them with `Enter`.
- Display the X16 real-time clock in saved 12-hour or 24-hour format.
- Switch between X16, Amber, and Night theme packages.
- Choose a small blue, large red, or normal black mouse pointer.
- Enable or mute subtle click, send, and receive sounds.
- Show compact sound and live Wi-Fi indicators in the top bar.
- Redraw scrolling regions instead of flashing the entire screen.

### Organizer applications

- **📝 Notes:** maintain six titled, multiline notes in a scrollable list and
  open them safely in a read-only reader before choosing Edit.
- **📅 Calendar:** browse months and add, view, edit, or delete color-coded
  appointments, tasks, and personal events.
- **📇 Desk Directory:** add, edit, search, scroll, inspect, and delete saved contact cards
  with name, role, phone, a 47-character email field, and social fields.
- **🧮 Calculator:** perform mouse- or keyboard-driven arithmetic with decimals.
- **📁 Files:** browse device 8, enter folders, create files or directories,
  rename, move, delete, edit text, and launch X16 programs.
- **✍️ Text Editor ++:** edit multiline text with mouse placement, Save, Save
  As, and an unsaved-work warning.
- **🌌 Deep Space Screensaver:** watch a clean parallax starfield surrounding
  a shiny cartoon refrigerator with chrome handles and a friendly face. Its
  hardware sprite drifts without erase/redraw blinking; leave with any key or click.

### Connected applications

- **📡 Network Setup:** detect the TexElec card at `$9FE0`, communicate with
  ZiModem, scan scrollable Wi-Fi results, join a selected network, inspect IP
  status, disconnect, and run a clear connection test.
- **💬 Comms:** save a username and host, add or remove friends, create or leave
  groups, exchange direct/group messages, sync automatically, scroll retained
  history, show presence, play optional sounds, and send five locally drawn
  emoji faces.
- **📈 Market Watch:** save up to 12 symbols, show three at a time on the
  desktop, refresh quotes, and retain the previous successful value so movement
  can be compared after a restart.

## 🖼️ Screenshots

| Desktop | TexElec Network Setup |
|---|---|
| ![DESK COMMANDER desktop](docs/images/desktop.png) | ![TexElec X16 network settings](docs/images/network-settings.png) |

## 📋 Application status

| Application | Available now | Important V1 work remaining |
|---|---|---|
| Desktop | App rail, glance panels, clock, sound/Wi-Fi status, keyboard selection | Connect glance notes to full Notes data; finish keyboard focus |
| Notes | Six persistent titled multiline notes, read-only Open, explicit Edit, transactional Add/Delete, keyboard focus, scrolling | Word-aware wrapping, undo, import/export |
| Calendar | Month navigation, 24 persistent events with 47-character wrapped details, direct dashboard-date opening | Multiple events per day, agenda, recurrence, reminders, RTC Today |
| Desk Directory | Blank first run; search, scrolling, detailed cards, transactional Add/Edit/Delete, safe legacy-record migration, 47-character email addresses | Larger capacity, sorting, duplicate, import/export |
| Calculator | Arithmetic, decimals, backspace, divide-by-zero handling | Memory keys and final edge-case testing |
| File Manager | Real device-8 browsing, file/folder operations, text open, and protected PRG/AUTOBOOT launch | Copy, destination browser, filters, richer error handling |
| Text Editor ++ | Multiline editing, Save, Save As, mouse placement | Find, clipboard, undo, larger documents, safer replacement saves |
| Screensaver | Parallax stars and a drifting chrome cartoon refrigerator; instant keyboard/mouse exit | Additional scenes and optional idle timer |
| Settings | Persistent theme, cursor, sound, and clock; Network and About | Keyboard focus, Restore Defaults, storage tools decision |
| Network Setup | Physical card detection, scan, join, IP status, disconnect, connection test | Recovery modes, richer errors, sustained-transfer testing |
| Comms | Password-authenticated direct/group chat over HTTPS, saved credentials, expiring browser sessions, presence, sounds, emoji | Recovery, credential rotation, certificate pinning, unread state, moderation |
| Market Watch | Persistent watchlist/cache, keyless assets, optional Finnhub stocks | Hardware API validation, timestamps, rate-limit and stale-data polish |

## 🚀 Run it in the emulator

From a terminal:

```bash
cd "/home/legion/Desktop/DESK COMMANDER"
./run.sh
```

The first run downloads the pinned tools into `.tools/`; it does not install
them system-wide. Later runs rebuild only changed components and open the X16
emulator.

On the splash screen, press a key or click. On the desktop, click an app or use
the arrow keys and `Enter`. Press `Esc` to close the current app or return to
BASIC.

### Build commands

```bash
# Verify every Prog8 target without producing a release.
make check

# Compile the main program and all loadable modules.
make

# Create the complete X16 package in dist/sdcard/.
make sdcard

# Validate, build, and create dist/release/DESK-COMMANDER-X16.zip.
DESKPKG

# Delete generated build files.
make clean
```

## 💾 Install on a real Commander X16

The easiest development deployment is the `deskbuild` alias created on this
computer. With the SD card inserted and mounted as `X16_SDCARD`, run:

```bash
cd "/home/legion/Desktop/DESK COMMANDER"
deskbuild
```

That command rebuilds the application, copies the complete runtime into
`/DESKCMD` on the SD card, installs an optional root launch shortcut for this
development machine, preserves user data, flushes pending writes, and verifies
every copied file. Public `DESKPKG` archives contain only the single folder.

For a manual installation, run `make sdcard` and copy everything inside
`dist/sdcard/` into one `DESKCMD` directory on a FAT32 SD card.

For distribution, run `DESKPKG`. It creates one clean archive at
`dist/release/DESK-COMMANDER-X16.zip` without personal `DCSTATE.BIN` data.
Extract that archive directly into the SD-card root. The archive contains one
self-contained `/DESKCMD` directory and puts no loose files in the card root.
Open that directory in an X16 launcher and select `AUTOBOOT.X16`, or enter the
directory and load `DCMAIN.PRG` directly from BASIC.

### Launch from BASIC

From the SD-card root, the installed shortcut can be run with the ROM DOS wedge:

```basic
^DESKCMD.PRG
```

Or launch the main program directly:

```basic
CD "DESKCMD"
LOAD "DCMAIN.PRG",8,1
RUN
```

`AUTOBOOT.X16` is the packaged application entry point. A compatible X16 app
launcher should open the `DESKCMD` directory or its `AUTOBOOT.X16` file. The
small root `DESKCMD.PRG` is an optional BASIC launch helper. The real compiled
program is `/DESKCMD/DCMAIN.PRG`, and its loadable banks remain beside it inside
`/DESKCMD`.

DESK COMMANDER currently targets ROM r49. The official
[ROM r49 release notes](https://github.com/X16Community/x16-rom/releases/tag/r49)
recommend VERA 48.0.1 and SMC 48.0.0 or 47.2.3.

## 🧭 Everyday controls

### Opening files and other X16 programs

In Files, select an item and choose **Open** (or press Enter); double-click
also opens it. Folders stay inside the current browsing tree, and closing
Files returns to Desk Commander's own folder so its other apps remain available.

- **`.PRG` and `.X16` programs:** Open exits Desk Commander and starts the
  selected program through BASIC's LOAD/RUN chain. This includes `AUTOBOOT.X16`
  and normal compiled programs with a BASIC `SYS` starter. The target's current
  directory is retained so it can load its companion files. Reopen Desk
  Commander when finished; this is a program launch, not an app overlay.
- **Raw machine-code binaries:** these need their own loader/entry address.
  Files reports `NEEDS BASIC LOADER` rather than guessing an address.
- **Text files:** open in Text Editor ++ and return to Files when closed.
  Binary control data and files over 2,047 bytes are rejected before editing
  (`NOT TEXT OR OVER 2K`), protecting originals from partial-file saves.
- **Names and Move paths:** support up to 50 characters; the input shows the
  last 24 while typing. Rename preserves the complete original name.

The conventional boot filename is **`AUTOBOOT.X16`**, not `AUTOBOOT.16`.
An SD/HostFS directory's generic `PRG` type is not enough to treat text or
`.BIN` assets as executable; use the actual `.PRG`/`.X16` filename suffix.

### Keyboard and mouse

In **Settings**, click **Theme** to cycle Commander, Amber, Midnight, Phosphor
(`PHOS`: charcoal/green/soft white), and Lunar (navy/silver/cyan). Click **Mouse**
to cycle small blue, large red, black, high-contrast white arrow, and precision
crosshair. The crosshair's center is its click point. Both selections save to
SD immediately; existing saved choices retain their original numbers.
Chat/emoji colors stay fixed, and the new themes keep red, teal, and gold
event/status colors distinct. These options do not change app layouts.

- **Desktop:** click an app, or use arrows and `Enter`.
- **Close:** use the visible red `X` or press `Esc`.
- **Scrollable areas:** use the mouse wheel, scrollbar, or arrow keys.
- **File Manager:** `Enter`/`O` opens, `N` creates a file, `F` creates a folder,
  `R` renames, `M` moves, `D` deletes, and `U` goes up.
- **Text Editor ++:** type normally; `F2` saves, `F4` opens Save As, and `Esc`
  closes with an unsaved-work check.
- **Notes:** click a populated row or select it with arrows and press `Enter` to
  open the read-only reader. Choose Edit there to make changes. `Tab` also
  reaches Add/Edit/Delete/Done. Inside the reader, Tab selects Edit or Done;
  arrows/wheel scroll long notes. The body editor follows the end while typing.
- **Desk Directory:** type to filter, use arrows/wheel to select, `Enter` edits,
  `Insert` adds, and `Delete` twice deletes when the search field is empty.
  Click the card's **CLICK TO VIEW** area to read every field, including the
  complete email address. In the email editor, left/right arrows move the
  cursor; typing inserts and Backspace deletes before it. Cancel rolls back
  the entire card.
- **Calendar:** click a highlighted dashboard date to open its event details
  directly. The heading or an unhighlighted area opens the month view. Event
  text supports 47 characters across three lines; Done or Esc saves and closes.
- **Network Setup:** `D` detects, `W` scans, `J` joins, `I` checks status, and
  `Esc` closes. Select an SSID with the pointer, arrows, wheel, or number.
- **Comms:** set `USER` plus its password and an HTTPS `HOST`, press `SYNC`, open the square conversation
  selector, choose a friend or group, type in the bottom field, and press
  `Enter` or `SEND`.

Keyboard behavior is not yet completely uniform in every dialog. Completing
universal visible focus is a V1 requirement.

## 📡 TexElec network setup

The supported adapter is the
[TexElec Commander X16 921.6Kbps Serial & ESP32 Network Card](https://texelec.com/product/commander-x16-serial-network-card/)
running [ZiModem](https://github.com/bozimmerman/Zimodem).

The tested default configuration is:

- Network UART at IO7-low `$9FE0-$9FEF`
- 115200 baud, 8N1
- RTS/CTS flow control
- Option Pin A high

On physical hardware, Desk Commander can detect the UART and ZiModem, scan for
access points, select and join Wi-Fi, obtain IP status, disconnect, and complete
an outbound connection test. The Network screen shows progress before every
bounded modem operation so a slow scan does not look like a frozen menu.

Wi-Fi passwords are case-preserving while entered but are **never saved by Desk
Commander**. ZiModem itself may remember a confirmed network configuration in
its firmware. Cards purchased before October 2024 may be affected by the
replacement notice on TexElec's product page.

## 💬 Comms and the official alpha service

Comms supports direct friends and group conversations. A friend can be saved
while offline and will remain in the list. Green means online, yellow means
away, and red means offline. Message history is bounded and scrollable; sent and
received messages appear in the same transcript. The local user's message block
is green, while other senders receive stable bright colors.

The five-face picker contains smile, frown, wink, red angry, and extra-happy
faces. The X16 stores compact three-byte tokens and draws the faces locally;
the server translates those tokens into normal Unicode emoji for browsers. The
banked renderer explicitly initializes normal drawing mode, preventing the
random XOR/inverted palette colors previously seen on physical hardware.

Every account joins the protected **WELCOME** group so a new tester has a place
to talk immediately. Ordinary alpha accounts are limited to 8 friends, 4
groups, 32 members per group, and 100 retained messages per conversation.

### Connect the X16

In Comms:

1. Set `HOST` to `143-244-168-180.sslip.io`.
2. Set `USER` to your desired username, then enter an 8–24 character password.
   A new name is securely claimed; an existing name requires its password.
3. Press `SYNC`.
4. Open the square conversation selector and choose `WELCOME` or `RODDY`.
5. Type in the bottom message field and press `SEND`.

`USER`, `HOST`, and the masked account password are saved in `DCSTATE.BIN` until
changed. The host remains editable so the X16 can connect to an official,
community, or private HTTPS-compatible server.

### Browser clients

- Public X16-style tester:
  [https://console.143-244-168-180.sslip.io/chat/](https://console.143-244-168-180.sslip.io/chat/)
- RODDY manager console:
  [https://console.143-244-168-180.sslip.io](https://console.143-244-168-180.sslip.io)

The public tester deliberately resembles the 320×240 X16 Comms application and
uses the same conversations. The manager console can inspect users, friends,
groups, presence, device traffic, direct messages, and simulated group users.

The manager token is stored outside this repository at:

```text
/home/legion/.config/deskcommander/admin-token
```

Display it locally with:

```bash
sed -n '1p' /home/legion/.config/deskcommander/admin-token
```

> [!IMPORTANT]
> Browser and X16 chat now use password-authenticated accounts. Passwords are
> stored on the server only as salted scrypt hashes. Browser clients receive a
> random 12-hour bearer session; the X16 sends its credential inside each
> ZiModem HTTPS request. Messages are TLS-encrypted in transit, but this is not
> end-to-end encryption—the selected chat server can read stored messages.

> [!WARNING]
> Current ZiModem HTTPS encrypts traffic but does not validate the server
> certificate, so a hostile network could still impersonate the host. The X16
> also has no secure credential vault: its masked password is recoverable by
> someone with the SD card. Do not reuse an important password. Certificate
> pinning/application-layer server authentication remains a V1 hardening item.

### Run the local test server

For same-network development:

```bash
cd "/home/legion/Desktop/DESK COMMANDER"
DESKSVR
```

The equivalent direct command is `./tools/run-chat-server.sh`. Open
`http://localhost:8088` for browser-only local testing. An X16 host now requires
an HTTPS hostname and reverse proxy; use the Caddy example in `backend/deploy`
for a private compatible host. Do not expose bare port 8088 to the internet.

## 📈 Market Watch data

Market Watch starts with GOOG, MSFT, and TSLA and supports up to 12 symbols.
Gold (`XAU`), silver (`XAG`), and Bitcoin (`BTC`) use a keyless current-price
feed. Other equities use a user-supplied free
[Finnhub](https://finnhub.io/) API key, subject to that account's plan and
exchange permissions.

Successful quotes are cached in `DCSTATE.BIN`. A new result compares against
the previous saved value, including after a power cycle. Only the first valid
quote begins at `0.00%`; failed refreshes do not erase the last baseline. Market
data is informational and may be delayed—it is not trading guidance.

## 💾 Saved data and privacy

Desk Commander stores its bounded 4 KB application state in `DCSTATE.BIN` on
device 8. The file has a signature and format version. If it is missing or invalid, the
alpha creates a fresh state image.

| Data | Current behavior |
|---|---|
| Theme, cursor, sound, clock | Saved immediately when changed |
| Notes | Six titled 108-character multiline records saved after each committed edit |
| Calendar | Current view and up to 24 titled events |
| Desk Directory | Active/deleted state plus four complete user-created contact cards |
| Network | Last SSID and confirmed-link indicator; never the Wi-Fi password |
| Market Watch | Symbols, quotes, page, and optional user API key |
| Comms identity | X16 username, HTTPS host, and masked account password saved locally |
| Friends, groups, chat history | Saved by the selected chat server |
| Edited files | Written as ordinary device-8 files |

Current saves replace `DCSTATE.BIN` directly. Temporary-file replacement,
backup recovery, full/write-protected-media handling, and power-loss testing
remain V1 release blockers. Back up `DCSTATE.BIN` only while Desk Commander is
closed.

Desk Directory now starts blank and stores only contacts created by the user. Some
other alpha organizer screens still include demo records; production V1 will
start all personal data blank unless Demo Data is explicitly selected.

## 🧰 Project structure

```text
src/                    Prog8 application, UI, drivers, and banked modules
server/                 Simple LAN/public-alpha Python chat compatibility server
server/web/             Manager console and X16-style browser tester
backend/                Modular FastAPI/SQLite RetroWire service foundation
docs/RETROWIRE.md       Draft multi-platform secure protocol
docs/images/            GitHub screenshots
tools/                  Toolchain setup, emulator, server, and SD deploy scripts
build/                  Generated compiler and assembler output
dist/sdcard/            Complete SD-card-ready runtime package
```

The core PRG remains below the X16 I/O window. Larger features are loaded into
RAM banks 4 through 20: Files, operations, editor, external launcher, Network,
SSID picker, Market Watch, quote fetching, persistence, Notes, Comms, chat HTTP,
chat rendering, emoji artwork, the Deep Space screensaver, Desk Directory, and
organizer dialogs. Compact
dashboard-card artwork remains in the safely sized core program.
Shared bounded state and chat buffers use
VERA RAM. Runtime filenames are 8.3-safe for both HostFS and physical SD cards.

After building, run `python tools/test-organizer.py` in a Python environment
with `py65` installed to execute the compiled 65C02 organizer regression tests.
These check bank entry addresses, migration boundaries, long-email editing,
read-only Notes, and contact save/rollback copies. ROM, input, video, and disk
operations are stubbed; physical-machine UI and SD tests are still required.
Run `python tools/test-files.py` in the same environment for file routing,
safe text limits, full filenames, and bounded DOS commands. Run
`python3 tools/test-file-launch.py` for real-ROM emulator checks of BASIC,
SYS, AUTOBOOT, and missing/invalid program handling (no SD card required).
Run `python tools/test-styles.py` for palette/preset persistence checks, cursor
pixels, and refrigerator sprite bounds/movement. It also writes a pixel preview
to `/tmp/desk-style-preview.png` for inspection.

Run `python tools/test-calendar.py` for compiled calendar text-limit,
storage-boundary, wrapping, and dashboard-date hitbox checks.

The pinned toolchain is:

- Prog8 12.3.2
- 64tass 1.60.3243
- Commander X16 emulator and ROM r49
- Eclipse Temurin Java 21

## 🗺️ What comes next

The next release work is centered on safe SD-card writes, certificate/server
authentication, account recovery and credential rotation, deeper Calendar and
Directory capacity, consistent keyboard parity, safer file editing, and long
real-hardware tests.

Read [ROADMAP.md](ROADMAP.md) for the prioritized checklist, milestones,
acceptance journey, and release gates.

---

Made by **Roddy** for the Commander X16. ❤️
