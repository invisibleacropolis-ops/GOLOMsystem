# Developer Codebase Overview

This document provides an exhaustive cross-reference of the Golom tactical RPG project for outside engineers. It surveys every script and module, details their responsibilities, and highlights interactions between systems. The goal is to consolidate knowledge currently scattered across scripts and existing manuals, giving contributors a single reference point.

## Project Layout

The project follows a clear directory structure to organize its components:

```
res://scripts/
  core/                # bootstrapping scenes and base actor definition
  grid/                # grid-specific resources and interaction helpers
  modules/             # self-contained logic services
  tests/               # isolated scene tests
  test_runner.gd       # headless aggregate test harness
```

Visual assets and scenes live under `res://scenes/`, while comprehensive documentation, including API details and manuals, resides in `docs/`.

## Core Scripts (`scripts/core`)

These scripts handle the fundamental setup and management of the game's core entities and development environment.

### `base_actor.gd` - `BaseActor`

Defines the **BaseActor** class, a lightweight template for any creature or entity placed on the grid. It's designed to be extended by specific actor types (e.g., player, enemy, NPC).

*   **Key Data:** Stores essential gameplay data such as:
    *   `grid_pos`: Current position on the `LogicGridMap`.
    *   `facing`: Direction the actor is facing.
    *   `size`: Physical size on the grid (e.g., 1x1, 2x2).
    *   `faction`: A string identifying the actor's allegiance (e.g., "player", "enemy", "neutral").
    *   Gameplay stats: Health (`HLTH`), Chi (`CHI`), Action Points (`ACT`), Initiative (`INIT`), status flags, and core attributes (power, speed, focus, capacity, perception).
    *   Harvestable rewards: XP, loot, quest tokens, and script triggers.
*   **Utility:** The `describe()` helper method outputs a human-readable summary of the actor's state, useful for debugging.
*   **API Reference:** While `BaseActor` itself doesn't have a dedicated API HTML document, its properties are heavily utilized by modules like `Attributes` and `TurnBasedGridTimespace`.

### `workspace.gd` - `Workspace`

Implements an interactive **Workspace** scene, primarily used for loading modules and running their tests. This is a developer-facing tool to ensure module stability.

*   **Functionality:**
    *   Provides a GUI to list each module, its load status, pass/fail test result, and a button to view detailed logs.
    *   Supports command-line flags (`--module` / `--modules`) to restrict which modules load and run tests.
    *   Emits a `tests_completed` signal with a summary dictionary, allowing for automated reporting.
    *   Supports looping test execution for long-running stability checks.
    *   Includes a dedicated Map Generator tab that runs procedural world creation on a background thread, showing a pulsing progress bar and allowing export of the resulting color map.
*   **API Reference:** This is an internal tool, so it doesn't have a public API document.

### `workspace_debugger.gd`

A small utility script that logs workspace events and errors to `user://workspace_errors.log` for later inspection. Both informational and error messages funnel through its `_log()` method. This is crucial for diagnosing issues within the development environment.

### `grid_default_map.gd`

This script is responsible for setting up a default demo grid for testing and development.

*   **Functionality:**
    *   Loads a 32x32 demo grid.
    *   Instantiates three color-coded actors (green player, red enemy, blue NPC).
    *   Preloads the `RuntimeServices` aggregator (see below) and an optional `GridRealtimeRenderer` for visual debugging when a display is available.
    *   Actors are positioned using `TurnBasedGridTimespace.add_actor()` and rendered via `GridVisualLogic.set_cell_color()`.
*   **Interaction:** Demonstrates the initial setup and interaction with `RuntimeServices`, `TurnBasedGridTimespace`, and `GridVisualLogic`.

### `root.gd`

The primary entry point scene for the game.

*   **Functionality:**
    *   Instantiates the `Workspace` scene.
    *   Listens for the `Workspace`'s `tests_completed` signal.
    *   If all module tests pass, it proceeds to load `GridDefaultMap.tscn` to provide an interactive sandbox for gameplay.
    *   Can enable continuous background testing via `workspace.start_loop()`.

## Grid Utilities (`scripts/grid`)

These scripts provide the foundational logic for managing the game's grid-based world and interactions within it.

### `grid_map.gd` – `LogicGridMap`

The `LogicGridMap` is a critical `Resource` that encapsulates all tactical spatial logic for the game world. It's a data-driven representation of the grid, separate from its visual rendering.

