**Overview**
- This project ships with an internal, agent-friendly debugging pipeline that captures logs from both wrappers and the running game, shows them in-scene, and lets the agent export snapshots while the human tests in the editor.

**Components**
- `ErrorHub` (autoload): Central aggregator with an API for structured reports. Provides signals and a ring buffer for quick retrieval.
- `WorkspaceDebugger` (autoload): File + stdout logger. Forwards to `ErrorHub` when available.
- `ErrorOverlay` (HUD): Lightweight on-screen panel with live log feed and quick actions.

**Paths**
- Autoloads:
  - `res://scripts/autoload/error_hub.gd` → `/root/ErrorHub`
  - `res://scripts/core/workspace_debugger.gd` → `/root/WorkspaceDebugger`
- HUD:
  - `res://scripts/ui/error_overlay.gd` (added in `scenes/VerticalSlice.tscn`)
- Files:
  - In‑game log: `user://workspace_errors.log`
  - Wrapper logs: `logs/*.log`

**ErrorHub API**
- Signals: `entry_added(entry: Dictionary)`
- Methods:
  - `info(ctx: String, msg: String, data := {})`
  - `warn(ctx: String, msg: String, data := {})`
  - `error(ctx: String, msg: String, data := {})`
  - `exception(ctx: String, data := {})`
  - `get_entries(max := 200, level_filter := []) -> Array`
  - `export_to_file(path := "user://error_snapshot.log") -> String` (returns the path written)

**Typical Use**
- From any script:
  - `ErrorHub.error("BattleController", "Failed to spawn", {pos=Vector2i(1,2)})`
- WorkspaceDebugger automatically forwards its messages to ErrorHub, so existing `log_info/log_error` calls show up too.

**UI (ErrorOverlay)**
- Displays the latest N messages with color coding.
- Buttons: Pause (toggle live updates), Clear (panel buffer), Save (write snapshot file path to logs).
- Can subscribe either to `WorkspaceDebugger.log_emitted` or `ErrorHub.entry_added`.

**Agent Workflow**
- Launch the editor or headless run via scripts in `docs/OPERATIONS.md`.
- Watch for on-screen overlay updates while the human reproduces problems.
- Export snapshot when asked and reference the path in your report.

