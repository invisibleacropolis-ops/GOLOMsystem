# Golom

This repository contains a Godot 4 project exploring tactical grid mechanics for a future role‑playing game. The rule set will ultimately be derived from the DOCX design documents in the root of this repository.

## Project structure
- `project.godot` – core project configuration.
- `scenes/` – scene files; `Workspace.tscn` launches logic modules and `TestGrid.tscn` runs the grid test harness.
- `scripts/core/` – infrastructure scripts such as the workspace launcher and file logger.
- `scripts/grid/` – core gameplay scripts including `grid_map.gd` which implements the tactical rules.
 - `scripts/modules/` – pluggable feature modules. `grid_visual_logic.gd` renders a configurable grid, `grid_logic.gd` remains a stub, and `turn_timespace.gd` introduces turn order and action point tracking.

The DOCX files (`Taoist Player's Handbook.docx`, `Taoist-GMguide.docx`, and `Taoist Monsters & Treasure.docx`) define the tabletop RPG that this engine will eventually implement.

## Prerequisites
- Godot 4.4.1 is required. The `godot4` binary should be available in your PATH for headless test execution.
- Runtime module responsibilities are summarized in [docs/runtime_services.md](docs/runtime_services.md).

## Headless Tooling (for CI and ASCII play)
- Configure paths in `scripts/godot4-config.json` (see `scripts/godot4-config.example.json`).
- Regenerate API XMLs: `pwsh -File scripts/doc_regen.ps1`
- Run module tests and an ASCII smoke: `pwsh -File scripts/run_headless.ps1 -Strict`
- Play interactively in ASCII: `pwsh -File scripts/ascii_play.ps1`
- Full details in `docs/headless_tooling.md`.

## Headless test runner
The repository provides `scripts/test_runner.gd` which invokes each module's `run_tests()` method:

```bash
 godot4 --headless --path . --script scripts/test_runner.gd
```

## Headless ASCII Mode
The ASCII engine renders the tactical grid directly in the terminal so the project can run without a windowed display. See [docs/ascii_engine_manual.md](docs/ascii_engine_manual.md) for full usage and configuration details.

## ASCII headless console
`scripts/tools/ascii_console.gd` wires the `GridRealtimeRenderer` to a minimal
command-line interface so the project can be inspected without a windowed
display. Spawn and move actors on a small 4×4 map and observe the ASCII snapshot
printed each frame:

```bash
godot4 --headless --path . --script scripts/tools/ascii_console.gd
```

Commands include:

```
spawn NAME X Y    # create an actor at the given tile
move_actor NAME X Y  # reposition an existing actor
source FILE        # run commands from FILE
list               # show all actors and their positions
select X Y | move X Y | target X Y | click X Y | clear
quit               # exit the console
```

Set the project setting `application/ascii_console_start_script` to the path of a
command file to execute it automatically when the console launches.


## Workspace launcher
`scripts/core/workspace.gd` powers `scenes/Workspace.tscn`. When executed headlessly it can load one or more logic modules and report their self‑test results. Each module is mapped to a scene; after a module's `run_tests()` coroutine completes the workspace stays alive so long‑running modules can keep processing. A companion script `workspace_debugger.gd` writes log output to `user://workspace_errors.log`.

Example:

```bash
godot4 --headless --path . -- --modules grid_logic
```

Multiple modules can be comma‑separated:

```bash
godot4 --headless --path . -- --modules grid_logic,other_module
```

The workspace prints a one‑line summary for each module and remains running:

```
grid_logic: PASS (0/0)
All module tests executed. Workspace running...
```

### Logic modules and event logs
The engine is organized into "logic modules" (for example `grid_map`, `grid_logic`, and `turn_timespace`) that the `workspace` module preloads and runs continuously. Serving as the master coordinator, the workspace will eventually chart logical flow and nodal connections between these modules. Each module now records non-error state changes to an `event_log` array via a `log_event(message)` helper. These per-module logs will later be aggregated into a master event stream to drive narrative output.

## Running grid tests
The comprehensive grid test suite lives in `scenes/TestGrid.tscn` and is driven by the `test_grid.gd` script. It instantiates `LogicGridMap` and runs scenario tests covering movement, pathfinding, line‑of‑sight and more. To execute the suite headlessly:

