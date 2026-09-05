#!/usr/bin/env bash

# Build DESK COMMANDER and launch it in the Commander X16 emulator.
#
# On the first run, this downloads a project-local copy of the pinned tools.
# Nothing is installed system-wide.

set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_marker="$project_root/.tools/READY"

if [[ ! -f "$tool_marker" ]]; then
    echo "DESK COMMANDER toolchain is not installed yet."
    echo "Running the one-time project setup..."
    "$project_root/tools/setup-toolchain.sh"
fi

make -C "$project_root" run

