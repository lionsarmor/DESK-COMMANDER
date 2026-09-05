# DESK COMMANDER — Version 1 Roadmap

> A fast, friendly, DeskMate-inspired personal desktop and organizer for the Commander X16.

**Current implementation status:** Version 0.2.0 is an early alpha. M0 is
complete, the M1 interaction prototype is underway, and early pieces of the
desktop, Notes, Calendar, Rolodex, File Manager, Calculator, and Settings are
running.
The project uses Prog8 12.3.2, Commander X16 ROM/emulator r49, and a 320x240
256-color VERA bitmap screen. Build and launch it through `./run.sh`.

Alpha builds contain sample records for visual testing. Production V1 builds
must start with blank personal data, with sample records available only through
an explicit demo-data option.

## 1. V1 Vision

DESK COMMANDER V1 will provide a cohesive desktop environment for everyday personal organization. It should feel at home on an 8-bit computer: immediate, understandable, keyboard-friendly, colorful, and dependable.

V1 is an integrated organizer rather than a complete office suite. Its essential applications are:

- Desktop shell
- Calendar, appointments, tasks, and alarms
- Text editor and quick notes
- Card-file database and contacts
- File manager and shared file dialogs
- Clipboard
- Calculator, clock, and other small desk accessories
- Basic printing

The defining feature is integration. All applications use the same controls, shortcuts, file dialogs, clipboard, and visual language.

## 2. Product Principles

1. **Fast first:** reach the desktop quickly and keep interaction responsive.
2. **Useful without a manual:** common actions should be visible in menus and dialogs.
3. **Keyboard and mouse are equals:** every action must be possible from the keyboard; the mouse should make the same action convenient.
4. **Data is precious:** saving must be predictable, recoverable, and resistant to interrupted writes.
5. **One coherent suite:** shared behavior matters more than the number of applications.
6. **Authentically X16:** embrace the machine's palette, sound, RTC, mouse, keyboard, VERA graphics, and SD-card storage.
7. **Inspired, not copied:** use original branding, icons, artwork, terminology, and file formats.

## 3. V1 Scope

### P0 — Required to ship

#### Desktop shell

- Application launcher with original icons
- Menu bar and pull-down menus
- Date and clock display
- Keyboard focus and navigation
- Hardware mouse pointer using the Commander X16 mouse facilities
- Left-click selection and activation
- Double-click application and document launching
- Right-click context menus where they provide useful commands
- Mouse-wheel scrolling in lists, documents, cards, and calendar views
- Pointer feedback for clickable, disabled, selected, and dragging states
- Common dialog system
- Recent or associated document list for each application
- About screen and version information
- Clean return to the desktop from every application

#### Calendar and tasks

- Month view
- Day agenda view
- Create, edit, move, and delete appointments
- Create, complete, and reopen tasks
- Optional start time and reminder for an item
- Daily, weekly, monthly, and yearly recurrence
- Visible indication of days containing items
- Today's agenda on startup or one key away
- Alarm notification using sound and a visible dialog
- Calendar and task data saved between sessions

#### Text and quick notes

- Create, open, edit, and save plain-text documents
- Insert and overwrite modes
- Cursor movement and text selection
- Word wrap
- Cut, copy, and paste
- Find text
- Undo for at least the most recent edit
- Save As
- Unsaved-change warning
- Basic printing
- Small quick-note accessory available from anywhere practical

#### Cards and contacts

- Create card files
- Built-in contact template
- User-named text fields
- Add, edit, duplicate, and delete cards
- Browse cards sequentially
- Search all displayed fields
- Sort contacts alphabetically
- Copy a field or complete address to the shared clipboard
- Import and export a documented delimited-text format

#### Files and storage

- Shared New, Open, Save, and Save As behavior
- Directory navigation
- Rename, copy, and delete files with confirmation
- File filtering by application or file type
- Friendly handling of missing disks, full disks, invalid names, and I/O errors
- Atomic-style save flow: write a temporary file before replacing valid data
- Recovery or backup copy for important organizer data
- Version identifier in every native DESK COMMANDER file format
- No silent destruction of a newer or unknown file format

#### Shared desktop services

- Text clipboard usable across Text, Cards, and Calendar
- Four-function calculator with memory
- Clock and alarm status
- Standard printer output path
- Consistent Help, About, and error dialogs
- User preferences saved between sessions

