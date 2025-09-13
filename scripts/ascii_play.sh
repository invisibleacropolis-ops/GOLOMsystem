#!/usr/bin/env bash
set -euo pipefail

EXTRA=()
if [ "${PIPE:-0}" = "1" ]; then
  EXTRA=(-- --pipe)
fi

mkdir -p logs
ts=$(date -u +%Y%m%d_%H%M%S)
log="logs/ascii_play_linux_${ts}.log"
latest="logs/ascii_play_linux.log"

set +e
godot4 --headless --path . --script scripts/tools/ascii_console.gd "${EXTRA[@]}" 2>&1 | tee "$log" >/dev/null
code=${PIPESTATUS[0]}
set -e
cp -f "$log" "$latest" 2>/dev/null || true
exit $code
