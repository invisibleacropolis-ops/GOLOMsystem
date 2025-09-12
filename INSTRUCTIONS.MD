INSTRUCTIONS — Godot 4.4.1 Runners, Headless Tooling, and ASCII Interface (AI‑Ops Manual)

Agent First-Step
- Before doing anything, read docs/OPERATIONS.md. It defines how this repo expects an AI agent to operate: the agent must use the wrappers under scripts/ to launch Godot (editor/headless), capture logs, and report results — do not hand instructions back to the human instead of acting.

Standard Operating Procedure (Windows, Full GUI)
- Launch the editor using: `pwsh -File open_editor.ps1`
- Leave the editor open for interactive testing. Do not auto-close; only close when explicitly instructed.
- Logs are written to:
  - `logs/editor_launch_win_YYYYMMDD_HHMMSS.log`
  - `logs/editor_launch_win.log`
  - `logs/editor_launch_win_status.json` (helpful for run metadata).
- Quick launches:
  - Linux/WSL: scripts/open_editor.sh (opens full editor)
  - Windows: scripts/open_editor.ps1 or scripts/open_editor.cmd (opens full editor)
  - Headless tests: scripts/run_headless.sh or pwsh -File scripts/run_headless.ps1 -Strict
 - See also: docs/INTERNAL_DEBUGGER.md for the in‑game logger/overlay.

Overview
This repository includes a set of scripts and wrappers designed to make running Godot 4.4.1 reliable from both interactive desktops and non‑interactive, headless environments. They exist primarily so an AI agent (like me) can:
- Launch the project with a known Godot version across Windows and WSL/Linux.
- Run headless tests for fast validation and CI.
- Drive a text‑mode ASCII interface to “see” and interact with the game loop entirely via the terminal (no graphics window required).

The tooling is intentionally redundant across PowerShell, CMD, and Bash so it works in multiple shells with minimal friction and clear fallbacks.

Important: Use PowerShell for all runs on Windows
- Always prefer the PowerShell wrappers on Windows for both normal and headless testing. Examples:
  - Normal run (editor):
    - pwsh -File scripts/godot4.ps1 --path . --editor
  - Normal run (play project):
    - pwsh -File scripts/godot4.ps1 --path .
  - Headless tests (diagnostics/CI):
    - pwsh -File scripts/run_headless.ps1 -Strict
- These flows use the configured Windows Godot 4.4.1 executable from scripts/godot4-config.json and avoid Mono/.NET dependencies.

Primary Testing Workflow (preferred now)
- Run the game in NORMAL mode using the Windows Godot executable and test via the built‑in ASCII engine.
  - Launch the editor: pwsh -File scripts/godot4.ps1 --path .
  - Open and run the slice scene: load res://scenes/VerticalSlice.tscn and press F5 (Play), or run the project’s Main scene.
  - Interact using the ASCII layer:
    - AsciiKeybinds is enabled (see autoloads). Keys: WASD (move), Enter (select), T (target), Space (click), C (clear).
    - ASCII output can be observed live by selecting the GridRealtimeRenderer node in the Remote SceneTree and setting `ascii_stream_enabled = true` (frames print to the Output panel). The ASCII overlay also mirrors grid state in‑window.
- Rationale: This provides live display and live inputs directly within the running game. Use this for primary gameplay testing and iteration.

Secondary Workflow (Windows headless tests)
- For diagnostic checks or CI, use the PowerShell runner with the Windows exe:
  - pwsh -File scripts/run_headless.ps1 -Strict
- This avoids Mono/.NET dependencies and quickly validates backend modules.

Quick Start: Vertical Slice (Normal Run)
- Prereqs
  - Godot 4.4.1 installed (Windows). Ensure scripts/godot4-config.json "win_exe" points to your Godot exe.
  - Project opens with run/main_scene = res://scenes/Root.tscn; for the slice, we’ll open its scene directly.

- Launch editor
  - pwsh -File scripts/godot4.ps1 --path .
  - In the editor, open res://scenes/VerticalSlice.tscn.

- Run the slice
  - Press F5 (Play). The scene assembles:
    - RuntimeServices (logic aggregation)
    - GridRealtimeRenderer (overlay + ASCII support)
    - GridInteractor (mouse input)
    - MainHUD (End Turn)
    - AbilityHotbar (attack_basic, overwatch)

