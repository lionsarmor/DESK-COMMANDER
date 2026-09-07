# DESK COMMANDER build commands
#
# Most people only need:
#
#     ./run.sh
#
# The longer commands remain here so the build is transparent and easy to
# change later.

# Keep Make's dependency paths relative. The project directory contains a
# space, and absolute paths with spaces are awkward dependency names in Make.
PROJECT_ROOT := $(CURDIR)
TOOLS_DIR    := .tools
BUILD_DIR    := build
SOURCE_DIR   := src
SDCARD_DIR   := dist/sdcard

JAVA         := $(TOOLS_DIR)/jre/bin/java
PROG8_JAR    := $(TOOLS_DIR)/prog8/prog8c-12.3.2-all.jar
ASSEMBLER    := $(TOOLS_DIR)/bin/64tass
EMULATOR     := $(TOOLS_DIR)/x16emu/x16emu
ROM          := $(TOOLS_DIR)/x16emu/rom.bin
PROGRAM      := $(BUILD_DIR)/main.prg
FILE_MANAGER := ZZFILEMAN.BIN
FILE_OPERATIONS := ZZFILEOPS.BIN
TEXT_EDITOR  := ZZEDITOR.BIN
PROGRAM_LAUNCHER := ZZLAUNCH.BIN
NETWORK_APP  := ZZNETWORK.BIN
NETWORK_PICKER := ZZNETPK.BIN
MARKET_APP   := ZZMARKET.BIN
MARKET_NETWORK := ZZMARKETNET.BIN
STATE_STORE   := ZZSTATE.BIN
NOTES_APP     := ZZNOTES.BIN
COMMS_APP     := ZZCOMMS.BIN
CHAT_NETWORK  := ZZCHATNET.BIN
COMMS_VISUAL  := ZZCHATUI.BIN

# Bank map for the loadable files above:
#   4 Files, 5 file operations, 6 editor, 7 network, 8 market UI,
#   9 market network worker, 10 persistence, 11 Notes, 12 Comms,
#   13 scrollable Wi-Fi picker, 14 external PRG launcher.
# The filenames use 8.3-safe names so the same build works with HostFS and SD.
# Keep each loadable bank tied only to the source it actually compiles. The
# old all-sources dependency made one Comms edit rebuild fourteen unrelated
# programs, which looked like deskbuild was looping on a slower machine.
STATE_DEPS   := $(SOURCE_DIR)/state_data.p8
THEME_DEPS   := $(SOURCE_DIR)/theme.p8 $(STATE_DEPS)
INPUT_DEPS   := $(SOURCE_DIR)/input.p8 $(SOURCE_DIR)/preferences.p8 $(THEME_DEPS)
CORE_DEPS    := $(SOURCE_DIR)/main.p8 $(SOURCE_DIR)/desktop.p8 $(SOURCE_DIR)/splash.p8 \
	$(SOURCE_DIR)/font5x7.p8 $(SOURCE_DIR)/calendar_app.p8 $(SOURCE_DIR)/market_data.p8 \
	$(SOURCE_DIR)/rolodex_app.p8 $(SOURCE_DIR)/appmeta.p8 $(INPUT_DEPS)
FILE_DEPS    := $(SOURCE_DIR)/app_mailbox.p8 $(INPUT_DEPS)
NET_DEPS     := $(SOURCE_DIR)/network_driver.p8 $(SOURCE_DIR)/network_mailbox.p8

.PHONY: all run check sdcard clean setup

all: $(PROGRAM) $(FILE_MANAGER) $(FILE_OPERATIONS) $(TEXT_EDITOR) $(PROGRAM_LAUNCHER) \
	$(NETWORK_APP) $(NETWORK_PICKER) $(MARKET_APP) $(MARKET_NETWORK) $(STATE_STORE) \
	$(NOTES_APP) $(COMMS_APP) $(CHAT_NETWORK) $(COMMS_VISUAL)

setup:
	./tools/setup-toolchain.sh

$(PROGRAM): $(CORE_DEPS) | $(BUILD_DIR)
	@echo "Building DESK COMMANDER..."
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-varsgolden \
		-srcdirs "$(SOURCE_DIR)" \
		-out "$(BUILD_DIR)" \
		-asmlist \
		"$(SOURCE_DIR)/main.p8"

$(FILE_MANAGER): $(SOURCE_DIR)/file_manager_overlay.p8 $(SOURCE_DIR)/file_manager.p8 $(FILE_DEPS) | $(BUILD_DIR)
	@echo "Building FILE MANAGER overlay..."
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-out "$(BUILD_DIR)" \
		-asmlist \
		"$(SOURCE_DIR)/file_manager_overlay.p8"
	@cp "$(BUILD_DIR)/file_manager_overlay.bin" "$(FILE_MANAGER)"