```bash
godot4 --headless --path . scenes/TestGrid.tscn
```

The scene exits with a non‑zero status code if any test fails so it can be integrated into CI workflows.

## Procedural demo world
The main scene `scenes/Root.tscn` now boots into a 64×64 procedurally
generated map. Terrain height, grass overlays and a simple cross‑road
network are produced via `ProceduralMapGenerator`. Three actors are
spawned through `RuntimeServices`: a controllable player and two AI
entities (enemy and NPC) that take turns under the `TurnBasedGridTimespace`
module.

## Turn-based Grid Timespace
The `scripts/modules/turn_timespace.gd` module orchestrates tactical rounds and links directly with `LogicGridMap` for spatial updates. Call `set_grid_map()` with a `LogicGridMap` instance, then register actors with `add_actor(actor, initiative, ap, pos)` to place them on the grid. During a round `move_current_actor()` consumes action points and delegates movement to the grid map, while `end_turn()` advances to the next actor by initiative order. Static objects can be tracked with `add_object(obj, pos)` and both actors and tiles may gain or lose status effects via `apply_status_to_actor`, `remove_status_from_actor`, `apply_status_to_tile`, and `remove_status_from_tile`.

Recent updates introduce a formal round/turn state machine with signals (`round_started`, `turn_started(actor)`, `ap_changed(actor, old, new)`, etc.) so UI and AI layers can react without tight coupling. Initiative ordering is deterministic thanks to a seedable tiebreaker and persistent IDs, ensuring stable turn order across runs. A lightweight action economy lets you register actions with AP costs and validators and invoke them through `can_perform`/`perform`. The module also supports basic serialization via `to_dict`/`from_dict` and emits a `timespace_snapshot_created` signal when snapshots are generated. A built-in `run_tests()` hook validates movement, ordering, and serialization so the workspace can preload the module safely.

## LogicGridMap internals
This section documents the `scripts/grid/grid_map.gd` resource in detail so that both newcomers and engineers can see how the grid system works.

### Core data model
- **Dimensions:** `width` and `height` define the playable rectangle. Everything else checks against these values.
- **Actor tracking:**
    - `occupied` maps each `Vector2i` tile to the actor covering it. Multi‑tile creatures appear once per tile.
  - `actor_positions` reverses that mapping, storing an actor's origin tile.
 - **Terrain layers:** optional dictionaries (`movement_costs`, `los_blockers`, `height_levels`, `tile_tags`, `covers`) add extra rules to individual cells without needing a visual map.

### Core grid functions
#### `is_in_bounds(pos: Vector2i) -> bool`
- *Plain language:* Confirms that a coordinate lies within the configured grid rectangle.
- *Engineering notes:* Returns `true` only when `0 <= x < width` and `0 <= y < height`. Used as the first guard in every map query【scripts/grid/grid_map.gd†L57-L60】.

#### `is_occupied(pos: Vector2i) -> bool`
- *Plain language:* Answers “is there anything standing on this tile?”
- *Engineering notes:* Delegates to the `occupied` dictionary; if the key exists, a unit already resides there【scripts/grid/grid_map.gd†L63-L66】.

#### `move_actor(actor, to) -> bool`
- *Plain language:* Relocates a piece, validating every tile it would cover and updating both forward and reverse lookup tables.
- *Engineering notes:* Builds the footprint with `get_tiles_for_footprint`, rejects moves that leave the board or collide with another actor, clears the actor's previous tiles, then marks the new tiles and updates the actor's `grid_pos` property【scripts/grid/grid_map.gd†L69-L94】.

#### `remove_actor(actor) -> void`
- *Plain language:* Erases an actor from the map completely.
- *Engineering notes:* Looks up all tiles occupied by the actor, clears them from `occupied`, and drops the actor from `actor_positions`【scripts/grid/grid_map.gd†L96-L103】.

#### `get_actor_at(pos) -> Object`
- *Plain language:* Retrieves whoever is standing on a tile, or `null` if empty.
- *Engineering notes:* Simple dictionary lookup against `occupied`【scripts/grid/grid_map.gd†L105-L108】.

#### `get_all_actors() -> Array[Object]`
- *Plain language:* Returns each unique actor currently present.
- *Engineering notes:* Iterates over `occupied.values()`, removes duplicates, and returns a typed array so callers can rely on `Object` elements【scripts/grid/grid_map.gd†L110-L118】.

