#!/usr/bin/env bash

# Build and verify DESK COMMANDER, then create one ZIP that can be extracted
# directly into the root of a Commander X16 SD card.

set -euo pipefail

project_dir="/home/legion/Desktop/DESK COMMANDER"
runtime_dir="$project_dir/dist/sdcard"
release_dir="$project_dir/dist/release"
archive_name="DESK-COMMANDER-X16.zip"
archive_path="$release_dir/$archive_name"
work_dir="$(mktemp -d)"
stage_dir="$work_dir/package"

cleanup() {
    rm -rf -- "$work_dir"
}
trap cleanup EXIT

echo "Checking every DESK COMMANDER target..."
make -C "$project_dir" check

echo
echo "Building the X16 runtime package..."
make -C "$project_dir" sdcard

mkdir -p "$stage_dir/DESKCMD" "$release_dir"

# Keep every runtime module beside the main PRG. Never distribute a developer's
# DCSTATE.BIN; a new user must receive a clean, private first-run state.
for source_file in "$runtime_dir"/*; do
    file_name="${source_file##*/}"
    if [[ "$file_name" != "DCSTATE.BIN" ]]; then
        cp -f -- "$source_file" "$stage_dir/DESKCMD/$file_name"
    fi
done

(
    cd "$stage_dir"
    zip -q -r "$work_dir/$archive_name" DESKCMD
)

# Replace only this explicitly named generated release archive.
mv -f -- "$work_dir/$archive_name" "$archive_path"

echo
echo "Release package ready:"
echo "  $archive_path"
echo
echo "Install by extracting the ZIP into the SD-card root."
echo "The result is one self-contained /DESKCMD directory."
echo "SHA-256: $(sha256sum "$archive_path" | cut -d ' ' -f 1)"
