
This repo is operated EXCLUSIVELY by an AI agent using the provided wrappers to launch and drive Godot 4.4.1 (Linux or Windows) WITHOUT asking the human to run commands, or forcing the human to do anything outside the current working environment.

CLEAR ROLES FOR YOU: 
the AI agent runs Godot, captures logs, and reports; 

the human observes in the editor, plays the game, and helps prioritize fixes.


**Agent Operating Model**

- **Default rule:** When the human says “launch Godot” or similar, the AI Agent runs the wrapper directly and captures output. DO NOT reply with instructions - ONLY TAKE ACTION by running these scripts and/or other tools and tasks.

- **Binary selection:** Prefer the Linux wrapper during automation or CI; use the PowerShell wrapper to drive the Windows editor on the user’s machine.

- **Config sources:** Resolve Godot paths from `scripts/godot4-config.json`, then environment variables, then explicit CLI flags.

- **Logging:** Always tee process output to `logs/` and surface errors via `WorkspaceDebugger` (in‑app overlay and `user://workspace_errors.log`).

**Key Files**
- `project.godot`: Sets run scene to `res://scenes/VerticalSlice.tscn` and registers autoloads (debugger, ASCII tools).

- `INSTRUCTIONS`: Deep reference for runners, headless flows, and ASCII controls.

- `scripts/godot4-config.json`: Paths for binaries and default mode.
- `scripts/`: Wrappers and helpers (see below).
- `logs/`: Host‑side logs from wrapper flows.
- `user://workspace_errors.log`: In‑game log from `WorkspaceDebugger` autoload.

**Root-Level Shortcuts**
- The repo root includes convenience proxies so you can launch without changing directories:
  - Windows PowerShell: `./open_editor.ps1`
  - Windows cmd: `open_editor.cmd`
  - Bash/WSL/Linux: `./open_editor.sh`
  - All of these delegate to the scripts/ wrappers and preserve the same logging behavior (timestamped log + latest copy in `logs/`).

  Note: `open_editor.sh` now auto-detects `powershell.exe` on Windows and will delegate to the Windows wrapper (`open_editor.ps1`) for a full GUI editor session. This keeps a single command working from any shell while still launching the correct GUI-capable path on Windows.


**---W-R-A-P-P-E-R-S---**

-(entry points)-**
- `scripts/godot4.ps1` (PowerShell, Windows)
  - Purpose: Launch Godot via configured Windows or WSL binary.
  - Options: `-Mode auto|win|wsl`, `-WinExe <path>`, `-WslExe <path>`; all other args pass through to Godot.
  - Examples:
    - Open editor: `pwsh -File scripts/godot4.ps1 --path . --editor`
    - Force Windows exe: `pwsh -File scripts/godot4.ps1 -Mode win --path . --editor`

- `scripts/godot4.sh` (Bash/WSL/Linux)
  - Purpose: Minimal shim to run the Linux binary; resolves from env or JSON.
  - Env: `GODOT4_LINUX_EXE=/mnt/.../Godot_v4.4.1-stable_linux.x86_64`
  - Examples:
    - Open editor: `scripts/godot4.sh --path . --editor`
    - Play a scene: `scripts/godot4.sh --path . scenes/VerticalSlice.tscn`

- `scripts/godot4.cmd` (cmd.exe)
  - Purpose: Windows shim that forwards to PowerShell wrapper with ExecutionPolicy bypass.

**-----Operational Workflows--------**

**Standard Operating Procedure (SOP) — Full Editor (Windows)**
- Launch with visible PowerShell window and GUI editor:
  - `pwsh -File open_editor.ps1`
- Behavior:
  - Opens the Godot 4.4.1 Windows editor using the configured `win_exe`.
  - Shows a PowerShell window for the session and streams process output there.
  - Writes logs and a status JSON under `logs/`:
    - `logs/editor_launch_win_YYYYMMDD_HHMMSS.log`
    - `logs/editor_launch_win.log`
    - `logs/editor_launch_win_status.json`