$(FILE_OPERATIONS): $(SOURCE_DIR)/file_ops_overlay.p8 $(SOURCE_DIR)/file_ops.p8 $(FILE_DEPS) | $(BUILD_DIR)
	@echo "Building FILE OPERATIONS overlay..."
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-out "$(BUILD_DIR)" \
		-asmlist \
		"$(SOURCE_DIR)/file_ops_overlay.p8"
	@cp "$(BUILD_DIR)/file_ops_overlay.bin" "$(FILE_OPERATIONS)"

$(TEXT_EDITOR): $(SOURCE_DIR)/text_editor_overlay.p8 $(SOURCE_DIR)/text_editor.p8 $(FILE_DEPS) | $(BUILD_DIR)
	@echo "Building TEXT EDITOR ++ overlay..."
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-out "$(BUILD_DIR)" \
		-asmlist \
		"$(SOURCE_DIR)/text_editor_overlay.p8"
	@cp "$(BUILD_DIR)/text_editor_overlay.bin" "$(TEXT_EDITOR)"

$(PROGRAM_LAUNCHER): $(SOURCE_DIR)/program_launcher_overlay.p8 $(SOURCE_DIR)/program_launcher.p8 $(FILE_DEPS) | $(BUILD_DIR)
	@echo "Building EXTERNAL PRG LAUNCHER overlay..."
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-out "$(BUILD_DIR)" \
		-asmlist \
		"$(SOURCE_DIR)/program_launcher_overlay.p8"
	@cp "$(BUILD_DIR)/program_launcher_overlay.bin" "$(PROGRAM_LAUNCHER)"

$(NETWORK_APP): $(SOURCE_DIR)/network_overlay.p8 $(SOURCE_DIR)/network_app.p8 $(NET_DEPS) $(INPUT_DEPS) | $(BUILD_DIR)
	@echo "Building TEXELEC NETWORK overlay..."
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-out "$(BUILD_DIR)" \
		-asmlist \
		"$(SOURCE_DIR)/network_overlay.p8"
	@cp "$(BUILD_DIR)/network_overlay.bin" "$(NETWORK_APP)"

$(NETWORK_PICKER): $(SOURCE_DIR)/network_picker_overlay.p8 $(SOURCE_DIR)/network_picker.p8 $(SOURCE_DIR)/network_mailbox.p8 $(THEME_DEPS) | $(BUILD_DIR)
	@echo "Building WIFI NETWORK PICKER overlay..."
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-out "$(BUILD_DIR)" \
		-asmlist \
		"$(SOURCE_DIR)/network_picker_overlay.p8"
	@cp "$(BUILD_DIR)/network_picker_overlay.bin" "$(NETWORK_PICKER)"

$(MARKET_APP): $(SOURCE_DIR)/market_overlay.p8 $(SOURCE_DIR)/market_app.p8 $(SOURCE_DIR)/market_data.p8 $(INPUT_DEPS) | $(BUILD_DIR)
	@echo "Building MARKET WATCH overlay..."
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-out "$(BUILD_DIR)" \
		-asmlist \
		"$(SOURCE_DIR)/market_overlay.p8"
	@cp "$(BUILD_DIR)/market_overlay.bin" "$(MARKET_APP)"

$(MARKET_NETWORK): $(SOURCE_DIR)/market_fetch_overlay.p8 $(SOURCE_DIR)/market_fetch.p8 $(SOURCE_DIR)/market_data.p8 $(NET_DEPS) $(STATE_DEPS) | $(BUILD_DIR)
	@echo "Building MARKET NETWORK service..."
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-out "$(BUILD_DIR)" \
		-asmlist \
		"$(SOURCE_DIR)/market_fetch_overlay.p8"
	@cp "$(BUILD_DIR)/market_fetch_overlay.bin" "$(MARKET_NETWORK)"

$(STATE_STORE): $(SOURCE_DIR)/state_overlay.p8 $(SOURCE_DIR)/state_store.p8 $(STATE_DEPS) | $(BUILD_DIR)
	@echo "Building PERSISTENT STATE service..."
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-out "$(BUILD_DIR)" \
		-asmlist \
		"$(SOURCE_DIR)/state_overlay.p8"
	@cp "$(BUILD_DIR)/state_overlay.bin" "$(STATE_STORE)"

$(NOTES_APP): $(SOURCE_DIR)/notes_overlay.p8 $(SOURCE_DIR)/notes_app.p8 $(INPUT_DEPS) | $(BUILD_DIR)
	@echo "Building NOTES overlay..."
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-out "$(BUILD_DIR)" \
		-asmlist \
		"$(SOURCE_DIR)/notes_overlay.p8"
	@cp "$(BUILD_DIR)/notes_overlay.bin" "$(NOTES_APP)"