#### `get_occupied_tiles(actor) -> Array[Vector2i]`
- *Plain language:* Lists every tile covered by the actor's footprint.
- *Engineering notes:* Uses the cached origin in `actor_positions` and the actor's `size` property to call `get_tiles_for_footprint`【scripts/grid/grid_map.gd†L120-L127】.

#### `get_tiles_for_footprint(origin, size) -> Array[Vector2i]`
- *Plain language:* Helper that expands a rectangle into individual tile coordinates.
- *Engineering notes:* Nested loops over width and height build a list of offsets added to the origin【scripts/grid/grid_map.gd†L129-L135】.

### Distance helpers
#### `get_distance(a, b) -> int`
- *Plain language:* Manhattan distance – counts steps when moving only north/south/east/west.
- *Engineering notes:* `abs(dx) + abs(dy)` gives an admissible heuristic for grid movement without diagonals【scripts/grid/grid_map.gd†L139-L146】.

#### `get_chebyshev_distance(a, b) -> int`
- *Plain language:* Square radius distance where diagonals cost the same as straights.
- *Engineering notes:* `max(abs(dx), abs(dy))` suits AoE radius checks and the A* heuristic for diagonal movement【scripts/grid/grid_map.gd†L148-L154】.

### Line of sight
#### `set_los_blocker(pos, blocks=true) -> void`
- *Plain language:* Marks a tile as permanently blocking vision or clears the mark.
- *Engineering notes:* Guarded by `is_in_bounds`; when `blocks` is true the position is stored in `los_blockers`, otherwise the key is removed【scripts/grid/grid_map.gd†L160-L168】.

#### `is_los_blocker(pos) -> bool`
- *Plain language:* Checks if a tile has been flagged as blocking vision.
- *Engineering notes:* Simple presence test in the `los_blockers` dictionary【scripts/grid/grid_map.gd†L170-L172】.

#### `has_line_of_sight(a, b) -> bool`
- *Plain language:* Uses a Bresenham line to trace from point A to point B and stops if any intermediate tile blocks sight.
- *Engineering notes:* Validates both endpoints, walks the grid while checking each tile for occupancy, explicit blockers, or "full" cover, and even tests diagonal corners to prevent corner‑cutting【scripts/grid/grid_map.gd†L174-L201】【scripts/grid/grid_map.gd†L202-L231】.

### Range queries
#### `get_actors_in_radius(center, radius, require_los=false)`
- *Plain language:* Finds actors within a square radius, optionally demanding a clear line of sight to each.
- *Engineering notes:* Iterates over `get_all_actors`, calculates Chebyshev distance, and filters by LOS when requested【scripts/grid/grid_map.gd†L237-L244】.

#### `get_positions_in_range(center, range_val, require_los=false)`
- *Plain language:* Enumerates tiles within a square radius from the center.
- *Engineering notes:* Loops across a bounding box, tests bounds, Chebyshev distance and optional LOS before appending positions【scripts/grid/grid_map.gd†L246-L255】.

### Pathfinding
#### `find_path_for_actor(actor, start, goal)`
- *Plain language:* Convenience wrapper that grabs an actor's `size` and `facing` before pathfinding.
- *Engineering notes:* Delegates to `find_path` so callers don't have to extract properties themselves【scripts/grid/grid_map.gd†L261-L264】.

#### `find_path(start, start_facing, goal, actor_size)`
- *Plain language:* Full A* search that respects terrain costs, turns, elevation, and actor size.
- *Engineering notes:* Maintains open/closed sets, uses Chebyshev distance for the heuristic, rejects tiles that violate height or occupancy rules, adds turn cost when the heading changes, and reconstructs the path once the goal is found【scripts/grid/grid_map.gd†L266-L332】【scripts/grid/grid_map.gd†L333-L362】.

### Area‑of‑effect templates
#### `get_aoe_tiles(shape, origin, direction, range)`
- *Plain language:* High‑level dispatcher returning tiles affected by burst, cone, line, or wall effects.
- *Engineering notes:* Switches on `shape` and forwards parameters to the respective private helper【scripts/grid/grid_map.gd†L370-L377】.