- Controls & flow
  - Turn order auto-selects the current actor.
  - Movement: Click blue tiles (AP-limited reach) to move along the computed path.
  - Attack: Click attack_basic on the hotbar to enter attack mode; red tiles are valid LOS targets. Click a target to attack (exits attack mode).
  - Overwatch: Click overwatch on the hotbar to register a reaction shot (shows “OW” label). End your turn to let enemies act.
  - End Turn: Use the MainHUD button.

- ASCII live view & input parity
  - In the Remote SceneTree (Debugger → Remote), select GridRealtimeRenderer and set ascii_stream_enabled = true to print ASCII frames to the Output panel.
  - AsciiKeybinds autoload provides hotkeys: WASD (move), Enter (select), T (target), Space (click), C (clear). GUI input and ASCII semantics match.

- What to expect
  - Small procedural map with terrain, LOS blockers, and cover visuals (outlined tiles with H/F labels).
  - Two-player squad vs two enemies; basic enemy AI moves toward or attacks in LOS.
  - Damage previews (labels) on valid targets during attack mode.

- Troubleshooting (normal mode)
  - Godot version mismatch: Ensure 4.4.1 and config/features in project.godot include "4.4".
  - Missing scene parts: Confirm VerticalSlice.tscn includes Runtime, GridRealtimeRenderer, GridInteractor, MainHUD, AbilityHotbar; BattleController properties are set (services_path, renderer_path, interactor_path, hotbar_path).
  - No ASCII output: Toggle ascii_stream_enabled on GridRealtimeRenderer; or verify AsciiGateway autoload is active in project.godot.

Attach to a Live ASCII Stream (Normal Run)
- Server: An autoload (AsciiStreamServer) is enabled and listens on 127.0.0.1:3456 by default.
  - Config (optional): ProjectSettings → ascii_stream/port (int), ascii_stream/frame_interval (float), ascii_stream/localhost_only (bool).
- Client (PowerShell):
  - pwsh -File scripts/ascii_stream_client.ps1 -Host 127.0.0.1 -Port 3456
  - Type commands (e.g., end_turn, select 5 4, move 6 4). Frames stream continuously.
- Client (Bash):
  - scripts/ascii_stream_client.sh 127.0.0.1 3456
- Command set (mirrors ascii_console):
  - spawn NAME X Y | move_actor NAME X Y | action NAME ID [X Y] | remove NAME | end_turn | list
  - select X Y | move X Y | target X Y | click X Y | clear | quit

Files at a Glance (all live under the scripts/ folder)
- scripts/godot4.ps1 — Primary, cross‑platform runner (Windows/WSL) with smart mode selection.
- scripts/godot4.cmd — Thin batch shim that forwards to PowerShell.
 - scripts/godot4.sh — Lightweight Bash/WSL runner; supports env file + JSON config and detects `godot4` on PATH.
- scripts/godot4-config.json — Central config for Godot 4 paths and default mode.
- scripts/godot4-config.example.json — Copyable example config.
- scripts/godot4.env.example — Example environment variables for Bash/WSL usage.
- scripts/run_headless.ps1 — Headless module tests + ASCII smoke on Windows/PowerShell.
- scripts/run_headless.sh — Headless module tests + ASCII smoke in Bash/WSL.
- scripts/ascii_play.ps1 — Start the ASCII console from PowerShell.
- scripts/ascii_play.sh — Start the ASCII console from Bash.
- scripts/test_runner.gd — Godot SceneTree script that discovers and runs module tests.
- scripts/tools/ascii_console.gd — Headless ASCII console: snapshot view + command parser.
- scripts/doc_regen.ps1 / scripts/doc_regen.sh — Generate API XML docs via Godot doctool; optional RST/HTML conversions.

Project prerequisites and integration points
- project.godot advertises 4.4 features: config/features = ["4.4", "Forward Plus"]. Use Godot 4.4.1 to avoid editor/runtime mismatches.
- Autoloads (project.godot) include:
  - WorkspaceDebugger — logs workspace output to user://workspace_errors.log.
  - AsciiGateway — live bridge for the ASCII tools to interact with RuntimeServices and GridRealtimeRenderer.
  - AsciiKeybinds — optional hotkeys (WASD and action keys) for ASCII control.

