# Developer Codebase Overview

This document provides an exhaustive cross-reference of the Golom tactical RPG project for outside engineers. It surveys every script and module, details their responsibilities, and highlights interactions between systems. The goal is to consolidate knowledge currently scattered across scripts and existing manuals, giving contributors a single reference point.

## Project Layout

```
res://scripts/
  core/                # bootstrapping scenes and base actor definition
  grid/                # grid-specific resources and interaction helpers
  modules/             # self-contained logic services
  tests/               # isolated scene tests
  test_runner.gd       # headless aggregate test harness
```

Visual assets and scenes live under `res://scenes/`, while documentation resides in `docs/`.

## Core Scripts (`scripts/core`)

### `base_actor.gd`
Defines **BaseActor**, a lightweight template for any creature placed on the grid. It stores grid coordinates (`grid_pos`), facing, size, a `faction` string (e.g. "player" or "enemy"), and gameplay stats such as health (`HLTH`), chi (`CHI`), action points (`ACT`), initiative (`INIT`), status flags, attributes (power, speed, focus, capacity, perception), and harvestable rewards (XP, loot, quest tokens, script triggers). The `describe()` helper outputs a human-readable summary.

### `workspace.gd`
Implements an interactive **Workspace** for loading modules and running their tests. The GUI lists each module, its load status, pass/fail result, and a button to view detailed logs. Command-line flags (`--module` / `--modules`) can restrict which modules load. The workspace emits a `tests_completed` signal with a summary dictionary and supports looping test execution for long-running stability checks. A dedicated Map Generator tab runs procedural world creation on a background thread, shows a pulsing progress bar during generation, and can export the resulting color map to `user://`.

### `workspace_debugger.gd`
A small utility that logs workspace events and errors to `user://workspace_errors.log` for later inspection. Both informational and error messages funnel through `_log()`.

### `grid_default_map.gd`
Loads a 32×32 demo grid and instantiates three color-coded actors (green player, red enemy, blue NPC). It preloads the `RuntimeServices` aggregator and an optional `GridRealtimeRenderer` for visualization when a display is available. Actors are positioned using `timespace.add_actor()` and rendered via `grid_vis.set_cell_color()`.

### `root.gd`
The entry point scene. It instantiates the Workspace, listens for its `tests_completed` signal, and if all module tests pass, loads `GridDefaultMap.tscn` to provide an interactive sandbox. Continuous background testing is enabled via `workspace.start_loop()`.

## Grid Utilities (`scripts/grid`)

### `grid_map.gd` – `LogicGridMap`
A feature-rich Resource responsible for tactical spatial logic:

- **Actor placement:** Tracks occupied tiles (`occupied`) and actor origins (`actor_positions`). `move_actor()` validates multi-tile footprints, while `remove_actor()` clears entries. `get_occupied_tiles()` and `get_all_actors()` expose current occupants.
- **Spatial queries:** `is_in_bounds()`, `is_occupied()`, distance helpers (`get_distance`, `get_chebyshev_distance`), and `has_line_of_sight()` using Bresenham's algorithm with LOS blockers and cover checks.
- **Range queries:** `get_actors_in_radius()` and `get_positions_in_range()` use Chebyshev distance and optional LOS requirements.
- **Pathfinding:** `find_path()` implements A* with movement costs, turning penalties (`TURN_COST`), climb restrictions, and multi-tile actor support. `find_path_for_actor()` wraps it using actor size and facing.
- **Area-of-effect shapes:** Burst, cone, line, and wall calculations via `get_aoe_tiles()` and helpers.
- **Tactical logic:** Zone-of-control projection (`get_zone_of_control`), flanking checks, cover handling, tile tags, per-tile movement costs, and height levels.
- **Event log:** `log_event()` appends non-error messages for debugging.

### `grid_interactor.gd` – `GridInteractor`
A `Node2D` that translates mouse input into grid interactions. It emits `tile_clicked`, `tiles_selected`, `actor_clicked`, and `actors_selected` signals.
See `grid_interactor_manual.md` for usage details and signal wiring examples. Features include drag-selection previews using `GridRealtimeRenderer`, modifier bitmask helpers (shift=add, ctrl=toggle), and stateful drag handling to differentiate clicks from marquee selection.

## Logic Modules (`scripts/modules`)
Each module is intentionally decoupled and exposes `run_tests()` for headless verification.

### Spatial & Timeline
- **`turn_timespace.gd` – TurnBasedGridTimespace:** Manages rounds, initiative order, action points, reactions, status ticking, and serialization. Actions are registered with validators/executors and performed via `perform()`. Signals (`round_started`, `turn_started`, `ap_changed`, `action_performed`, etc.) keep UI/AI layers loosely coupled. Extensive self-tests cover initiative stability, AP spending, overwatch, status durations, serialization, and event log schema.
- **`grid_logic.gd`:** Placeholder stub that currently logs a self-test message.
- **`grid_visual_logic.gd` – GridVisualLogic:** Immediate-mode renderer using `draw_rect` for debugging or minimal UI. Accepts per-tile `Color` or `Callable` states and exposes helpers for batch updates.
- **`GridRealtimeRenderer.gd`:** High-performance overlay built on `MultiMeshInstance2D`. Provides layered fills, glyphs, strokes, optional hatch patterns, label pooling, numeric channels with heatmap gradients, and ASCII snapshots for headless inspection.

### Actor Data & Effects
- **`attributes.gd` – Attributes:** Centralizes numeric stats. Supports base values and additive/multiplicative modifiers grouped by source. `get_value()` computes the final stat.
- **`statuses.gd` – Statuses:** Tracks buffs/debuffs with stacks and durations. `apply_status()` records entries, while `tick()` decrements durations and logs expirations.
- **`abilities.gd` – Abilities:** Registers ability definitions, validates availability, and logs execution. Currently a stub for future effect lists and cost handling.
- **`loadouts.gd` – Loadouts:** Computes the ability set available to an actor based on granted IDs.
- **`reactions.gd` – Reactions:** Queues reaction opportunities in FIFO order and exposes `resolve_next()` for consumption.
- **`event_bus.gd` – EventBus:** Append-only structured log for analytics and deterministic replays.

### Integration Layer
- **`runtime_services.gd` – RuntimeServices:** Aggregates all core modules into a single node. On `_init` it wires `TurnBasedGridTimespace` to a `LogicGridMap`. `run_tests()` performs a minimal integration test then executes each module's self-tests, aggregating results for CI.

## UI Components
- **`variable_display.gd` – VariableDisplay:** Panel script attached to `scenes/MainHUD.tscn` that subscribes to `RuntimeServices` signals. It shows the current round, active actor, and allows modules to register custom stats via `register_stat()` with optional formatting helpers.

## Tests

- **`scripts/test_runner.gd`** iterates over module instances, runs `run_tests()`, prints pass/fail summaries, and exits with the number of failures. Each module frees temporary objects to avoid leaks.
- **`scripts/tests/grid_visual_logic_test.gd`** provides a small SceneTree that instantiates `GridVisualLogic` and exercises color and callable drawing paths.

## Documentation
Existing manuals in `docs/` describe individual modules. This overview ties them together and highlights additional scripts (Workspace, GridInteractor, BaseActor, etc.) that were previously undocumented.

