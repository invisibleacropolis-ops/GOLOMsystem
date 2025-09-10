Headless Tooling & Runner Scripts
=================================

This repo includes wrappers and helpers so you (and the assistant) can run the
Godot 4 editor/runtime headlessly for testing, docs generation, and ASCII play.

Quick Setup
-----------
- Copy `scripts/godot4-config.example.json` → `scripts/godot4-config.json` and set:
  - `win_exe`: `F:\AIstuff\FILES-FOR-MODELS\Godot_v4.4.1-stable_win64.exe`
  - `wsl_exe`: `/mnt/f/AIstuff/FILES-FOR-MODELS/Godot_v4.4.1-stable_mono_linux.x86_64`
- Optional: env vars instead of JSON
  - `GODOT4_WIN_EXE`, `GODOT4_LINUX_EXE`, `GODOT4_MODE=auto|wsl|win`
- Optional (bash/WSL): copy `scripts/godot4.env.example` → `scripts/godot4.env` and edit.

Unified Runner (`godot4`)
-------------------------
- Windows (PowerShell/cmd):
  - `pwsh -File scripts/godot4.ps1 --version`
  - `scripts\godot4.cmd --headless --path . --script scripts/test_runner.gd`
- Linux/WSL (bash): `bash scripts/godot4.sh --version`

Notes
- Mode selection comes from JSON/env by default. You can force PowerShell mode with `-Mode win` or `-Mode wsl`.
- On WSL with the Mono build, install: `.NET SDK 8+`, `libasound2`, `libpulse0`. Otherwise use `-Mode win`.

Headless Flows
--------------
- Doctool XMLs: `pwsh -File scripts/doc_regen.ps1` or `bash scripts/doc_regen.sh`
- Tests + ASCII smoke (writes logs): `pwsh -File scripts/run_headless.ps1 -Strict`
- ASCII play:
  - Interactive: `pwsh -File scripts/ascii_play.ps1`
  - Piped (non-interactive):
    - Prepare commands in `logs/ascii_commands.txt` (see `scripts/run_headless.ps1` for an example)
    - Run: `pwsh -File scripts/ascii_play.ps1 -Pipe` or `PIPE=1 bash scripts/ascii_play.sh < logs/ascii_commands.txt`

Direct EXE Examples (for troubleshooting)
----------------------------------------
- `F:\AIstuff\FILES-FOR-MODELS\Godot_v4.4.1-stable_win64.exe --headless --path . --doctool docs/api --gdscript-docs res://scripts/modules`
- `F:\AIstuff\FILES-FOR-MODELS\Godot_v4.4.1-stable_win64.exe --headless --path . --script scripts/test_runner.gd`
- `F:\AIstuff\FILES-FOR-MODELS\Godot_v4.4.1-stable_win64.exe --headless --path . --script scripts/tools/ascii_console.gd`

Logs live under `logs/`.