#### `_get_burst_aoe(origin, radius)`
- *Plain language:* Returns all tiles within a square radius around the origin.
- *Engineering notes:* Thin wrapper over `get_positions_in_range` with LOS disabled【scripts/grid/grid_map.gd†L379-L383】.

#### `_get_cone_aoe(origin, direction, length)`
- *Plain language:* Builds a 90° cone extending `length` tiles from the origin in the supplied direction.
- *Engineering notes:* Normalizes the facing vector, scans a bounding box, and uses dot‑product thresholds to keep only tiles inside the cone and within Manhattan distance【scripts/grid/grid_map.gd†L385-L407】.

#### `_get_line_aoe(origin, direction, length)`
- *Plain language:* Marches `length` steps from the origin and returns the 1‑tile‑wide line.
- *Engineering notes:* Repeatedly adds the direction vector, recording in‑bounds positions【scripts/grid/grid_map.gd†L409-L418】.

#### `_get_wall_aoe(origin, direction, length)`
- *Plain language:* Produces a straight wall perpendicular to the given direction.
- *Engineering notes:* Derives the perpendicular vector, walks equally in both directions from the origin, and collects all valid tiles【scripts/grid/grid_map.gd†L420-L435】.

### Tactical evaluation
#### `get_zone_of_control(actor, radius=1, arc="all")`
- *Plain language:* Computes tiles threatened by an actor, optionally limited to front/rear/side arcs.
- *Engineering notes:* Determines border tiles for large actors, fans out from each tile up to `radius`, filters by dot products relative to facing, and deduplicates the result【scripts/grid/grid_map.gd†L489-L547】.

#### `_get_border_tiles(actor)`
- *Plain language:* Helper that returns only the perimeter tiles of a multi‑tile actor.
- *Engineering notes:* Builds a dictionary of occupied tiles and flags those with any neighbor missing to identify the edge【scripts/grid/grid_map.gd†L552-L575】.

#### `get_tiles_under_zoc(radius=1, arc="all")`
- *Plain language:* Union of every actor's zone of control, useful for crowd‑control visuals.
- *Engineering notes:* Calls `get_zone_of_control` for each actor and stores tiles in a dictionary to remove duplicates before returning an array【scripts/grid/grid_map.gd†L577-L591】.

#### `actor_in_zoc(defender, threat_actor, radius=1, arc="all")`
- *Plain language:* Checks whether one actor stands in another's threatened area.
- *Engineering notes:* Pulls the defender's cached `grid_pos` and simply tests membership in the threat actor's ZOC list【scripts/grid/grid_map.gd†L594-L606】.

#### `get_threatened_tiles_by(actor, radius=1, arc="all")`
- *Plain language:* Alias for `get_zone_of_control`; included for semantic readability.
- *Engineering notes:* Direct pass‑through【scripts/grid/grid_map.gd†L608-L611】.

#### `get_attack_arc(defender, attacker) -> String`
- *Plain language:* Classifies the attacker's bearing relative to the defender (`front`, `rear`, `left`, `right`, or `none`).
- *Engineering notes:* Calculates the angle between defender's facing vector and the vector toward the attacker; thresholds at ±45° and ±135° split the plane into four quadrants【scripts/grid/grid_map.gd†L613-L642】.

#### `is_flanked(actor) -> bool`
- *Plain language:* Determines if an actor is threatened by enemies from roughly opposite sides.
- *Engineering notes:* Gathers all opponents that place the actor inside their ZOC, then checks pairwise dot products to see if any two are separated by ~180°【scripts/grid/grid_map.gd†L644-L668】.

### Terrain, tags, and cover
These functions attach environmental properties to individual tiles that influence movement and visibility.

#### `set_movement_cost(pos, cost)` / `get_movement_cost(pos)`
- *Plain language:* Override the default step cost or query it. `INF` represents impassable terrain.
- *Engineering notes:* Setter stores a float in `movement_costs`; getter falls back to `1.0` or `INF` if out of bounds【scripts/grid/grid_map.gd†L673-L687】.

#### `set_height(pos, level)` / `get_height(pos)`
- *Plain language:* Records elevation and retrieves it later. High steps may block movement.
- *Engineering notes:* Heights default to `0`; setters check bounds before writing to `height_levels`【scripts/grid/grid_map.gd†L689-L700】.

