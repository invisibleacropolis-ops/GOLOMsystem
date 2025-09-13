#!/usr/bin/env bash
set -euo pipefail

# If running on Windows with PowerShell available, delegate to the
# Windows editor wrapper for a proper GUI session.
if command -v powershell.exe >/dev/null 2>&1; then
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(dirname "$0")/open_editor.ps1" "$@"
  exit $?
fi

"$(dirname "$0")/scripts/open_editor.sh" "$@"
