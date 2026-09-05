#!/usr/bin/env bash

# Download a reproducible, project-local Commander X16 development toolchain.
#
# Pinned versions:
#   Prog8 compiler:       12.3.2
#   64tass assembler:     1.60.3243
#   Commander X16 emu:    r49, Linux x86_64
#   Java runtime:         Eclipse Temurin 21
#
# The downloaded files live under .tools/, which is ignored by Git.
# This script does not use sudo and does not modify the rest of the system.

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tools_root="$project_root/.tools"
downloads="$tools_root/downloads"

prog8_version="12.3.2"
tass_version="1.60.3243"
emulator_version="r49"

prog8_url="https://github.com/irmen/prog8/releases/download/v${prog8_version}/prog8c-${prog8_version}-all.jar"
tass_url="https://sourceforge.net/projects/tass64/files/source/64tass-${tass_version}-src.zip/download"
emulator_url="https://github.com/X16Community/x16-emulator/releases/download/${emulator_version}/x16emu_linux-x86_64-${emulator_version}.zip"
jre_url="https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.12.1%2B1/OpenJDK21U-jre_x64_linux_hotspot_21.0.12.1_1.tar.gz"

mkdir -p "$downloads" "$tools_root/bin" "$tools_root/prog8" \
         "$tools_root/jre" "$tools_root/x16emu" "$tools_root/src"

need_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required host command: $1" >&2
        exit 1
    fi
}

download_once() {
    local url="$1"
    local destination="$2"

    if [[ ! -f "$destination" ]]; then
        echo "Downloading $(basename "$destination")..."
        curl --fail --location --show-error "$url" --output "$destination"
    fi
}

need_command curl
need_command make
need_command unzip
need_command tar
need_command cc

# Prog8 is distributed as a self-contained Java archive.
prog8_jar="$tools_root/prog8/prog8c-${prog8_version}-all.jar"
download_once "$prog8_url" "$prog8_jar"

# Use a private Java runtime so contributors do not have to alter their system.
jre_archive="$downloads/temurin-jre-21.tar.gz"
download_once "$jre_url" "$jre_archive"
if [[ ! -x "$tools_root/jre/bin/java" ]]; then
    echo "Extracting the Java runtime..."
    tar -xzf "$jre_archive" --strip-components=1 -C "$tools_root/jre"
fi

# Prog8 emits assembly and asks 64tass to turn it into a .PRG file.
tass_archive="$downloads/64tass-${tass_version}-src.zip"
tass_source="$tools_root/src/64tass-${tass_version}-src"
download_once "$tass_url" "$tass_archive"
if [[ ! -x "$tools_root/bin/64tass" ]]; then
    echo "Building the 64tass assembler..."
    unzip -q -o "$tass_archive" -d "$tools_root/src"
    make -C "$tass_source" -j2
    cp "$tass_source/64tass" "$tools_root/bin/64tass"
    chmod +x "$tools_root/bin/64tass"
fi

# The official emulator archive also contains the matching X16 ROM image.
emulator_archive="$downloads/x16emu-linux-x86_64-${emulator_version}.zip"
download_once "$emulator_url" "$emulator_archive"
if [[ ! -x "$tools_root/x16emu/x16emu" ]]; then
    echo "Extracting the Commander X16 emulator..."
    unzip -q -o "$emulator_archive" -d "$tools_root/x16emu"
    chmod +x "$tools_root/x16emu/x16emu"
fi

touch "$tools_root/READY"

echo
echo "Toolchain ready."
echo "Run DESK COMMANDER with:"
echo
echo "    ./run.sh"