#### `add_tile_tag(pos, tag)` / `remove_tile_tag(pos, tag)` / `has_tile_tag(pos, tag)`
- *Plain language:* Manage arbitrary string tags such as terrain types or landmarks.
- *Engineering notes:* Uses arrays per tile; removal also cleans up empty arrays to keep dictionaries lean【scripts/grid/grid_map.gd†L703-L730】.

#### `set_cover(pos, type, direction, height:=1)` / `get_cover(pos)`
- *Plain language:* Assigns directional defensive cover (`half` or `full`) with an optional height; retrieval returns a dictionary and defaults to `none`.
- *Engineering notes:* Stored in a `covers` map; `has_line_of_sight` and `get_cover_modifier` respect facing and height when determining protection【scripts/grid/grid_map.gd†L874-L926】.

---

## Test grid harness
`scenes/test_grid.gd` wires up the `LogicGridMap` with a lightweight `BaseActor` node and runs an extensive suite of scenario tests.

### Utility types and helpers
#### `BaseActor`
- *Plain language:* Master template for game pieces, storing grid position, facing, size, and core stats.
- *Engineering notes:* Defined in `scripts/core/base_actor.gd`; extends `Node` for scene-tree cleanup and offers helpers like `set_facing` and `describe`【scripts/core/base_actor.gd†L8-L26】.

#### `_add_actor(name, pos, facing=RIGHT, size=Vector2i(1,1))`
- *Plain language:* Creates a `BaseActor`, inserts it into the scene, and positions it on the grid.
- *Engineering notes:* Calls `grid.move_actor` and reports placement errors via `push_error`【scenes/test_grid.gd†L20-L27】.

#### `_reset()`
- *Plain language:* Clears all actors from both the scene tree and the grid data so each test starts fresh.
- *Engineering notes:* Iterates children, queues free on any `BaseActor`, then resets every dictionary in the `LogicGridMap` instance and restores default dimensions【scenes/test_grid.gd†L29-L47】.

### Test runner lifecycle
#### `_ready()`
- *Plain language:* Instantiates the grid resource and kicks off the full asynchronous test run when the scene loads.
- *Engineering notes:* Uses `await _run_all_tests()` so the process waits for every section before exiting【scenes/test_grid.gd†L16-L17】.

#### `_run_all_tests()`
- *Plain language:* Central coordinator that registers each named test, executes them sequentially, logs per‑section results, and exits the process with a failure count as the status code.
- *Engineering notes:* Builds a dictionary mapping section titles to callables, awaits `_run_test_section` for each, aggregates pass/fail counts, prints a summary, and finally calls `get_tree().quit(failed_tests)` for CLI integration【scenes/test_grid.gd†L51-L99】.

#### `_run_test_section(title, test_callable)`
- *Plain language:* Resets the board, runs one test, and formats success or failure details.
- *Engineering notes:* Invokes `_reset`, yields one frame to ensure cleanup, executes the callable, and standardizes return structure `{passed: bool, message: String}`【scenes/test_grid.gd†L101-L112】.

### Individual test functions
Each test returns the standardized dictionary so the runner can present rich diagnostics.

