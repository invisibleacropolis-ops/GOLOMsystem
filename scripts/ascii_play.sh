#!/usr/bin/env bash
set -euo pipefail

EXTRA=()
if [ "${PIPE:-0}" = "1" ]; then
  EXTRA=(-- --pipe)
fi

godot4 --headless --path . --script scripts/tools/ascii_console.gd "${EXTRA[@]}"