Configuration

1) JSON (primary)
- Location: scripts/godot4-config.json
- Shape:
  {
    "mode": "auto|wsl|win",
    "win_exe": "F:\\Path\\To\\Godot_v4.4.1-stable_win64.exe",
    "wsl_exe": "/mnt/f/Path/To/Godot_v4.4.1-stable_mono_linux.x86_64"
  }
- This file is read by both PowerShell and Bash runners. It centralizes the exact Godot 4.4.1 binaries to use.

2) Environment variables (overrides)
- GODOT4_MODE — default run mode (auto, wsl, win).
- GODOT4_WIN_EXE — path to Windows Godot 4.4.1 exe.
- GODOT4_LINUX_EXE — path to Linux Godot 4.4.1 binary (typically WSL-visible path).

3) CLI overrides (highest priority in PowerShell)
- -Mode / --mode — force mode (wsl or win or auto).
- -WinExe / --win — supply Windows exe path directly.
- -WslExe / --wsl — supply Linux binary path directly.

Why these scripts exist (the “why”)
- Deterministic versioning: They lock runs to 4.4.1 so editor/headless behaviors match CI and dev machines.
- Headless runs: Tests and ASCII gameplay work without any GUI or GPU (good for servers/containers/CI and AI agents).
- Cross‑environment ergonomics: Seamlessly prefer WSL Linux runs when available, but fall back to native Windows.
- Reproducible logs: All helpers write to logs/ with consistent exit codes so automation can assert pass/fail.
- Low ceremony: One command works everywhere (pwsh, cmd, bash) with minimal or no manual path tinkering.

Primary Runner (PowerShell): scripts/godot4.ps1

Purpose
- Provide a single entry point that can launch either the WSL/Linux binary or the Windows .exe, with predictable precedence and robust error messages.

How it parses arguments
- The script declares param([string[]]$AllArgs) to avoid positional binding.
- It scans $AllArgs for three options:
  - -Mode / --mode — string value: auto (default), wsl, win.
  - -WinExe / --win — path to the Windows Godot exe.
  - -WslExe / --wsl — path to the Linux Godot binary.
- All other arguments are passed through verbatim to the actual Godot process ($ArgsPassthrough). This is critical so flags like --headless, --path, --script, scenes, or custom -- parameters are forwarded unchanged.

Config resolution
- Read-JsonConfig() loads scripts/godot4-config.json if present.
- Precedence (high → low): CLI → JSON → environment variables → defaults (none; error if unresolved).
- If $Mode is not set after resolution, it defaults to auto.

WSL helpers
- Test-WSLAvailable: returns true when the wsl command is found.
- Resolve-WslPath(p): converts a Windows path to a WSL path using wsl wslpath -a, unless already a Unix/WSL path (/ or /mnt/ prefix). Returns null if resolution fails.

Execution functions
- Invoke-WSL(exePath, args):
  - Ensures WSL is available and resolves the path via Resolve-WslPath.
  - Executes via & wsl "$wslPath" @args and exits with the child’s exit code.
- Invoke-Win(exePath, args):
  - Verifies the Windows exe exists (Test-Path), then & "$exePath" @args, exiting with that code.

Mode selection
- wsl: Always run Invoke-WSL with the WSL/Linux binary.
- win: Always run Invoke-Win with the Windows exe.
- auto: Prefer WSL if available and configured; otherwise fall back to Windows. If WSL attempt fails, the script logs a warning and tries the Windows exe.

Error handling
- All exceptions are caught; messages are prefixed with [godot4.ps1] and a non‑zero exit code is returned. Clear guidance is given if neither binary is configured.

Examples
- Use configured auto mode (from JSON/env):
  pwsh -File scripts/godot4.ps1 --headless --path .
- Force WSL Linux binary explicitly:
  pwsh -File scripts/godot4.ps1 -Mode wsl --headless --path .
- Force Windows exe explicitly:
  pwsh -File scripts/godot4.ps1 -Mode win --path . scenes/Root.tscn
