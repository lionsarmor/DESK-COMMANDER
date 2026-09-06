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
NETWORK_APP  := ZZNETWORK.BIN
MARKET_APP   := ZZMARKET.BIN
MARKET_NETWORK := ZZMARKETNET.BIN
STATE_STORE   := ZZSTATE.BIN
NOTES_APP     := ZZNOTES.BIN
COMMS_APP     := ZZCOMMS.BIN

# Bank map for the loadable files above:
#   4 Files, 5 file operations, 6 editor, 7 network, 8 market UI,
#   9 market network worker, 10 persistence, 11 Notes, 12 Comms.
# The filenames use 8.3-safe names so the same build works with HostFS and SD.
SOURCES      := $(wildcard $(SOURCE_DIR)/*.p8)

.PHONY: all run check sdcard clean setup

all: $(PROGRAM) $(FILE_MANAGER) $(FILE_OPERATIONS) $(TEXT_EDITOR) \
	$(NETWORK_APP) $(MARKET_APP) $(MARKET_NETWORK) $(STATE_STORE) \
	$(NOTES_APP) $(COMMS_APP)

setup:
	./tools/setup-toolchain.sh

$(PROGRAM): $(SOURCES) | $(BUILD_DIR)
	@echo "Building DESK COMMANDER..."
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-varsgolden \
		-srcdirs "$(SOURCE_DIR)" \
		-out "$(BUILD_DIR)" \
		-asmlist \
		"$(SOURCE_DIR)/main.p8"

$(FILE_MANAGER): $(SOURCES) | $(BUILD_DIR)
	@echo "Building FILE MANAGER overlay..."
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-out "$(BUILD_DIR)" \
		-asmlist \
		"$(SOURCE_DIR)/file_manager_overlay.p8"
	@cp "$(BUILD_DIR)/file_manager_overlay.bin" "$(FILE_MANAGER)"

$(FILE_OPERATIONS): $(SOURCES) | $(BUILD_DIR)
	@echo "Building FILE OPERATIONS overlay..."
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-out "$(BUILD_DIR)" \
		-asmlist \
		"$(SOURCE_DIR)/file_ops_overlay.p8"
	@cp "$(BUILD_DIR)/file_ops_overlay.bin" "$(FILE_OPERATIONS)"

$(TEXT_EDITOR): $(SOURCES) | $(BUILD_DIR)
	@echo "Building TEXT EDITOR ++ overlay..."
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-out "$(BUILD_DIR)" \
		-asmlist \
		"$(SOURCE_DIR)/text_editor_overlay.p8"
	@cp "$(BUILD_DIR)/text_editor_overlay.bin" "$(TEXT_EDITOR)"

$(NETWORK_APP): $(SOURCES) | $(BUILD_DIR)
	@echo "Building TEXELEC NETWORK overlay..."
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-out "$(BUILD_DIR)" \
		-asmlist \
		"$(SOURCE_DIR)/network_overlay.p8"
	@cp "$(BUILD_DIR)/network_overlay.bin" "$(NETWORK_APP)"

$(MARKET_APP): $(SOURCES) | $(BUILD_DIR)
	@echo "Building MARKET WATCH overlay..."
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-out "$(BUILD_DIR)" \
		-asmlist \
		"$(SOURCE_DIR)/market_overlay.p8"
	@cp "$(BUILD_DIR)/market_overlay.bin" "$(MARKET_APP)"

$(MARKET_NETWORK): $(SOURCES) | $(BUILD_DIR)
	@echo "Building MARKET NETWORK service..."
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-out "$(BUILD_DIR)" \
		-asmlist \
		"$(SOURCE_DIR)/market_fetch_overlay.p8"
	@cp "$(BUILD_DIR)/market_fetch_overlay.bin" "$(MARKET_NETWORK)"

$(STATE_STORE): $(SOURCES) | $(BUILD_DIR)
	@echo "Building PERSISTENT STATE service..."
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-out "$(BUILD_DIR)" \
		-asmlist \
		"$(SOURCE_DIR)/state_overlay.p8"
	@cp "$(BUILD_DIR)/state_overlay.bin" "$(STATE_STORE)"

$(NOTES_APP): $(SOURCES) | $(BUILD_DIR)
	@echo "Building NOTES overlay..."
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-out "$(BUILD_DIR)" \
		-asmlist \
		"$(SOURCE_DIR)/notes_overlay.p8"
	@cp "$(BUILD_DIR)/notes_overlay.bin" "$(NOTES_APP)"

$(COMMS_APP): $(SOURCES) | $(BUILD_DIR)
	@echo "Building COMMS overlay..."
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-out "$(BUILD_DIR)" \
		-asmlist \
		"$(SOURCE_DIR)/comms_overlay.p8"
	@cp "$(BUILD_DIR)/comms_overlay.bin" "$(COMMS_APP)"

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
		"$(SOURCE_DIR)/network_overlay.p8"
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
	@cp "$(PROGRAM)" "$(SDCARD_DIR)/DESKCMD.PRG"
	@cp "$(FILE_MANAGER)" "$(FILE_OPERATIONS)" "$(TEXT_EDITOR)" \
		"$(NETWORK_APP)" "$(MARKET_APP)" "$(MARKET_NETWORK)" \
		"$(STATE_STORE)" "$(NOTES_APP)" "$(SDCARD_DIR)/"
	@cp "$(COMMS_APP)" "$(SDCARD_DIR)/"
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
	      "$(BUILD_DIR)/network_overlay.asm" \
	      "$(BUILD_DIR)/network_overlay.bin" \
	      "$(BUILD_DIR)/network_overlay.list" \
	      "$(BUILD_DIR)/network_overlay.vice-mon-list" \
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
	      "$(FILE_MANAGER)" \
	      "$(FILE_OPERATIONS)" \
	      "$(TEXT_EDITOR)" \
	      "$(NETWORK_APP)" \
	      "$(MARKET_APP)" \
	      "$(MARKET_NETWORK)" \
	      "$(STATE_STORE)" \
	      "$(NOTES_APP)" \
	      "$(COMMS_APP)" \
	      "FILEMAN.BIN"