*   **Key Responsibilities & API Highlights:**
    *   **Actor Placement:** Tracks occupied tiles (`occupied` member) and actor origins (`actor_positions` member).
        *   `move_actor(actor: Object, from_pos: Vector2i, to_pos: Vector2i) -> bool`: Validates and performs actor movement, handling multi-tile footprints.
        *   `remove_actor(actor: Object) -> void`: Clears an actor's entries from the map.
        *   `get_occupied_tiles() -> Array`: Returns all currently occupied tile positions.
        *   `get_all_actors() -> Array`: Returns all actors currently on the map.
    *   **Spatial Queries:**
        *   `is_in_bounds(pos: Vector2i) -> bool`: Checks if a position is within the grid boundaries.
        *   `is_occupied(pos: Vector2i) -> bool`: Checks if a tile is occupied by an actor.
        *   Distance helpers (`get_distance`, `get_chebyshev_distance`).
        *   `has_line_of_sight(from_pos: Vector2i, to_pos: Vector2i) -> bool`: Uses Bresenham's algorithm to check for unobstructed line of sight, considering LOS blockers and cover.
    *   **Range Queries:**
        *   `get_actors_in_radius(center: Vector2i, radius: int) -> Array`: Finds actors within a given radius.
        *   `get_positions_in_range(center: Vector2i, radius: int) -> Array`: Finds all positions within a given radius.
    *   **Pathfinding:**
        *   `find_path(start: Vector2i, end: Vector2i, actor: Object = null) -> Array`: Implements A* pathfinding, considering movement costs, turning penalties (`TURN_COST` constant), climb restrictions, and multi-tile actor support.
        *   `find_path_for_actor(actor: Object, start: Vector2i, end: Vector2i) -> Array`: A wrapper for `find_path` that uses the actor's size and facing.
    *   **Area-of-Effect (AoE) Shapes:** Provides methods for calculating tiles within various AoE shapes (burst, cone, line, wall) via `get_aoe_tiles()`.
    *   **Tactical Logic:** Supports zone-of-control projection (`get_zone_of_control`), flanking checks, cover handling, per-tile movement costs, and height levels.
    *   **Event Logging:** `log_event()` appends non-error messages for debugging.
*   **API Reference:** [LogicGridMap API Documentation](html/GridLogic.html) (Note: The API doc is named `GridLogic.html` but refers to the `LogicGridMap` class).

### `grid_interactor.gd` – `GridInteractor`

A `Node2D` script that translates mouse input into grid interactions, making the grid interactive for players or developers.

*   **Key Functionality & API Highlights:**
    *   **Input Handling:** Processes mouse clicks, drags, and selections on the grid.
    *   **Signals:** Emits various signals to notify other systems of interactions:
        *   `tile_clicked(pos: Vector2i)`
        *   `tiles_selected(positions: Array)`
        *   `actor_clicked(actor: Object)`
        *   `actors_selected(actors: Array)`
    *   **Features:** Includes drag-selection previews using `GridRealtimeRenderer`, modifier key bitmask helpers (Shift for adding to selection, Ctrl for toggling), and stateful drag handling to differentiate simple clicks from marquee selections.
*   **API Reference:** This is a UI-focused script and does not have a direct API HTML document, but it interacts heavily with `GridRealtimeRenderer`.
*   **Usage Details:** See `grid_interactor_manual.md` for usage details and signal wiring examples.

## Logic Modules (`scripts/modules`)

Each module in this directory is designed to be self-contained and loosely coupled, focusing on a specific domain of game logic. They typically expose a `run_tests()` method for headless verification, facilitating automated testing.

### Spatial & Timeline Modules

These modules manage the game's temporal and spatial state, beyond the basic grid structure.

*   **`turn_timespace.gd` - `TurnBasedGridTimespace`**
    *   **Purpose:** The central orchestrator for turn-based combat. It manages rounds, initiative order, action points (AP), reactions, status ticking, and serialization of the game state.
    *   **Key API:**
        *   `start_round()`, `end_turn()`: Control the flow of turns and rounds.
        *   `add_actor()`, `get_current_actor()`: Manage actors within the turn order.
        *   `register_action()`, `perform()`: Define and execute actions.
        *   Signals: `round_started`, `turn_started`, `ap_changed`, `action_performed`, `damage_applied`, etc., provide real-time updates to other systems.
    *   **Interaction:** Interacts heavily with `Statuses` (for ticking effects), `Abilities` (for executing actions), and `LogicGridMap` (for spatial updates). It also pushes events to the `EventBus`.
    *   **Testing:** Extensive self-tests cover initiative stability, AP spending, overwatch, status durations, serialization, and event log schema.
    *   **API Reference:** [TurnBasedGridTimespace API Documentation](html/TurnBasedGridTimespace.html)
    *   **Manual:** See `turn_timespace_manual.md` for more details.