- Supply explicit paths ad hoc:
  pwsh -File scripts/godot4.ps1 -WslExe "/mnt/f/.../Godot_v4.4.1-stable_mono_linux.x86_64" --headless --path .

Batch shim: scripts/godot4.cmd
- Purpose: Let cmd.exe users run the same PowerShell runner.
- Behavior: Chooses pwsh.exe if present, otherwise powershell.exe, then forwards all args. Returns the child’s exit code.

Bash/WSL runner: scripts/godot4.sh

Purpose
- Minimal dependency wrapper that “just runs” the configured Linux binary in WSL/Linux shells.

Resolution order
- Sources scripts/godot4.env if present to pick up GODOT4_LINUX_EXE and/or GODOT4_MODE.
- Otherwise attempts to read scripts/godot4-config.json via a POSIX sed pattern to extract the value of "wsl_exe" without requiring jq.
- If neither path is found, exits with a helpful error instructing how to set GODOT4_LINUX_EXE or scripts/godot4-config.json.

Execution
- Uses exec "$GODOT_BIN" "$@" to replace the shell process with Godot, ensuring signals and exit codes propagate correctly.

Examples
- With env file:
  cp scripts/godot4.env.example scripts/godot4.env
  $EDITOR scripts/godot4.env  # set GODOT4_LINUX_EXE
  scripts/godot4.sh --headless --path .
- With JSON only:
  scripts/godot4.sh scenes/Root.tscn

Headless: test + ASCII smoke

PowerShell: scripts/run_headless.ps1
- Purpose: Execute the GDScript test runner and then a quick ASCII console “smoke” to validate the ASCII loop functions under stdin piping.
- Godot locator:
  - Reads win_exe from scripts/godot4-config.json (or GODOT4_WIN_EXE). If not set, uses godot4 (expects wrapper on PATH).
- Headless tests:
  - Runs: --headless --path . --script scripts/test_runner.gd
  - Captures stdout/stderr to logs/headless_tests.log (or logs/headless_tests.err.log in the Start-Process branch).
  - Records the exit code in $testExit.
- ASCII smoke:
  - Writes a short command script to logs/ascii_commands.txt, e.g., spawn, list, select, move, target, clear, remove, end_turn, quit.
  - Pipes the file to the console runner: scripts/tools/ascii_console.gd with -- --pipe so it exits cleanly at EOF.
  - Logs to logs/ascii_smoke.log.
- Strict mode:
  - -Strict flag will fail the script if tests fail (non‑zero exit); otherwise the script exits with the test exit code.

Bash: scripts/run_headless.sh
- Equivalent behavior in Bash using tee and PIPESTATUS to preserve the Godot exit code from the pipeline.
- Produces the same logs directory artifacts.

What the test runner does: scripts/test_runner.gd
- Extends SceneTree. On _init():
  - Loads each named module script (grid_logic, grid_visual_logic, grid_map, attributes, statuses, abilities, loadouts, reactions, event_bus, procedural_map_generator, grid_realtime_renderer, procedural_world, map_generator, terrain, runtime_services, console_commands).
  - If the script can instantiate and exposes run_tests(), it calls it and expects a Dictionary with keys { failed, total, log? }.
  - Accumulates totals; prints a PASS/FAIL line per module.
  - Prints a final TOTAL: X/Y failed summary and quit(failed) to make CI assertable.

ASCII interface (how the AI “sees” and interacts)

High‑level architecture
- AsciiGateway (scripts/autoload/ascii_gateway.gd) attaches at /root/AsciiGateway and acts as a stable façade over:
  - RuntimeServices: Game state coordinator exposing grid_map and timespace.
  - GridRealtimeRenderer: Provides ASCII snapshots and accepts input actions.
- ascii_console.gd (scripts/tools/ascii_console.gd) is a headless SceneTree that:
  - Attaches to AsciiGateway if available (preferred), otherwise bootstraps a minimal 4×4 grid + renderer + runtime internally so it can still function.
  - Emits frame snapshots to stdout so the AI can “see” the grid in text.
  - Reads commands from stdin interactively or from a pipe for scripted runs.