$(COMMS_APP): $(SOURCE_DIR)/comms_overlay.p8 $(SOURCE_DIR)/comms_app.p8 $(SOURCE_DIR)/comms_data.p8 $(INPUT_DEPS) | $(BUILD_DIR)
	@echo "Building COMMS overlay..."
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-out "$(BUILD_DIR)" \
		-asmlist \
		"$(SOURCE_DIR)/comms_overlay.p8"
	@cp "$(BUILD_DIR)/comms_overlay.bin" "$(COMMS_APP)"

$(CHAT_NETWORK): $(SOURCE_DIR)/chat_network_overlay.p8 $(SOURCE_DIR)/chat_network.p8 $(SOURCE_DIR)/comms_data.p8 $(NET_DEPS) $(STATE_DEPS) | $(BUILD_DIR)
	@echo "Building COMMS NETWORK service..."
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-out "$(BUILD_DIR)" \
		-asmlist \
		"$(SOURCE_DIR)/chat_network_overlay.p8"
	@cp "$(BUILD_DIR)/chat_network_overlay.bin" "$(CHAT_NETWORK)"

$(COMMS_VISUAL): $(SOURCE_DIR)/comms_visual_overlay.p8 $(SOURCE_DIR)/comms_visual.p8 $(SOURCE_DIR)/comms_data.p8 $(THEME_DEPS) | $(BUILD_DIR)
	@echo "Building COMMS VISUAL service..."
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-out "$(BUILD_DIR)" \
		-asmlist \
		"$(SOURCE_DIR)/comms_visual_overlay.p8"
	@cp "$(BUILD_DIR)/comms_visual_overlay.bin" "$(COMMS_VISUAL)"

$(BUILD_DIR):
	mkdir -p "$(BUILD_DIR)"

check:
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-varsgolden \
		-srcdirs "$(SOURCE_DIR)" \
		-check \
		"$(SOURCE_DIR)/main.p8"
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-check \
		"$(SOURCE_DIR)/file_manager_overlay.p8"
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-check \
		"$(SOURCE_DIR)/file_ops_overlay.p8"
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-check \
		"$(SOURCE_DIR)/text_editor_overlay.p8"
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-check \
		"$(SOURCE_DIR)/program_launcher_overlay.p8"
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-check \
		"$(SOURCE_DIR)/network_overlay.p8"
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-check \
		"$(SOURCE_DIR)/network_picker_overlay.p8"
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-check \
		"$(SOURCE_DIR)/market_overlay.p8"
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-check \
		"$(SOURCE_DIR)/market_fetch_overlay.p8"
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-check \
		"$(SOURCE_DIR)/state_overlay.p8"
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-check \
		"$(SOURCE_DIR)/notes_overlay.p8"
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-check \
		"$(SOURCE_DIR)/comms_overlay.p8"
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-check \
		"$(SOURCE_DIR)/chat_network_overlay.p8"
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-check \
		"$(SOURCE_DIR)/comms_visual_overlay.p8"

run: all
	@echo "Starting the Commander X16 emulator..."
	@cd "$(PROJECT_ROOT)" && \
		"$(EMULATOR)" \
		-rom "$(ROM)" \
		-fsroot . \
		-prg "$(PROGRAM)" \
		-run \
		-rtc \
		-scale 2

# Build a physical-machine folder with only the files required at runtime.
# DCSTATE.BIN is intentionally omitted so each copied build starts clean.
sdcard: all
	@echo "Preparing Commander X16 SD-card folder..."
	@mkdir -p "$(SDCARD_DIR)"
	@rm -f "$(SDCARD_DIR)/ZZNETPICK.BIN"
	@cp "$(PROGRAM)" "$(SDCARD_DIR)/DESKCMD.PRG"
	@cp "$(FILE_MANAGER)" "$(FILE_OPERATIONS)" "$(TEXT_EDITOR)" "$(PROGRAM_LAUNCHER)" \
		"$(NETWORK_APP)" "$(NETWORK_PICKER)" "$(MARKET_APP)" "$(MARKET_NETWORK)" \
		"$(STATE_STORE)" "$(NOTES_APP)" "$(SDCARD_DIR)/"
	@cp "$(COMMS_APP)" "$(CHAT_NETWORK)" "$(COMMS_VISUAL)" "$(SDCARD_DIR)/"
	@echo "Ready: $(SDCARD_DIR)"

