#!/usr/bin/env bash

# Build DESK COMMANDER and install the complete runtime onto the physical
# Commander X16 SD card. User state and personal files remain untouched. The
# one explicitly named obsolete picker binary may be removed during upgrades.

set -euo pipefail

project_dir="/home/legion/Desktop/DESK COMMANDER"
package_dir="$project_dir/dist/sdcard"
sd_mount="/media/legion/X16_SDCARD"
install_dir="$sd_mount/DESKCMD"
shortcut_file="$project_dir/build/DESKCMD.PRG"

echo "Building DESK COMMANDER..."
make -C "$project_dir" sdcard

# Refuse to copy into an ordinary local directory when the SD card is absent.
if ! mountpoint -q "$sd_mount"; then
    echo
    echo "X16 SD card is not mounted at: $sd_mount"
    echo "Insert the card, wait for X16_SDCARD to appear, then run deskbuild again."
    exit 1
fi

mkdir -p "$install_dir"

# R7 initially used a nine-character base name. Remove only that obsolete
# generated overlay now that the X16-safe ZZNETPK.BIN replacement exists.
if [[ -f "$install_dir/ZZNETPICK.BIN" ]]; then
    rm -f -- "$install_dir/ZZNETPICK.BIN"
    echo "Removed obsolete runtime file: ZZNETPICK.BIN"
fi

# Older alphas called the real program DESKCMD.PRG inside the application
# directory. It is now DCMAIN.PRG so it cannot be confused with the tiny
# root-level DESKCMD.PRG shortcut.
if [[ -f "$install_dir/DESKCMD.PRG" ]]; then
    rm -f -- "$install_dir/DESKCMD.PRG"
    echo "Removed obsolete runtime file: DESKCMD/DESKCMD.PRG"
fi

echo
echo "Installing runtime files into: $install_dir"
for source_file in "$package_dir"/*; do
    file_name="${source_file##*/}"
    cp -f -- "$source_file" "$install_dir/$file_name"
done

# Keep the actual application together in /DESKCMD and install only this tiny
# launch helper in the SD-card root.
cp -f -- "$shortcut_file" "$sd_mount/DESKCMD.PRG"

# Finish outstanding writes before the user ejects the removable card.
sync "$sd_mount"

echo
echo "Verifying installed files..."
for source_file in "$package_dir"/*; do
    file_name="${source_file##*/}"
    if ! cmp -s -- "$source_file" "$install_dir/$file_name"; then
        echo "Verification failed: $file_name"
        exit 1
    fi
    file_size=$(stat -c '%s' "$install_dir/$file_name")
    printf '  %-18s %s bytes\n' "$file_name" "$file_size"
done

if ! cmp -s -- "$shortcut_file" "$sd_mount/DESKCMD.PRG"; then
    echo "Verification failed: root DESKCMD.PRG shortcut"
    exit 1
fi
printf '  %-18s %s bytes\n' "/DESKCMD.PRG" "$(stat -c '%s' "$sd_mount/DESKCMD.PRG")"

echo
echo "Build and SD-card deployment complete."
echo "DCSTATE.BIN and user-created files were preserved."