- **`_test_bounds_and_occupancy`** – Validates `is_in_bounds`, `is_occupied`, `get_actor_at`, and `get_all_actors` with simple placements【scenes/test_grid.gd†L117-L135】.
- **`_test_move_and_remove`** – Exercises `move_actor` and `remove_actor`, confirming tiles and caches update correctly【scenes/test_grid.gd†L137-L154】.
- **`_test_distance`** – Checks the Manhattan distance helper against a known 3‑4‑5 triangle【scenes/test_grid.gd†L156-L163】.
- **`_test_los`** – Verifies LOS blockers and `has_line_of_sight` both for blocking and clearing situations【scenes/test_grid.gd†L165-L183】.
- **`_test_range`** – Ensures `get_actors_in_radius` and `get_positions_in_range` return the expected counts and include/exclude actors appropriately【scenes/test_grid.gd†L185-L199】.
- **`_test_pathfinding_finds_path`** – Confirms A* can route around obstacles and that the path starts and ends on the correct tiles【scenes/test_grid.gd†L201-L216】.
- **`_test_pathfinding_is_blocked`** – Builds an impassable wall to ensure pathfinding reports failure when no route exists【scenes/test_grid.gd†L218-L232】.
- **`_test_pathfinding_height`** – Uses height levels to forbid climbs higher than `MAX_CLIMB_HEIGHT` and then allows a single‑step climb after lowering the wall【scenes/test_grid.gd†L234-L255】.
- **`_test_pathfinding_facing_cost`** – Demonstrates how `TURN_COST` influences A* decisions by toggling an expensive tile and a cheaper detour【scenes/test_grid.gd†L257-L282】.
- **`_test_tile_tags_and_cover`** – Exercises tag addition/removal and cover types, plus LOS interaction with `full` vs `half` cover【scenes/test_grid.gd†L284-L314】.
- **`_test_aoe_templates`** – Checks all AOE helpers (burst, line, cone, wall) against hand‑computed expectations【scenes/test_grid.gd†L316-L351】.
- **`_test_creature_size`** – Places, moves, pathfinds with, and removes a `2×2` actor to confirm footprint handling and collision rules【scenes/test_grid.gd†L353-L397】.
- **`_test_zoc`** – Validates zone‑of‑control calculations, tile collection, and `actor_in_zoc` helper【scenes/test_grid.gd†L399-L414】.
- **`_test_attack_arcs`** – Places attackers on each side of a defender to classify arcs as front/left/right/rear【scenes/test_grid.gd†L440-L458】.
- **`_test_flanking`** – Ensures `is_flanked` requires threats from roughly opposite sides and responds when one threat is removed【scenes/test_grid.gd†L480-L492】.
- **`_test_edge_cases`** – Miscellaneous checks for Chebyshev distance, LOS filters in `get_actors_in_radius`, and diagonal attack arc detection【scenes/test_grid.gd†L520-L539】.

These tests collectively exercise the entire API so contributors can verify behavior quickly from the command line.

## Module catalog

The engine is composed of small, testable modules. Each focuses on a single concern and exposes a `run_tests()` helper so it can be loaded by the workspace or the headless test runner.

- **`grid_logic.gd`** – placeholder for future high‑level tactical rules; it currently just records log messages and reports a passing self‑test【F:scripts/modules/grid_logic.gd†L1-L18】.
- **`grid_visual_logic.gd`** – a `Node2D` that renders a grid using immediate drawing commands. Cell state can be a color or a custom callable, and dimensions are either set manually or derived from a `LogicGridMap` instance【F:scripts/modules/grid_visual_logic.gd†L1-L44】【F:scripts/modules/grid_visual_logic.gd†L50-L60】.
- **`turn_timespace.gd`** – the tactical round system. It tracks actors and objects on a `LogicGridMap`, emits signals as turns progress, and provides an action economy with validators and executors. A deterministic RNG ensures stable initiative ordering across runs【F:scripts/modules/turn_timespace.gd†L1-L66】【F:scripts/modules/turn_timespace.gd†L72-L99】.
- **`attributes.gd`** – central stats service. Base values and stacked modifiers are queried through `get_value(actor, key)` so gameplay code does not read raw fields directly【F:scripts/modules/attributes.gd†L1-L56】.
- **`statuses.gd`** – manages buffs, debuffs, and stances on actors. Each tick decrements durations and logs expirations when counters hit zero【F:scripts/modules/statuses.gd†L1-L35】.
- **`abilities.gd`** – minimal ability registry. It validates usage and logs execution without enforcing complex rules yet【F:scripts/modules/abilities.gd†L1-L24】.
- **`loadouts.gd`** – tracks which abilities an actor currently has access to; future revisions will filter by equipment or status effects【F:scripts/modules/loadouts.gd†L1-L24】.
- **`reactions.gd`** – simple interrupt queue for handling triggered responses such as overwatch shots. Entries are resolved FIFO【F:scripts/modules/reactions.gd†L1-L21】.
- **`event_bus.gd`** – append‑only store for structured events, intended for analytics or deterministic replays【F:scripts/modules/event_bus.gd†L1-L17】.

Modules are designed to work together: the `TurnBasedGridTimespace` orchestrates initiative and uses the `LogicGridMap` for movement, `Statuses` for ongoing effects, and `Abilities`/`Loadouts` to determine what actions a unit can perform. `Reactions` hooks into movement events emitted by `turn_timespace` while all modules can optionally push structured records to the shared `EventBus` for later analysis.
