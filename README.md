# 🖥️ DESK COMMANDER

> A friendly, DeskMate-inspired personal desktop for the Commander X16.

![DESK COMMANDER splash screen](docs/images/splash.png)

DESK COMMANDER is an original retro organizer written in readable
[Prog8](https://prog8.readthedocs.io/) for the Commander X16. It combines
Notes, Calendar, Rolodex, Files, Calculator, Settings, Comms, and Market Watch
inside a crisp mouse-and-keyboard desktop.

> [!IMPORTANT]
> This is **version 0.2.0 alpha**. Several screens are working prototypes and
> personal data is not saved yet. See the [V1 roadmap](ROADMAP.md) for the
> complete, honest list of unfinished work.

## ✨ Current highlights

- 🖱️ Hardware mouse support with small blue, large red, and normal black pointers
- ⌨️ Arrow-key desktop selection with `Enter` to launch
- 🕐 Live RTC clock with working 12/24-hour formats
- 📝 Four editable in-memory Notes with Add and Delete
- 📅 Month navigation and 24 editable color-coded Calendar events
- 📇 Searchable, scrollable Rolodex with phone, email, and social fields
- 🧮 Functional mouse-and-keyboard Calculator
- 📁 Two-pane File Manager interface ready for real disk operations
- 🎨 X16, Amber, and Night theme packages
- 🔊 Subtle optional interface sounds
- 💬 Full-screen Comms prototype with direct chats, servers, and presence colors
- 📈 Market Watch demonstration panel
- 📡 TexElec X16 Serial & ESP32 Network Card setup screen
- ⚡ Dirty-region redraws that reduce flashing during normal interaction

## 🖼️ Screenshots

| Desktop | TexElec network setup |
|---|---|
| ![DESK COMMANDER desktop](docs/images/desktop.png) | ![TexElec X16 network settings](docs/images/network-settings.png) |

The Network screen is designed for the
[TexElec Commander X16 921.6Kbps Serial & ESP32 Network Card](https://texelec.com/product/commander-x16-serial-network-card/).
It reflects the card's preinstalled
[ZiModem](https://github.com/bozimmerman/Zimodem) interface, default IO7-low
network UART at `$9FE0`, 115200 baud, and RTS/CTS flow control. Hardware
detection, Wi-Fi scanning, credential entry, and AT-command transport remain
roadmap work.

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

# Compile build/main.prg.
make

# Remove generated build files.
make clean
```

## 🧭 App guide

| App | What works now | Still to come |
|---|---|---|
| Notes | Select, type, add, delete | Saved long-form notes, files, clipboard, undo |
| Calendar | Browse months; add/edit/delete typed events | Multiple daily events, agenda, recurrence, reminders, saving |
| Rolodex | Search, scroll, inspect, delete demo contacts | Create/edit contacts, sorting, import/export, saving |
| Calculator | Basic arithmetic, decimals, keyboard input | Memory keys and final edge-case testing |
| Files | Practical two-pane interface | Real CMDR-DOS directory and file operations |
| Settings | Theme, mouse, sound, clock, Network, About | Persistent preferences and working network configuration |
| Comms | Direct/server layout and selection | Accounts, transport, messages, history, real presence |
| Market Watch | Clearly labeled demo quotes | Watchlist, network feed, caching, stale/offline states |

## 🧰 Project layout

```text
src/main.p8          Program entry point
src/appmeta.p8       Version, creator, and copyright strings
src/theme.p8         Shared palette and theme packages
src/input.p8         Keyboard, mouse, cursor, and click-sound handling
src/font5x7.p8       Scalable splash-title font
src/splash.p8        Splash screen drawing and dismissal
src/desktop.p8       Desktop, Calculator, Files, Settings, and Network UI
src/notes_app.p8     In-memory Notes application
src/calendar_app.p8  Month view and event editor
src/rolodex_app.p8   Searchable contact-card application
src/comms_app.p8     Direct-message and server-chat prototype
docs/images/         GitHub screenshots
```

Generated files live in `build/`. Downloaded tools live in `.tools/`. Both are
excluded from source control.

Uninitialized app data is placed in X16 high-RAM bank 1 with Prog8's
`-varshigh 1` option. This preserves conventional RAM for the growing program;
network code must preserve the selected RAM bank when it is added.

## 🧪 Toolchain

- Prog8 12.3.2
- 64tass 1.60.3243
- Commander X16 emulator r49
- Matching Commander X16 ROM r49
- Eclipse Temurin Java 21 runtime

Versions are pinned by `tools/setup-toolchain.sh` so a future upstream update
cannot silently change the build.

## 💾 Alpha data policy

The current alpha includes sample notes, contacts, and events so unfinished
features are easy to evaluate. Changes last only for the current session.

The production V1 first-run experience will contain **blank personal data**.
Sample records will only appear when the user deliberately chooses a Demo Data
option.

## 🗺️ Where development goes next

The immediate priorities are persistent storage, complete keyboard focus,
finished organizer records, and the real TexElec/ZiModem driver. After that,
Comms and Market Watch can share one safe, non-blocking connection service.

Read [ROADMAP.md](ROADMAP.md) for milestones, networking commands, acceptance
tests, and every known unfinished V1 area.

---

Made by **Roddy** for the Commander X16. ❤️