*   **`grid_logic.gd`**
    *   **Purpose:** This module is currently a placeholder stub, primarily used for logging a self-test message. It is intended to house higher-level grid-related game logic that might not fit directly into `LogicGridMap`'s spatial management.
    *   **API Reference:** [GridLogic API Documentation](html/GridLogic.html)

*   **`grid_visual_logic.gd` - `GridVisualLogic`**
    *   **Purpose:** An immediate-mode renderer designed for debugging or minimal UI visualization of the grid. It allows for drawing colors or custom callables on individual cells.
    *   **Key API:**
        *   `set_grid_map()`, `set_grid_size()`: Configure the grid dimensions.
        *   `set_cell_state()`, `clear_cell_state()`, `update_cells()`: Control what is drawn on each cell.
        *   `log_event()`: For internal debugging.
    *   **Interaction:** Often used in conjunction with `LogicGridMap` to visualize its state.
    *   **API Reference:** [GridVisualLogic API Documentation](html/GridVisualLogic.html)

*   **`GridRealtimeRenderer.gd`**
    *   **Purpose:** A high-performance visual overlay for the grid, built on Godot's `MultiMeshInstance2D` for efficient rendering of many small elements. It's used for displaying complex visual feedback like fills, glyphs, strokes, and heatmaps.
    *   **Key API:**
        *   `set_ascii_entity()`, `clear_ascii_entities()`, `remove_ascii_actor()`: Manage ASCII character overlays.
        *   `begin_labels()`, `push_label()`, `end_labels()`: For rendering text labels on the grid.
        *   `apply_heatmap_auto()`, `apply_heatmap()`: Visualize numerical data as heatmaps.
        *   `set_mark()`, `set_stroke()`, `set_hatch()`: Draw various visual markers and patterns.
    *   **Interaction:** Used by `GridInteractor` for drag-selection previews and can be used by any module needing rich visual feedback on the grid.
    *   **API Reference:** [GridRealtimeRenderer API Documentation](html/GridRealtimeRenderer.html)

### Actor Data & Effects Modules

These modules manage the attributes, status effects, abilities, and reactions of actors within the game.

*   **`attributes.gd` - `Attributes`**
    *   **Purpose:** Centralizes all numeric statistics for actors. It handles base values, additive, multiplicative, and percentage modifiers, and ensures values are clamped within defined ranges.
    *   **Key API:**
        *   `set_base()`, `add_modifier()`, `clear_modifiers()`: Manage attribute values and their modifications.
        *   `get_value()`: **The primary method to query an actor's final attribute value**, considering all modifiers and ranges.
        *   `set_range()`: Defines min/max bounds for attributes.
    *   **Interaction:** Heavily used by `Abilities` (for cost checks) and `Statuses` (for applying attribute-modifying effects).
    *   **API Reference:** [Attributes API Documentation](html/Attributes.html)
    *   **Manual:** See `attributes_manual.md` for more details.

*   **`statuses.gd` - `Statuses`**
    *   **Purpose:** Tracks and manages buffs/debuffs and other temporary status effects on actors and tiles, including their stacks and durations.
    *   **Key API:**
        *   `apply_status()`: Applies a new status effect.
        *   `tick()`: Decrements durations of all active statuses and removes expired ones.
        *   Signals: `status_applied`, `status_removed` notify other systems of changes.
    *   **Interaction:** `TurnBasedGridTimespace` calls `tick()` on `Statuses`. `Statuses` interacts with `Attributes` to apply the numerical effects of statuses.
    *   **API Reference:** [Statuses API Documentation](html/Statuses.html)
    *   **Manual:** See `statuses_manual.md` for more details.

*   **`abilities.gd` - `Abilities`**
    *   **Purpose:** Registers ability definitions, validates if an actor can use an ability, and executes the ability's logic.
    *   **Key API:**
        *   `register_ability()`, `load_from_file()`: Define and load abilities.
        *   `can_use()`: Checks if an ability can be used (integrates with `Attributes` for cost checks).
        *   `execute()`: Runs the ability's effects.
        *   `tick_cooldowns()`: Manages ability cooldowns.
    *   **Interaction:** `Loadouts` determines which abilities are available. `Abilities` uses `Attributes` for resource management and `TurnBasedGridTimespace` for event logging and signaling.
    *   **API Reference:** [Abilities API Documentation](html/Abilities.html)
    *   **Manual:** See `abilities_manual.md` for more details.