- Important: Do not auto‑close the editor. Leave it running for interactive testing. Only close it when explicitly instructed.


- **Launch Full Editor (agent action)**
  - Linux/WSL: `scripts/godot4.sh --path . --editor`
  - Windows: `pwsh -File scripts/godot4.ps1 -Mode win --path . --editor`
  - Behavior: Opens the Godot 4.4.1 editor on the project. The run scene is `res://scenes/VerticalSlice.tscn` (F5 to play).


**Full Editor Launch — End‑to‑End Procedure**
- Preconditions
  - `scripts/godot4-config.json` points to valid binaries:
    - `win_exe` for Windows desktop sessions.
    - `wsl_exe` for Linux/WSL sessions. Prefer a non‑Mono build for CI/headless to avoid .NET warnings.
  - On Windows, PowerShell (`pwsh` or `powershell`) is available.
- Windows (recommended for GUI)
  - Run: `scripts/open_editor.ps1`
  - Effect: Launches the configured Windows Godot editor on this project.
  - Logs: `logs/editor_launch_win_YYYYMMDD_HHMMSS.log` and latest copy `logs/editor_launch_win.log`.
  - Notes: The Auto‑Play plugin opens and runs `VerticalSlice.tscn` unless `--no-autoplay` or `GODOT_NO_AUTOPLAY` is set.
- Linux/WSL (non‑GUI shells)
  - Run: `scripts/open_editor.sh`
  - Effect: Attempts to open the editor using the configured Linux binary. In headless shells the editor may not display; use Windows for GUI sessions.
  - Logs: `logs/editor_launch_linux_YYYYMMDD_HHMMSS.log` and latest copy `logs/editor_launch_latest.log`.
- Verification checklist
  - Editor window opens (Windows) and project loads without fatal errors.
  - `VerticalSlice.tscn` plays via Auto‑Play or by pressing `F5`.
  - `logs/editor_launch_*` shows no critical errors beyond environment‑specific warnings (e.g., missing ALSA on headless).
  - In‑game test summary prints `TOTAL: 0/65 failed` in Output when the slice runs.

- **Headless Tests + ASCII Smoke (agent validation)**
  - Linux/WSL: `scripts/run_headless.sh`
  - Windows: `pwsh -File scripts/run_headless.ps1 -Strict`
  - Outputs: `logs/headless_tests.log`, `logs/ascii_smoke.log` and non‑zero exit on failure when `-Strict`.

**Headless Game Run (smoke, no GUI)**
- Quick game boot (time‑boxed, Linux/WSL):
  - Example: `timeout 12s scripts/godot4.sh --headless --path . | tee logs/game_headless_run.log`
  - Expect: ASCII TCP server announces `listening on 127.0.0.1:3456`; in‑game tests print `TOTAL: 0/65 failed`.
  - Common warnings: `.NET hostfxr missing` (Mono builds), audio drivers (ALSA/Pulse) absent in CI.

- **ASCII Interactive (no GUI)**
  - Windows: `pwsh -File scripts/ascii_play.ps1`
  - Bash/WSL: `scripts/ascii_play.sh`
  - Streaming client: `pwsh -File scripts/ascii_stream_client.ps1 -Host 127.0.0.1 -Port 3456`

**Scene Runtime and Debug**
- `res://scenes/VerticalSlice.tscn`
  - Main systems: `RuntimeServices`, `GridRealtimeRenderer` (2D overlay), `GridInteractor`, `BattleController`, `MainGUI`.
  - Debug UI: `SliceDebug` with toggles for ASCII stream and a checkbox to show/hide the 2D grid overlay.
  - In‑game tests: `InGameTests` (script `scripts/tools/test_harness_node.gd`) auto‑run and publish results via `WorkspaceDebugger`.

