#!/usr/bin/env bash
set -euo pipefail

# Linux/WSL runner. Configure with:
#   - env: GODOT4_LINUX_EXE=/mnt/c/.../Godot_v4.4.1-stable_mono_linux.x86_64
#   - optional env file: scripts/godot4.env
#   - optional JSON: scripts/godot4-config.json { "wsl_exe": "/mnt/..." }

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load env file if present
if [[ -f "$ROOT_DIR/godot4.env" ]]; then
  # shellcheck disable=SC1090
  source "$ROOT_DIR/godot4.env"
fi

GODOT_BIN="${GODOT4_LINUX_EXE:-}"

# Fallback: try to parse minimal JSON (no jq): grab wsl_exe value if quoted
if [[ -z "$GODOT_BIN" && -f "$ROOT_DIR/godot4-config.json" ]]; then
  GODOT_BIN=$(sed -n 's/.*"wsl_exe"\s*:\s*"\([^"]\+\)".*/\1/p' "$ROOT_DIR/godot4-config.json" | head -n1 || true)
fi

# Clear if resolved path is not executable
if [[ -n "$GODOT_BIN" && ! -x "$GODOT_BIN" ]]; then
  GODOT_BIN=""
fi

# Final fallback: attempt to resolve `godot4` from PATH if still unset
if [[ -z "$GODOT_BIN" ]]; then
  if command -v godot4 >/dev/null 2>&1; then
    GODOT_BIN=$(command -v godot4)
  fi
fi

if [[ -z "$GODOT_BIN" ]]; then
  echo "[ERROR] Configure GODOT4_LINUX_EXE, scripts/godot4-config.json (wsl_exe), or install godot4 on PATH." >&2
  exit 1
fi

exec "$GODOT_BIN" "$@"
