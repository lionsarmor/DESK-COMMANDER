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

JAVA         := $(TOOLS_DIR)/jre/bin/java
PROG8_JAR    := $(TOOLS_DIR)/prog8/prog8c-12.3.2-all.jar
ASSEMBLER    := $(TOOLS_DIR)/bin/64tass
EMULATOR     := $(TOOLS_DIR)/x16emu/x16emu
ROM          := $(TOOLS_DIR)/x16emu/rom.bin
PROGRAM      := $(BUILD_DIR)/main.prg

SOURCES      := $(wildcard $(SOURCE_DIR)/*.p8)

.PHONY: all run check clean setup

all: $(PROGRAM)

setup:
	./tools/setup-toolchain.sh

$(PROGRAM): $(SOURCES) | $(BUILD_DIR)
	@echo "Building DESK COMMANDER..."
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-out "$(BUILD_DIR)" \
		-asmlist \
		"$(SOURCE_DIR)/main.p8"

$(BUILD_DIR):
	mkdir -p "$(BUILD_DIR)"

check:
	@PATH="$(TOOLS_DIR)/bin:$$PATH" \
		"$(JAVA)" -jar "$(PROG8_JAR)" \
		-target cx16 \
		-srcdirs "$(SOURCE_DIR)" \
		-check \
		"$(SOURCE_DIR)/main.p8"

run: $(PROGRAM)
	@echo "Starting the Commander X16 emulator..."
	@cd "$(PROJECT_ROOT)" && \
		"$(PROJECT_ROOT)/$(EMULATOR)" \
		-rom "$(PROJECT_ROOT)/$(ROM)" \
		-fsroot "$(PROJECT_ROOT)" \
		-prg "$(PROJECT_ROOT)/$(PROGRAM)" \
		-run \
		-rtc \
		-scale 2

clean:
	@echo "Removing generated build files..."
	rm -f "$(BUILD_DIR)/main.asm" \
	      "$(BUILD_DIR)/main.list" \
	      "$(BUILD_DIR)/main.prg" \
	      "$(BUILD_DIR)/main.vice-mon-list"
