# ASCII Engine Manual

## Overview
The ASCII engine renders Golom's tactical grid directly in the terminal so the project can run without a graphical window. It wires `GridRealtimeRenderer` to the core runtime services and mirrors GUI behavior in a text-only environment. Frames are streamed at a configurable interval and the engine accepts commands over standard input.

## Commands
### Game loop
When launched via `godot4 --headless --path .`, the engine loads the world and waits for single-character commands:

- `w`, `a`, `s`, `d` – move the player actor when it is their turn.
- `quit` – exit the simulation.

### Console helper
Running `godot4 --headless --path . --script scripts/tools/ascii_console.gd` starts a lightweight console useful for tests:

- `spawn NAME X Y` – create an actor at the given tile.
- `move_actor NAME X Y` – reposition an existing actor.
- `source FILE` – run commands from a file.
- `list` – show all actors and their positions.
- `select X Y` / `move X Y` / `target X Y` / `click X Y` – mark tiles through `update_input`.
- `clear` – remove all markers.
- `quit` – exit the console.

### TCP server
`godot4 --headless --path . --script scripts/tools/ascii_server.gd` runs a network server that mirrors the console interface on port `3456`. Connect using a tool like `nc localhost 3456` and you'll receive an ASCII grid every `0.5` seconds. Typed commands apply to the shared simulation just like the local console. Sending `quit` shuts down the server.

## Reading Output
Each refresh prints an ASCII snapshot of the grid. Actors appear as `@`; background layers use `*` for glyphs, `#` for strokes, `+` for filled cells and `.` for empties. When `ascii_use_color` is enabled the renderer emits ANSI color codes so terminals can approximate tile colors. The most recent snapshot is also stored in `GridRealtimeRenderer.ascii_debug` for inspection.

## Configuration
Key renderer options:

- `ascii_update_sec` – seconds between snapshots (default `0.5`).
- `ascii_use_color` – emit ANSI color codes.
- `ascii_include_actors` – automatically insert actors from `ascii_actor_group` (default `"actors").`
- `set_ascii_entity(pos, symbol, color, priority)` – manually stamp symbols.
- `update_input(pos, action)` – record selections or paths (`select`, `move`, `target`, `click`, `clear`).

Console option:

- `application/ascii_console_start_script` – path to a command file sourced on launch.

## Example Session
```
$ godot4 --headless --path .
@..
...
...
w
@..
...
...
quit
```
The first lines show the grid; entering `w` moved the player up and `quit` exited.

Running the console helper:

```
$ godot4 --headless --path . --script scripts/tools/ascii_console.gd
....
....
....
spawn A 1 1
.@..
....
....
move_actor A 2 1
..@.
....
....
quit
```

## Debugging Tips
- Run `godot4 --headless --path . --script scripts/test_runner.gd` before starting to verify modules pass self tests.
- Use `list` in the console to confirm actor positions.
- Enable `ascii_use_color` to highlight tile fills when debugging heatmaps.
- If input seems unresponsive, ensure the player's turn is active and that the terminal has focus.

## Wishlist
- Expose more renderer options from the command line.
- ASCII minimap and viewport scrolling.
- Record and replay sessions for regression tests.
ASCII Engine – Live Control & Gateway
====================================

Overview
--------
The ASCII engine mirrors the tactical grid at runtime. It can operate headlessly for CI and also attach to the live GUI game to act as a 1:1 controller/display.

Key components
- GridRealtimeRenderer (scripts/modules/GridRealtimeRenderer.gd)
  - `get_ascii_frame()` returns the current snapshot
  - `set_ascii_stream(enabled)` toggles periodic printing
  - `set_ascii_rate(hz)` sets snapshot frequency (when streaming)
  - `set_symbol_map(map)` maps classes/names → `{char,color,priority,z_index}`
- ASCII Gateway (autoload): scripts/autoload/ascii_gateway.gd
  - Exposes `snapshot()`, `apply_input(pos, action)`
  - Actor ops: `spawn`, `move_actor`, `perform`, `remove`, `list`
- Tools
  - Console: scripts/tools/ascii_console.gd (interactive or `--pipe`, attaches by default)
  - Server: scripts/tools/ascii_server.gd (TCP 3456, streams frames, accepts same commands)

Attach to live game
-------------------
The gateway autoload (`AsciiGateway`) searches for an existing `RuntimeServices` and `GridRealtimeRenderer`. If absent, it creates them. Console and server attach automatically. Use `--no-attach` to run the console in self-contained mode.

Common commands
---------------
From console or server:
- `spawn NAME X Y`
- `move_actor NAME X Y`
- `action NAME ID [X Y]`
- `remove NAME`
- `end_turn`
- `list`
- Renderer passthrough: `select X Y`, `move X Y`, `target X Y`, `click X Y`, `clear`

Examples
--------
- Interactive console (attach): `pwsh -File scripts/ascii_play.ps1`
- Piped: `PIPE=1 bash scripts/ascii_play.sh < logs/ascii_commands.txt`
- TCP server: `godot4 --headless --path . --script scripts/tools/ascii_server.gd`