### P1 — Ship only if P0 is stable

- Small worksheet application
- Calendar and contact-list printing
- Address-label printing
- CSV import and export for worksheet data
- Startup preference: desktop or today's agenda
- Recently opened documents
- User-selectable color themes

### Explicitly deferred beyond V1

- Paint or Draw
- Music composition and sound editing
- Serial terminal, online services, or networking
- Email
- Full spreadsheet compatibility or advanced formulas
- Rich fonts and desktop publishing
- Spell checking
- Mail merge
- Recipe, meal-planning, grocery, and checkbook applications
- Multiple overlapping windows
- Preemptive multitasking
- External-program task switching
- Third-party application SDK

## 4. Recommended V1 Interaction Model

V1 should use a single foreground application with persistent desktop services. This keeps memory use and state management understandable while preserving the feel of an integrated environment.

### Global controls

- A consistent key opens the application or system menu.
- `Tab` and `Shift+Tab` move focus between controls.
- Arrow keys navigate menus, lists, calendars, and fields.
- `Enter` activates the focused command.
- `Esc` cancels a dialog or returns one level.
- Standard shortcuts cover New, Open, Save, Print, Cut, Copy, Paste, Find, and Help.
- Destructive actions always require deliberate confirmation.

The final key map should be tested on real Commander X16 keyboard layouts and documented in one quick-reference screen.

### V1 mouse behavior

Mouse support is a release requirement across the entire suite, not just on the desktop.

- A visible pointer must be available in every interactive screen.
- A single left click selects an icon, list item, date, card, field, or control.
- A double left click opens applications, documents, and browsable containers.
- Clicking a menu title opens its menu; moving across menu titles switches the open menu.
- Pressing and dragging selects text and moves scroll thumbs where those features are present.
- The mouse wheel scrolls the control beneath the pointer when possible, otherwise the focused view.
- Right click opens a small context menu where useful; screens without a context menu ignore it safely.
- Buttons visibly depress on press and activate on release while the pointer remains over them.
- Disabled controls do not activate and look visually disabled.
- Modal dialogs constrain clicks to the dialog and provide clear OK, Cancel, or Close targets.
- Pointer movement is clamped to the active display and remains correct after a screen-mode change.
- Accidental motion must not change keyboard focus until a click or wheel action occurs.
- Keyboard navigation remains fully available for users without a mouse.

## 5. Technical Foundation

The exact programming language and toolchain remain open, but V1 should be divided into reusable layers from the start.

### Platform layer

- Keyboard event normalization
- Mouse position, buttons, double-click timing, and wheel input
- RTC date and time access
- Timers and alarm polling
- VERA screen, palette, sprites, and drawing primitives
- File and directory operations through the X16 KERNAL/CMDR-DOS interfaces
- Printer output abstraction
- Simple sound cues

### UI toolkit

- Desktop and application screen layout
- Menu bar and pull-down menus
- Buttons, labels, text fields, checkboxes, and radio buttons
- Scrollable lists
- Message, confirmation, and file dialogs
- Focus management
- Keyboard shortcuts and mnemonics
- Mouse hit testing
- Status and help line
- Theme and palette constants

### Application services

- Shared clipboard
- Preferences
- Recent-document tracking
- Date and recurrence calculations
- Document lifecycle and dirty-state tracking
- File-format versioning
- Temporary-save, backup, and recovery flow
- Common print interface

### Applications

- Desktop
- Calendar/Tasks
- Text
- Cards/Contacts
- File Manager
- Calculator and Quick Notes
- Worksheet, if promoted from P1

## 6. Milestones

Milestones are ordered by dependency, not calendar date. Each milestone should run in the current X16 emulator and be smoke-tested on real hardware whenever available.

### M0 — Project definition and toolchain

**Goal:** establish a reproducible build and a fixed V1 target.

- Select implementation language, compiler/assembler, and build system.
- Select the minimum supported Commander X16 ROM release.
- Decide the initial video mode and working resolution.
- Define memory ownership and banking conventions.
- Define repository structure and coding conventions.
- Add one-command debug and release builds.
- Add emulator launch configuration with an isolated test SD-card image or directory.
- Record the initial performance and memory budgets.

**Exit criteria:** a fresh checkout builds and launches a versioned DESK COMMANDER splash screen and empty desktop.

### M1 — Input, graphics, and UI prototype

**Goal:** prove the interaction model before building applications.

