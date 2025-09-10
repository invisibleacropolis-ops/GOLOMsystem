#!/usr/bin/env bash
# Headless helper to run generate_meshlib.gd.
# Pass --quiet to suppress output.
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."
QUIET=0
if [[ "$1" == "--quiet" ]]; then
  QUIET=1
  shift
fi
if [[ $QUIET -eq 1 ]]; then
  godot4 --headless --editor --quit --path . --script res://tools/generate_meshlib.gd "$@" >/dev/null
else
  godot4 --headless --editor --quit --path . --script res://tools/generate_meshlib.gd "$@"
fi