AsciiGateway responsibilities
- Bootstrap: If RuntimeServices or GridRealtimeRenderer are not found, it instantiates them and adds them to the root.
- Synchronization: If a live grid exists, it sizes the renderer accordingly.
- Snapshot API: snapshot() returns renderer.get_ascii_frame().
- Input API: apply_input(Vector2i, action) forwards to renderer.update_input.
- Actor ops: spawn, move_actor, perform, remove, list; manage an internal name->actor map to ensure consistent references.
- Command exec(line): Parses simple DSL commands and applies them; returns a snapshot string after execution to support REPL/server modes.
- Optional profile: _maybe_load_profile() reads res://data/ascii_profiles.json, allowing symbol/color mappings for renderer glyphs.

ascii_console.gd responsibilities
- Startup args: --pipe causes it to read stdin until EOF and then exit (useful for CI); --no-attach forces it to run without AsciiGateway.
- History/completion: Maintains a circular command history and a minimal completion pass (in interactive mode; full raw-mode editing is intentionally simplified for portability).
- Built‑in command set (when no gateway):
  - spawn NAME X Y — create an actor at a position.
  - move_actor NAME X Y — run the built-in move.
  - action NAME ID [X Y] — run an action with optional Vector2i payload.
  - remove NAME — delete an actor.
  - end_turn — advance the turn order.
  - list — print actors + positions.
  - save_state FILE — write grid/actors/markers JSON (see _save_state()).
  - load_state FILE — restore state and markers (see _load_state()).
  - select|move|target|click X Y, clear — renderer passthroughs.
  - quit — exit the console.
- Snapshot: _snapshot() prints AsciiGateway.snapshot() if attached, otherwise renderer.generate_ascii_field() so something textual always renders.

Interactive vs piped modes
- Interactive loop: Prints a frame, then a prompt, then reads a line, processes and repeats until quit or stdin closes.
- Piped loop: Prints a frame each tick and reads raw stdin chunks; on EOF or explicit quit it exits. This lets automation feed a sequence of commands and capture deterministic output.

Example ASCII scripted session (portable)
1) Create commands file:
   spawn A 0 0
   list
   select 0 0
   move 1 1
   target 1 0
   clear
   remove A
   end_turn
   quit
2) Run (PowerShell):
   Get-Content commands.txt | pwsh -File scripts/ascii_play.ps1 -Pipe
3) Run (Bash):
   PIPE=1 scripts/ascii_play.sh < commands.txt

Hotkeys (optional GUI input)
- AsciiKeybinds (scripts/autoload/ascii_keybinds.gd) binds keys to gateway input:
  - WASD → move
  - Enter → select
  - C → clear
  - T → target
  - Space → click
These are only effective when a window is open and you’re capturing input; headless runs ignore them, but the autoload remains harmless.

Documentation generation: doctool wrappers

PowerShell: scripts/doc_regen.ps1
- Locates Godot (win_exe or godot4 wrapper) and runs:
  --headless --path . --doctool <docsDir> --gdscript-docs <scriptsRoot>
- Optional conversions:
  - -BuildRst: tools/make_rst.py to docs/api_rst
  - -BuildHtml: tools/rst_to_html.py to docs/html
- Logs to logs/doctool*.log. Exits non‑zero if doctool fails.

Bash: scripts/doc_regen.sh
- Same flow using bash semantics and environment toggles RST=1, HTML=1.

Quick start recipes

Run the editor (Windows exe)
- pwsh -File scripts/godot4.ps1 -Mode win --path .   # runner is in scripts/

Run the editor (WSL/Linux binary)
- pwsh -File scripts/godot4.ps1 -Mode wsl --path .   # runner is in scripts/
  or (Bash/WSL) run directly without PATH setup:
- scripts/godot4.sh --path .

Headless module tests (PowerShell)
- pwsh -File scripts/run_headless.ps1 -Strict

Headless module tests (Bash)
- scripts/run_headless.sh

Play ASCII interactively
- Windows: pwsh -File scripts/ascii_play.ps1
- Bash/WSL: scripts/ascii_play.sh

Feed a scripted ASCII session and exit automatically
- Windows: Get-Content mycmds.txt | pwsh -File scripts/ascii_play.ps1 -Pipe
- Bash: PIPE=1 scripts/ascii_play.sh < mycmds.txt