*   **`loadouts.gd` - `Loadouts`**
    *   **Purpose:** Computes and manages the set of abilities available to a specific actor, potentially based on equipped items, class, or active status effects.
    *   **Key API:**
        *   `grant()`: Grants a specific ability ID to an actor.
        *   `get_available()`: Returns a list of all abilities an actor currently has access to.
    *   **Interaction:** Primarily queried by UI systems or `TurnBasedGridTimespace` to determine an actor's available actions.
    *   **API Reference:** [Loadouts API Documentation](html/Loadouts.html)
    *   **Manual:** See `loadouts_manual.md` for more details.

*   **`reactions.gd` - `Reactions`**
    *   **Purpose:** Queues and resolves reactive opportunities (e.g., attacks of opportunity, counter-spells) in a First-In, First-Out (FIFO) order.
    *   **Key API:**
        *   `trigger()`: Adds a reaction to the queue.
        *   `resolve_next()`: Processes the next reaction in the queue.
        *   `get_pending()`: Returns the list of reactions awaiting resolution.
    *   **Interaction:** `TurnBasedGridTimespace` can trigger reactions based on game events (e.g., movement into line of sight).
    *   **API Reference:** [Reactions API Documentation](html/Reactions.html)
    *   **Manual:** See `reactions_manual.md` for more details.

*   **`event_bus.gd` - `EventBus`**
    *   **Purpose:** An append-only, structured log for all significant game events. It's fundamental for analytics, debugging, and enabling deterministic replays of game sessions.
    *   **Key API:**
        *   `push()`: Adds an event dictionary to the log.
        *   `serialize()`, `replay()`: For saving and loading event logs.
    *   **Interaction:** Almost all other modules push events to the `EventBus` to maintain a comprehensive record of game state changes.
    *   **API Reference:** [EventBus API Documentation](html/EventBus.html)
    *   **Manual:** See `event_bus_manual.md` for more details.

### Integration Layer

This module acts as a central point for wiring together the core logic services.

*   **`runtime_services.gd` - `RuntimeServices`**
    *   **Purpose:** Aggregates all core logic modules (e.g., `LogicGridMap`, `TurnBasedGridTimespace`, `Attributes`, `Statuses`, `Abilities`, `Loadouts`, `Reactions`, `EventBus`) into a single `Node`. This provides a convenient single entry point for gameplay scenes to access the entire backend logic state.
    *   **Key API:** Its members are direct references to instances of the other core modules (e.g., `runtime_services.grid_map`, `runtime_services.timespace`).
    *   **Interaction:** On `_init`, it wires `TurnBasedGridTimespace` to a `LogicGridMap` and sets up cross-module references. Its `run_tests()` method performs a minimal integration test and then executes each aggregated module's self-tests, aggregating results for CI.
    *   **API Reference:** [RuntimeServices API Documentation](html/RuntimeServices.html)

## UI Components

These scripts are responsible for displaying game information and handling player input.

*   **`variable_display.gd` - `VariableDisplay`**
    *   **Purpose:** A panel script typically attached to `scenes/MainHUD.tscn`. It subscribes to `RuntimeServices` signals to display real-time game information (e.g., current round, active actor).
    *   **Key API:** Allows modules to register custom stats via `register_stat()` with optional formatting helpers, making it flexible for displaying various game data.
    *   **Interaction:** Listens to signals from `RuntimeServices` and its aggregated modules to update the UI.

## Tests

The project includes a robust testing framework to ensure the stability and correctness of its modules.

*   **`scripts/test_runner.gd`**
    *   **Purpose:** The main headless test harness. It iterates over module instances, calls their `run_tests()` methods, prints pass/fail summaries, and exits with the number of failures.
    *   **Best Practice:** Each module is designed to free temporary objects to avoid memory leaks during testing.
*   **`scripts/tests/grid_visual_logic_test.gd`**
    *   **Purpose:** Provides a small SceneTree specifically for testing `GridVisualLogic`. It instantiates the visual logic module and exercises its color and callable drawing paths to ensure visual correctness.

## Documentation

Existing manuals in `docs/` describe individual modules in more detail. This overview ties them together and highlights additional scripts (like `Workspace`, `GridInteractor`, `BaseActor`) that are crucial for understanding the project's structure and development workflow. Refer to the specific manual for in-depth API usage and examples for each module.