- Initialize the screen, palette, mouse, keyboard, and clock.
- Implement normalized input events.
- Implement mouse-button edge detection, capture, double-click timing, and wheel events.
- Implement pointer clamping and screen-mode reconfiguration.
- Implement focus navigation and shortcuts.
- Implement menu, button, text field, list, and dialog controls.
- Implement hover, press, drag, release, and disabled visual states.
- Establish the desktop visual style and original icon language.
- Add a UI playground/test screen containing every control.

**Exit criteria:** all controls work with both keyboard and mouse; click, double-click, right-click, drag, and wheel behavior pass the mouse acceptance checks; focus remains visible; and the UI stays responsive under continuous input.

### M2 — Desktop shell and common services

**Goal:** create the stable frame that all applications share.

- Build the application launcher and menu bar.
- Display RTC date and time.
- Implement application entry and exit.
- Add preferences, Help, About, and error dialogs.
- Implement the clipboard service.
- Establish application document associations.
- Add calculator and clock accessories.

**Exit criteria:** the user can boot to the desktop, launch placeholder applications, use accessories, and return without losing desktop state.

### M3 — Storage and document safety

**Goal:** make data trustworthy before applications depend on it.

- Implement directory browsing and shared file dialogs.
- Implement New, Open, Save, Save As, Rename, Copy, and Delete.
- Define versioned file headers and error rules.
- Implement temporary-file saves plus backup/recovery behavior.
- Track dirty documents and warn before closing or replacing them.
- Test full media, missing media, write protection, corrupt files, interrupted saves, and unsupported file versions.

**Exit criteria:** repeated error-injection tests do not silently lose the last known-good document.

### M4 — Calendar, tasks, and alarms

**Goal:** deliver the core personal-organizer workflow.

- Implement robust date arithmetic and leap-year handling.
- Build month and day views.
- Build appointment and task editors.
- Implement recurrence rules.
- Implement completed-task state.
- Poll reminders and display audible/visible alarm notifications.
- Save and reload calendar data.
- Add today's agenda entry point.

**Exit criteria:** a user can manage one month of mixed appointments and tasks, restart the machine, and receive the correct reminders afterward.

### M5 — Text and Quick Notes

**Goal:** provide dependable writing and cross-application text movement.

- Implement the text buffer and editor viewport.
- Add selection, clipboard operations, word wrap, find, and one-level undo.
- Add document opening, saving, recovery, and printing.
- Add a small quick-note accessory.
- Test documents larger than the visible window and available conventional memory.

**Exit criteria:** the user can write, revise, save, reopen, recover, and print a useful document without corrupting it.

### M6 — Cards and contacts

**Goal:** provide a reusable personal information database.

- Define card-file and contact schemas.
- Implement record editing and sequential browsing.
- Implement search and alphabetical sort.
- Integrate clipboard operations.
- Implement documented delimited-text import/export.
- Add contact selection from Calendar where practical.

**Exit criteria:** the user can maintain, search, export, and restore a realistically sized contact collection.

### M7 — Integration and optional P1 decision

**Goal:** make the separate features behave like one product.

- Unify menus, shortcuts, dialogs, status messages, and errors.
- Copy contact data into Text and Calendar.
- Open associated documents from the desktop.
- Exercise alarms while each application is active.
- Measure startup time, application-switch time, input latency, memory use, and disk use.
- Fix all P0 data-loss, crash, navigation, and alarm defects.
- Decide whether the worksheet can be added without delaying or destabilizing V1.

**Exit criteria:** every primary workflow crosses applications cleanly and meets the release quality gates below.

### M8 — Release candidate and launch

**Goal:** produce a distributable, documented V1.

- Freeze native file formats.
- Freeze visible UI text and default shortcuts.
- Complete real-hardware compatibility testing.
- Create example contacts, appointments, notes, and documents.
- Write the user guide, quick reference, installation instructions, and file-format notes.
- Package emulator-ready and SD-card-ready releases.
- Publish known limitations and upgrade/backup guidance.
- Tag and archive the reproducible V1 source and binaries.

**Exit criteria:** a new user can install DESK COMMANDER, complete the core acceptance journey, back up their data, and recover from a failed save using only the included documentation.

## 7. Core Acceptance Journey

Before V1 can ship, a first-time user must be able to complete this journey without developer assistance:

