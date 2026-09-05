# DESK COMMANDER

DESK COMMANDER is a DeskMate-inspired personal desktop and organizer for the
Commander X16. The project is written in readable Prog8, with small modules,
plain control flow, and comments that explain hardware-specific decisions.

The current alpha contains:

- A native 320x240 VERA splash screen
- DESK COMMANDER, creator, year, and version branding
- A transparent source copy of the supplied RODDY logo
- Keyboard-or-mouse splash dismissal
- A mouse-enabled organizer dashboard
- A live Commander X16 RTC clock in the top identity bar
- A clean single desktop header without non-functional menu commands
- Tall Notes and Calendar at-a-glance sections
- A symbol-only left app rail for Files, Calculator, Rolodex, Comms, and Settings
- An in-memory Notes app with selection, typing, Add, and Delete controls
- A clickable Calendar with appointment, task, and personal event colors
- Editable Event Details for every date, with type, Delete, and Done controls
- Previous/next month arrows with correct month lengths and year rollover
- A live at-a-glance calendar reflecting event dates, types, and colors
- A searchable and scrollable Rolodex with Delete, email, and social fields
- A wide Market Watch placeholder with clearly labeled demo quotes
- A working mouse-and-keyboard Calculator with decimals and error handling
- A two-pane File Manager window with places, file types, and clear actions
- A visual Settings window with six distinct preference categories
- Hover feedback and clickable buildout placeholders for every section
- A pinned, project-local Prog8 and X16 emulator toolchain

## Run it

From this directory:

```bash
./run.sh
```

The first run downloads and prepares the pinned development tools beneath
`.tools/`. This takes longer than later runs but does not install anything
system-wide. Subsequent runs rebuild changed source files and launch the X16
emulator immediately.

On the splash screen, press any key or click the left mouse button. On the
desktop, click Calendar and then click any date to view or edit its event.
Type to change the event name, use Backspace to erase, and click a colored
button to set its type. Use the arrow buttons beside the month to browse the
calendar. Changes currently remain in memory until the app is closed. Press
`Esc` to close the current window or return to BASIC.

## Other useful commands

```bash
# Download or repair the local toolchain without launching the app.
./tools/setup-toolchain.sh

# Compile only.
make

# Ask Prog8 to check the program without producing a binary.
make check

# Remove generated program and assembly files.
make clean
```

## Source map

```text
src/main.p8       Small program entry point
src/appmeta.p8    Name, version, creator, and copyright strings
src/theme.p8      Shared X16 palette indexes and RGB colors
src/input.p8      Keyboard and mouse polling
src/font5x7.p8    Scalable splash-title font
src/splash.p8     Splash screen drawing and dismissal
src/desktop.p8    Interactive desktop and accessory windows
src/notes_app.p8  In-memory Notes app
src/calendar_app.p8 Interactive month view and event editor
src/rolodex_app.p8 Searchable and scrollable contact-card app
```

Generated files go into `build/`. Downloaded tools go into `.tools/`. Both are
ignored by Git.

## Tool versions

- Prog8 12.3.2
- 64tass 1.60.3243
- Commander X16 emulator r49
- Matching r49 Commander X16 ROM
- Eclipse Temurin Java 21 runtime

Versions are pinned in `tools/setup-toolchain.sh` so that the same source does
not unexpectedly compile differently after an upstream release.

The alpha intentionally includes sample notes, contacts, and calendar events
to make unfinished features easy to test. The normal V1 first-run experience
will start with blank personal data; sample content will only appear when a
user explicitly chooses a demo-data option.

See [ROADMAP.md](ROADMAP.md) for the complete V1 plan.