How this enables AI operation
- Deterministic boot: The wrappers guarantee Godot 4.4.1 is used, so behavior and CLI flags remain stable.
- Headless I/O: The ASCII console prints frames and accepts commands over stdin/stdout, which are the two channels an AI can read/write in most automation sandboxes.
- Error visibility: All runners send logs to logs/ and return meaningful exit codes, so an AI can infer success/failure and decide the next step.
- Cross‑shell parity: The same intent (launch editor, run tests, play ASCII) works in PowerShell, cmd, and bash.

Troubleshooting

Godot not found
- Symptom: “godot4: command not found” or “[ERROR] Configure GODOT4_LINUX_EXE …”.
- Fix: All wrappers are under scripts/. You can either invoke `scripts/godot4.sh` (Bash) or `pwsh -File scripts/godot4.ps1` (Windows), or ensure a `godot4` command is on PATH for automatic detection.
  Also ensure scripts/godot4-config.json has correct win_exe/wsl_exe, or set env vars (GODOT4_WIN_EXE/GODOT4_LINUX_EXE).

WSL path resolution fails
- Symptom: “Could not resolve WSL path from: <path>”.
- Fix: Ensure WSL is installed and wslpath works. If your binary is already in /mnt/... form, pass -WslExe "/mnt/..." or set wsl_exe accordingly.

PowerShell execution policy blocks scripts
- Symptom: ExecutionPolicy errors.
- Fix: Run via scripts/godot4.cmd or invoke PowerShell with -ExecutionPolicy Bypass (the batch shim does this).

ASCII console doesn’t exit when piped
- Symptom: Console awaits input indefinitely.
- Fix: Make sure you pass the -- --pipe terminator to ascii_console.gd. The wrappers do this for you in run_headless and ascii_play when using piped input.

Headless test exit code always zero
- Cause: Losing the upstream exit code when piping through tee.
- Fix: PowerShell uses Start-Process or $LASTEXITCODE capture. Bash uses PIPESTATUS[0]. These are already implemented in the provided scripts.

Renderer snapshot missing or empty
- Cause: No renderer present or mismatch in method name.
- Fix: AsciiGateway creates a renderer if missing. ascii_console falls back to a local renderer when not attached to the gateway. Confirm GridRealtimeRenderer provides the ASCII snapshot API.

Migrating to another Godot 4.x
- Update paths in scripts/godot4-config.json.
- Keep project.godot config/features aligned with your installed editor.
- Test headless runs via scripts/run_headless.ps1 -Strict or scripts/run_headless.sh to validate non‑GUI flows before switching editor sessions.

Extensibility ideas
- Add discovery: Probe common install paths and cache results to scripts/godot4-config.json if nothing configured.
- Add version gate: Query the editor --version and block mismatched majors/minors with a clear message.
- Add CI flags: Environment‑controlled timeouts or artifact paths for logs and snapshots.

Cheat sheet
- Run editor (auto): pwsh -File scripts/godot4.ps1 --path .
- Headless tests (strict): pwsh -File scripts/run_headless.ps1 -Strict
- ASCII interactive: pwsh -File scripts/ascii_play.ps1
- ASCII scripted (exit on EOF): Get-Content cmds.txt | pwsh -File scripts/ascii_play.ps1 -Pipe
- Bash equivalents: scripts/godot4.sh, scripts/run_headless.sh, scripts/ascii_play.sh

Implementation references
- Wrapper scripts: scripts/godot4.ps1, scripts/godot4.cmd, scripts/godot4.sh
- Config files: scripts/godot4-config.json, scripts/godot4-config.example.json, scripts/godot4.env.example
- Headless flows: scripts/run_headless.ps1, scripts/run_headless.sh, scripts/test_runner.gd
- ASCII runtime: scripts/tools/ascii_console.gd, scripts/autoload/ascii_gateway.gd, scripts/autoload/ascii_keybinds.gd
- Docs generation: scripts/doc_regen.ps1, scripts/doc_regen.sh

This document is intentionally verbose so both humans and automated agents can quickly understand the intent and guarantees of each piece of tooling, and how to compose them to validate and interact with the project without a graphical desktop.