1. Start DESK COMMANDER and reach the desktop.
2. Create a contact in Cards.
3. Create an appointment linked to or labeled with that contact.
4. Set a reminder and observe the correct alarm.
5. Create a text note and paste the contact's address into it.
6. Save, close, reopen, edit, and print the note.
7. Create and complete a task.
8. Restart DESK COMMANDER and find all saved data intact.
9. Rename and copy a document through the File Manager.
10. Recover the last known-good data after a simulated interrupted save.

## 8. Release Quality Gates

V1 is ready only when all of the following are true:

- All P0 features are complete; no placeholder actions remain in shipping menus.
- No known bug can silently corrupt or discard user data.
- Calendar reminders survive save, restart, and date transitions.
- Keyboard-only operation covers every required workflow.
- Mouse-only operation covers normal workflows except unavoidable text entry.
- Every visible interactive control has a reliable mouse hit target and immediate visual feedback.
- Single click, double click, right click, dragging, and wheel scrolling behave consistently across applications.
- Disconnecting, reconnecting, or omitting the mouse does not block keyboard operation or crash the suite.
- Focus is always visible, and every modal dialog has a clear exit.
- Every destructive action is confirmed or has a documented recovery path.
- Unknown or newer file formats are rejected safely.
- Startup and common interactions feel responsive on real hardware.
- A long-session test can repeatedly open, edit, save, and close documents without crashing or exhausting resources.
- The release package works from a clean SD-card installation.
- User guide, shortcut reference, backup instructions, and known limitations are included.

## 9. Test Matrix

### Environments

- Current supported Commander X16 emulator
- Minimum supported ROM release
- Current supported ROM release
- Real Commander X16 hardware
- PS/2 keyboard only
- Keyboard and two-button PS/2 mouse
- Clean SD card and populated SD card

### High-risk cases

- Leap years, month/year boundaries, and midnight rollover
- Recurring events across short months
- Multiple alarms due at the same time
- Long filenames and nested directories
- Full, removed, unavailable, or write-protected storage
- Corrupt, truncated, empty, and newer-version documents
- Maximum-size text documents and card collections
- Rapid input, double clicks, held keys, and mouse movement at screen edges
- Pressing over one control and releasing over another
- Dragging outside a control, application view, or modal dialog
- Mouse disconnect/reconnect and startup without a mouse
- Wheel input over nested or non-scrollable controls
- Changing screen mode or pointer bounds while the mouse is enabled
- Printing while documents contain uncommon characters or long lines
- Reset or power interruption during a save

## 10. Primary Risks and Controls

| Risk | Control |
|---|---|
| Suite scope becomes too large | Enforce P0/P1/deferred boundaries at every milestone review. |
| UI work is duplicated per application | Require applications to use the shared UI toolkit and document lifecycle. |
| Banked memory complicates application state | Assign memory ownership early and keep persistent services small and explicit. |
| User data is corrupted during saving | Use versioned formats, validation, temporary saves, backups, and failure-injection tests. |
| Calendar edge cases create incorrect reminders | Isolate and exhaustively test date/recurrence logic before polishing views. |
| Mouse support weakens keyboard usability | Make keyboard navigation part of every control's definition of done. |
| Emulator-only assumptions slip into release | Test every milestone on real hardware whenever possible and require it for release. |
| Worksheet delays the organizer | Keep it P1 until all P0 integration and quality gates pass. |

## 11. Decisions to Lock During M0

- Programming language and toolchain — **Prog8 12.3.2 plus 64tass 1.60.3243**
- Minimum X16 ROM version — **r49 for the alpha; review before file-format freeze**
- Default screen mode and resolution — **320x240, 256-color VERA bitmap**
- Text encoding and newline convention
- Native filename extensions
- Printer protocols supported in V1
- Maximum clipboard, document, card-file, and calendar sizes
- Memory-bank allocation strategy
- Whether alarms operate only while DESK COMMANDER is running
- Distribution format and license

## 12. Post-V1 Direction

After V1 is stable, prioritize additions according to real usage rather than historical completeness. The likely progression is:

1. Worksheet and stronger printing
2. Calendar/contact integration and labels
3. Paint/Draw
4. Home Organizer modules built on Cards and Worksheet
5. Telecommunications and network features
6. Third-party application and file-format documentation

V1 succeeds when DESK COMMANDER becomes a pleasant place to start the Commander X16 and a trustworthy place to keep everyday information.