- Camera (Isometric)
  - Script: `scripts/integration/isometric_camera.gd`.
  - Controls: Left‑drag = orbit, Right/Middle‑drag = pan, Mouse wheel = zoom, `F` = refit to grid bounds.

**Error Reporting and Logs**
- `WorkspaceDebugger` (autoload): `scripts/core/workspace_debugger.gd`
  - Emits `log_emitted(message, level)`; writes to `user://workspace_errors.log` and echoes to stdout.
  - In‑scene overlay HUD: `scripts/ui/error_overlay.gd` shows the latest messages.

- Wrapper logs (host filesystem):
  - `logs/headless_tests.log`, `logs/ascii_smoke.log`, `logs/editor_launch*.log`, etc.
  - Editor helpers log automatically:
    - Windows editor: `scripts/open_editor.ps1` writes timestamped log + `logs/editor_launch_win.log`.
    - Linux editor: `scripts/open_editor.sh` writes timestamped log + `logs/editor_launch_latest.log`.
    - ASCII clients (`ascii_play.*`, `ascii_stream_client.*`) write `logs/ascii_*` timestamped logs and latest copies.

See also
- `INSTRUCTIONS` — Runner details and examples.
- `docs/INTERNAL_DEBUGGER.md` — In‑game logging and overlay.

**Configuration Details**
- `scripts/godot4-config.json`
  - `mode`: `auto|wsl|win` (defaults to `auto`).
  - `win_exe`: Path to Windows Godot 4.4.1 exe (e.g., `F:\AIstuff\...\Godot_v4.4.1-stable_win64.exe`).
  - `wsl_exe`: Path to Linux Godot 4.4.1 binary (e.g., `/mnt/f/.../Godot_v4.4.1-stable_mono_linux.x86_64`).

- Environment overrides
  - `GODOT4_WIN_EXE`, `GODOT4_LINUX_EXE`, `GODOT4_MODE`.

**Agent Responsibilities**
- Run wrappers directly upon request (editor, play, headless tests, ASCII flows).
- Capture and attach relevant logs from `logs/` and `user://workspace_errors.log`.
- When graphics are unavailable, fall back to headless + ASCII while still attempting editor launch where applicable.
- Proactively fix script/API issues revealed by headless tests before handing off to the user for interactive verification.

**Human Responsibilities**
- Use the editor launched by the agent to play and visually verify.
- Provide recorded error output and priorities for fixes.
- Adjust `scripts/godot4-config.json` if binaries move; otherwise the agent resolves paths automatically.

**Troubleshooting**
- Editor opens with warnings in this shell but no window:
  - Expected in non‑GUI shells. Use the Windows wrapper for a desktop editor session.
- “godot4: command not found”:
  - Invoke wrappers directly (`scripts/godot4.sh` or `scripts/godot4.ps1`) instead of relying on PATH.
- TileMap API errors or overlay covers 3D view:
  - Overlay is off by default; toggle “Show 2D Grid Overlay” in SliceDebug if needed.
- Camera seems stuck:
  - Use Left‑drag (orbit), Right/Middle‑drag (pan), wheel (zoom), or press `F` to refit.

- “.NET hostfxr missing” on Linux Mono builds:
  - Use a non‑Mono Linux binary for CI/headless, or install .NET SDK 8.0+ if C# is required.
- Editor crashes in headless shells:
  - Expected where no display is available. Use the Windows wrapper for full GUI sessions.
- Plugin script path error `res://.../res://...`:
  - Fixed by using relative `script="plugin.gd"` in `addons/auto_play_on_editor/plugin.cfg`.

**Quick Commands (agent)**
- Open editor (Linux/WSL): `scripts/godot4.sh --path . --editor`
- Open editor (Windows): `pwsh -File scripts/godot4.ps1 -Mode win --path . --editor`
- Run tests (Linux/WSL): `scripts/run_headless.sh`
- Run tests (Windows): `pwsh -File scripts/run_headless.ps1 -Strict`