clean:
	@echo "Removing generated build files..."
	rm -f "$(BUILD_DIR)/main.asm" \
	      "$(BUILD_DIR)/main.list" \
	      "$(BUILD_DIR)/main.prg" \
	      "$(BUILD_DIR)/main.vice-mon-list" \
	      "$(BUILD_DIR)/file_manager_overlay.asm" \
	      "$(BUILD_DIR)/file_manager_overlay.bin" \
	      "$(BUILD_DIR)/file_manager_overlay.list" \
	      "$(BUILD_DIR)/file_manager_overlay.vice-mon-list" \
	      "$(BUILD_DIR)/file_ops_overlay.asm" \
	      "$(BUILD_DIR)/file_ops_overlay.bin" \
	      "$(BUILD_DIR)/file_ops_overlay.list" \
	      "$(BUILD_DIR)/file_ops_overlay.vice-mon-list" \
	      "$(BUILD_DIR)/text_editor_overlay.asm" \
	      "$(BUILD_DIR)/text_editor_overlay.bin" \
	      "$(BUILD_DIR)/text_editor_overlay.list" \
	      "$(BUILD_DIR)/text_editor_overlay.vice-mon-list" \
	      "$(BUILD_DIR)/program_launcher_overlay.asm" \
	      "$(BUILD_DIR)/program_launcher_overlay.bin" \
	      "$(BUILD_DIR)/program_launcher_overlay.list" \
	      "$(BUILD_DIR)/program_launcher_overlay.vice-mon-list" \
	      "$(BUILD_DIR)/network_overlay.asm" \
	      "$(BUILD_DIR)/network_overlay.bin" \
	      "$(BUILD_DIR)/network_overlay.list" \
	      "$(BUILD_DIR)/network_overlay.vice-mon-list" \
	      "$(BUILD_DIR)/network_picker_overlay.asm" \
	      "$(BUILD_DIR)/network_picker_overlay.bin" \
	      "$(BUILD_DIR)/network_picker_overlay.list" \
	      "$(BUILD_DIR)/network_picker_overlay.vice-mon-list" \
	      "$(BUILD_DIR)/market_overlay.asm" \
	      "$(BUILD_DIR)/market_overlay.bin" \
	      "$(BUILD_DIR)/market_overlay.list" \
	      "$(BUILD_DIR)/market_overlay.vice-mon-list" \
	      "$(BUILD_DIR)/market_fetch_overlay.asm" \
	      "$(BUILD_DIR)/market_fetch_overlay.bin" \
	      "$(BUILD_DIR)/market_fetch_overlay.list" \
	      "$(BUILD_DIR)/market_fetch_overlay.vice-mon-list" \
	      "$(BUILD_DIR)/state_overlay.asm" \
	      "$(BUILD_DIR)/state_overlay.bin" \
	      "$(BUILD_DIR)/state_overlay.list" \
	      "$(BUILD_DIR)/state_overlay.vice-mon-list" \
	      "$(BUILD_DIR)/notes_overlay.asm" \
	      "$(BUILD_DIR)/notes_overlay.bin" \
	      "$(BUILD_DIR)/notes_overlay.list" \
	      "$(BUILD_DIR)/notes_overlay.vice-mon-list" \
	      "$(BUILD_DIR)/comms_overlay.asm" \
	      "$(BUILD_DIR)/comms_overlay.bin" \
	      "$(BUILD_DIR)/comms_overlay.list" \
	      "$(BUILD_DIR)/comms_overlay.vice-mon-list" \
	      "$(BUILD_DIR)/chat_network_overlay.asm" \
	      "$(BUILD_DIR)/chat_network_overlay.bin" \
	      "$(BUILD_DIR)/chat_network_overlay.list" \
	      "$(BUILD_DIR)/chat_network_overlay.vice-mon-list" \
	      "$(BUILD_DIR)/comms_visual_overlay.asm" \
	      "$(BUILD_DIR)/comms_visual_overlay.bin" \
	      "$(BUILD_DIR)/comms_visual_overlay.list" \
	      "$(BUILD_DIR)/comms_visual_overlay.vice-mon-list" \
	      "$(FILE_MANAGER)" \
	      "$(FILE_OPERATIONS)" \
	      "$(TEXT_EDITOR)" \
	      "$(PROGRAM_LAUNCHER)" \
	      "$(NETWORK_APP)" \
	      "$(NETWORK_PICKER)" \
	      "$(MARKET_APP)" \
	      "$(MARKET_NETWORK)" \
	      "$(STATE_STORE)" \
	      "$(NOTES_APP)" \
	      "$(COMMS_APP)" \
	      "$(CHAT_NETWORK)" \
	      "$(COMMS_VISUAL)" \
	      "FILEMAN.BIN"
