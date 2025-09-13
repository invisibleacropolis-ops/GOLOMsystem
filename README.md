# Golom: Tactical RPG Engine

This repository contains a Godot 4 project exploring tactical grid mechanics for a future role-playing game. The engine is designed with modularity and testability in mind, providing a robust foundation for complex turn-based combat. This document serves as the **Full Volume Operations Manual for the Current State of the Engine**, specifically tailored for beginner engineers joining the project. It synthesizes all available documentation to give you a comprehensive understanding of how Golom works, how its components interact, and how you can contribute.

## Agent Operations (Read First)

This repo is set up so an AI agent can launch and drive Godot itself using the wrappers under `scripts/`. See `docs/OPERATIONS.md` for the exact flows (open editor, headless tests, ASCII runs), configuration resolution, and logging. Quick launch: `scripts/open_editor.sh` (Linux/WSL) or `scripts/open_editor.ps1` / `scripts/open_editor.cmd` (Windows).

### Docs Index
- `INSTRUCTIONS` — Runner details and flows (read with the Operations doc).
- `docs/OPERATIONS.md` — Agent-led ops model and wrapper usage (Read First).
- `docs/INTERNAL_DEBUGGER.md` — Internal ErrorHub / WorkspaceDebugger / ErrorOverlay.
- `LogicGridMap (GDScript) — README.md` — Legacy gridmap API notes.

## For Beginner Engineers: Your Operations Manual

Welcome to the Golom project! This section is your go-to guide for understanding the engine's architecture, its core components, and how to get started with development.

### Getting Started

To begin working with the Golom engine, you'll need the following:

*   **Godot 4.4.1:** This specific version of the Godot Engine is required. You can download it from the official Godot website.
*   **Godot Executable in PATH:** For headless test execution and tooling, the `godot4` binary should be available in your system's PATH.
*   **Configuration:**
	*   Copy `scripts/godot4-config.example.json` to `scripts/godot4-config.json`.
	*   Edit `scripts/godot4-config.json` and set the `win_exe` field to the absolute path of your Godot 4 executable for Windows (e.g., `F:\AIstuff\FILES-FOR-MODELS\Godot_v4.4.1-stable_win64.exe`).
	*   If you are using Windows Subsystem for Linux (WSL) or a Linux environment, also set `wsl_exe` to the path of your Linux Godot executable.
	*   **Optional Environment Variables:** Alternatively, you can set environment variables: `GODOT4_WIN_EXE`, `GODOT4_LINUX_EXE`, and `GODOT4_MODE` (set to `auto`, `wsl`, or `win`). These will override settings in `godot4-config.json`.
	*   **Optional Bash/WSL Environment:** For bash/WSL users, copy `scripts/godot4.env.example` to `scripts/godot4.env` and edit it.

### Project Structure

Understanding the project's directory layout is fundamental to navigating the codebase:

*   `project.godot`: The core project configuration file for Godot.
*   `scenes/`: Contains all Godot scene files.
	*   `Workspace.tscn`: Launches logic modules and provides a GUI for running tests.
	*   `TestGrid.tscn`: Runs the grid test harness.
	*   `Root.tscn`: The main entry point scene for the game, which boots into a procedurally generated map.
*   `scripts/core/`: Infrastructure scripts for bootstrapping and logging.
	*   `base_actor.gd`: Defines the `BaseActor` class, a template for all grid entities.
	*   `workspace.gd`: Implements the `Workspace` scene logic.
	*   `workspace_debugger.gd`: Utility for logging workspace events.
	*   `grid_default_map.gd`: Sets up a default demo grid for testing.
	*   `root.gd`: The primary entry point script for the game.
*   `scripts/grid/`: Core gameplay scripts related to the grid.
	*   `grid_map.gd`: Implements the `LogicGridMap`, the authoritative source for tactical rules and spatial data.
	*   `grid_interactor.gd`: Translates mouse input into grid interactions.
*   `scripts/modules/`: Self-contained, pluggable feature modules that encapsulate specific game logic.
	*   `abilities.gd`: Manages in-game abilities.
	*   `attributes.gd`: Centralizes numeric statistics for actors.
	*   `event_bus.gd`: Provides an append-only log of game events.
	*   `GridRealtimeRenderer.gd`: High-performance visual overlay renderer.
	*   `grid_logic.gd`: Coordinates high-level tactical queries (currently a placeholder).
	*   `grid_visual_logic.gd`: Immediate-mode renderer for debugging or minimal UI.
	*   `loadouts.gd`: Determines which abilities an actor can access.
	*   `map_generator.gd`: Orchestrates procedural grid creation.
	*   `procedural_map_generator.gd`: Builds `LogicGridMap` instances from noise.
	*   `procedural_world.gd`: Generates `LogicGridMap` instances by sampling noise data.
	*   `reactions.gd`: Queues interrupt abilities.
	*   `runtime_services.gd`: Aggregates all core logic modules.
	*   `statuses.gd`: Manages buffs, debuffs, and stances.
	*   `terrain.gd`: Centralizes terrain type definitions.
	*   `turn_timespace.gd`: Orchestrates the tactical timeline (turn manager).
*   `scripts/tests/`: Isolated scene tests for individual modules.
*   `scripts/tools/`: Utility scripts for headless operations.
	*   `ascii_console.gd`: Provides a command-line interface for headless inspection.
*   `scripts/test_runner.gd`: Headless aggregate test harness.
*   `docs/`: Comprehensive documentation, including API details and manuals.
*   `data/`: Data files (e.g., `actions.json`, `terrain.json`).
*   `addons/`: Godot addons, including `tile_to_gridmap`.
*   `tilesets/`: Godot TileSet resources.
*   `Taoist Player's Handbook.docx`, `Taoist-GMguide.docx`, `Taoist Monsters & Treasure.docx`: Design documents defining the tabletop RPG that this engine will eventually implement.

### Core Concepts: The Building Blocks of Golom

Golom's game logic is built upon several interconnected modules, each specializing in a core aspect of the game. Understanding these modules and their APIs is key to building and extending the game.

*   **`LogicGridMap`**
	*   **Purpose:** This module (`scripts/grid/grid_map.gd`) is the pure data container for all spatial information in the game world. It handles grid coordinates, terrain tags, and the physical presence of actors. It's the foundation for anything that needs to know about "where" things are.
	*   **Key API Role:** Provides methods for spatial queries (e.g., `is_in_bounds()`, `is_occupied()`), pathfinding (`find_path()`), and line of sight (`has_line_of_sight()`). It doesn't handle visual rendering directly but provides the data for it.
	*   **Why it's separate:** By separating spatial data from visual representation, the game can run headless (without graphics) for testing or server-side logic, and allows for flexible visual layers.
	*   **Further Reading:** [LogicGridMap API Documentation](docs/html/GridLogic.html), [Grid Map Manual](docs/grid_map_manual.md)

*   **`TurnBasedGridTimespace`**
	*   **Purpose:** This module (`scripts/modules/turn_timespace.gd`) acts as the central state machine for turn-based combat. It orchestrates the flow of rounds and turns, manages action points (AP), and handles the initiative order of all actors.
	*   **Key API Role:** Methods like `start_round()` and `end_turn()` drive the game's temporal progression. It manages actor AP and triggers status effect processing. It also emits crucial signals like `round_started`, `turn_started`, and `ap_changed` to notify other systems of game state changes.
	*   **Why it's central:** By centralizing turn management, the game ensures consistent application of rules and provides clear points for other modules (like UI or AI) to synchronize with the game's flow.
	*   **Further Reading:** [TurnBasedGridTimespace API Documentation](docs/html/TurnBasedGridTimespace.html), [Turn Timespace Manual](docs/turn_timespace_manual.md)

*   **`Attributes`**
	*   **Purpose:** This module (`scripts/modules/attributes.gd`) is the central authority for all numeric statistics (attributes) of actors. It handles base values, applies various types of modifiers (additive, multiplicative, percentage), and enforces clamped ranges.
	*   **Key API Role:** The `get_value(actor, key)` method is paramount; **all systems must query attribute values through this method** to ensure modifiers and ranges are correctly applied. Methods like `set_base()` and `add_modifier()` allow for dynamic changes to attributes.
	*   **Why it's centralized:** Funneling all attribute reads and modifications through this single service ensures consistency, prevents bugs from direct field manipulation, and makes auditing attribute calculations much easier.
	*   **Further Reading:** [Attributes API Documentation](docs/html/Attributes.html), [Attributes Manual](docs/attributes_manual.md)

*   **`Statuses`**
	*   **Purpose:** This module (`scripts/modules/statuses.gd`) manages temporary or persistent status effects (buffs and debuffs) applied to actors or even specific tiles.
	*   **Key API Role:** `apply_status()` adds effects, and `tick()` (called by `TurnBasedGridTimespace`) reduces durations and purges expired statuses. Signals like `status_applied` and `status_removed` inform other modules of changes.
	*   **Why it's separate:** Isolating status effect logic simplifies their management, allowing for complex interactions without cluttering actor definitions. It also ensures consistent application and removal of effects.
	*   **Further Reading:** [Statuses API Documentation](docs/html/Statuses.html), [Statuses Manual](docs/statuses_manual.md)

*   **`Abilities` & `Loadouts`**
	*   **Purpose:**
		*   **`Abilities`** (`scripts/modules/abilities.gd`): Defines, validates, and executes active abilities. It handles resource costs, cooldowns, and the core logic of what an ability does.
		*   **`Loadouts`** (`scripts/modules/loadouts.gd`): Determines which abilities an actor currently has access to, based on factors like equipment, class, or active status effects.
	*   **Key API Role:** `Abilities.can_use()` checks if an actor meets the requirements (e.g., AP, cooldowns via `Attributes`). `Abilities.execute()` performs the ability. `Loadouts.get_available()` provides the list of usable abilities to UI or AI.
	*   **Why they work together:** `Loadouts` acts as a filter or grant system for `Abilities`. This separation allows designers to easily define new abilities and then control their availability to different actors without modifying core ability logic.
	*   **Further Reading:** [Abilities API Documentation](docs/html/Abilities.html), [Loadouts API Documentation](docs/html/Loadouts.html), [Abilities Manual](docs/abilities_manual.md), [Loadouts Manual](docs/loadouts_manual.md)

*   **`Reactions`**
	*   **Purpose:** This module (`scripts/modules/reactions.gd`) provides a lightweight interrupt system for "opportunity actions" or reactions that occur in response to specific game events (e.g., an attack of opportunity when an enemy moves into range).
	*   **Key API Role:** `trigger()` queues a reaction, and `resolve_next()` processes the next one.
	*   **Why it's separate:** It allows for complex reactive behaviors without tightly coupling them into the main turn sequence, making the game logic more flexible and extensible.
	*   **Further Reading:** [Reactions API Documentation](docs/html/Reactions.html), [Reactions Manual](docs/reactions_manual.md)

*   **`EventBus`**
	*   **Purpose:** This module (`scripts/modules/event_bus.gd`) is an append-only log that captures every significant state change or event in the game.
	*   **Key API Role:** `push(evt)` is used by all other modules to record structured event dictionaries. `serialize()` and `replay()` enable saving, loading, and replaying game sessions deterministically.
	*   **Why it's crucial:** It's fundamental for debugging (seeing the exact sequence of events), analytics (collecting data on gameplay), and enabling deterministic replays (recreating a game session exactly as it happened).
	*   **Further Reading:** [EventBus API Documentation](docs/html/EventBus.html), [Event Bus Manual](docs/event_bus_manual.md)

*   **`GridVisualLogic`**
	*   **Purpose:** This module (`scripts/modules/grid_visual_logic.gd`) is an immediate-mode renderer primarily used for debugging grid state or powering a minimal UI. It allows developers to draw colors or custom shapes directly onto grid cells.
	*   **Key API Role:** `set_cell_state()` and `update_cells()` allow for dynamic visual feedback on the grid.
	*   **Why it's separate:** It provides a quick and easy way to visualize the underlying `LogicGridMap` data without needing complex 3D models or extensive UI setup, making debugging much faster.
	*   **Further Reading:** [GridVisualLogic API Documentation](docs/html/GridVisualLogic.html), [Grid Visual Logic Manual](docs/grid_visual_logic.md)

*   **`GridRealtimeRenderer`**
	*   **Purpose:** This module (`scripts/modules/GridRealtimeRenderer.gd`) is a high-performance visual overlay renderer built on Godot's `MultiMeshInstance2D` for efficient rendering of many small elements. It's used for displaying complex visual feedback like fills, glyphs, strokes, heatmaps, and ASCII output.
	*   **Key API Role:** Provides methods for `set_cell_color()`, `apply_heatmap()`, `set_mark()`, `set_stroke()`, and `generate_ascii_field()`. It also supports GPU-accelerated labels.
	*   **Why it's efficient:** Its batching capabilities make it ideal for dynamic visual feedback without performance bottlenecks.
	*   **Further Reading:** [GridRealtimeRenderer API Documentation](docs/html/GridRealtimeRenderer.html), [GridRealtimeRenderer Manual](docs/grid_realtime_renderer_manual.md)

*   **`MapGenerator`**
	*   **Purpose:** This module (`scripts/modules/map_generator.gd`) orchestrates the creation of procedural grids and acts as a crucial bridge between the game's core logic and the [Tile to Gridmap](https://github.com/godotengine/godot-tile-to-gridmap-addon) addon.
	*   **Key API Role:** Its `build()` method combines `ProceduralMapGenerator` output with `TileSet` and `terrain_atlas` data to produce a `LogicGridMap`, a 3D `GridMap`, a `GridRealtimeRenderer`, and a `TileToGridMapBridge`.
	*   **Why it's an orchestrator:** It simplifies the complex process of generating a game world from abstract parameters, handling both logical and visual aspects.
	*   **Further Reading:** [MapGenerator API Documentation](docs/html/MapGenerator.html), [Map Generator Manual](docs/map_generator_manual.md)

*   **`ProceduralMapGenerator`**
	*   **Purpose:** This module (`scripts/modules/procedural_map_generator.gd`) is responsible for building `LogicGridMap` instances from simple noise algorithms and string-based presets.
	*   **Key API Role:** Its `generate()` method creates a `LogicGridMap` based on `width`, `height`, `seed`, and `terrain` parameters, populating it with terrain tags and optionally carving roads.
	*   **Why it's data-driven:** Allows engineers to quickly produce deterministic grid layouts for prototyping, testing, or even full game levels without the need for manual tile authoring.
	*   **Further Reading:** [ProceduralMapGenerator API Documentation](docs/html/ProceduralMapGenerator.html), [Procedural Map Manual](docs/procedural_map_manual.md)

*   **`ProceduralWorld`**
	*   **Purpose:** This module (`scripts/modules/procedural_world.gd`) builds `LogicGridMap` instances by sampling noise data, typically from `FastNoiseLiteDatasource` scripts.
	*   **Key API Role:** Its `generate()` method returns both the generated `LogicGridMap` and a color array suitable for visualization with `GridRealtimeRenderer`.
	*   **Why it's flexible:** Provides a way to create diverse and procedurally generated game worlds based on configurable noise functions.
	*   **Further Reading:** [ProceduralWorld API Documentation](docs/html/ProceduralWorld.html), [Procedural World Manual](docs/procedural_world_manual.md)

*   **`Terrain`**
	*   **Purpose:** This module (`scripts/modules/terrain.gd`) centralizes terrain type definitions used by `LogicGridMap`. It loads default rules from `data/terrain.json` and allows runtime modification.
	*   **Key API Role:** `register_type()` adds new terrain definitions, `set_property()` mutates existing ones, and `apply_to_map()` updates `LogicGridMap` tiles with terrain properties (movement costs, LOS blockers, tags).
	*   **Why it's centralized:** Ensures consistency across the game world and allows for easy modification and extension of terrain properties.
	*   **Further Reading:** [Terrain API Documentation](docs/html/Terrain.html), [Terrain Manual](docs/terrain_manual.md)

*   **`RuntimeServices`**
	*   **Purpose:** This module (`scripts/modules/runtime_services.gd`) acts as an aggregator, bringing together all the core logic modules into a single `Node`. This provides a convenient single entry point for gameplay scenes to access all backend services.
	*   **Key API Role:** Its members are direct references to instances of the other core modules (e.g., `services.grid_map`, `services.timespace`). It handles the initial wiring of these modules.
	*   **Why it's an aggregator:** Simplifies setup and access to the entire backend logic state, reducing boilerplate code in gameplay scenes.
	*   **Further Reading:** [RuntimeServices API Documentation](docs/html/RuntimeServices.html), [Runtime Service Overview](docs/runtime_services.md)

### Execution Flow: A Turn in Action

Understanding how these modules interact during a typical game turn is essential. The `TurnBasedGridTimespace` module acts as the central coordinator.

1.  **Round Start:** `TurnBasedGridTimespace.start_round()` is called. This resets each actor's action points and emits the `round_started` signal. It also triggers `Statuses.tick()` to process any round-start effects.
2.  **Turn Begins:** `TurnBasedGridTimespace` initiates an actor's turn, emitting the `turn_started` signal and applying any `turn_start` statuses via the `Statuses` module.
3.  **Ability Selection:** External logic (e.g., player UI) queries `Loadouts.get_available()` to see what abilities an actor has. For each ability, `Abilities.can_use()` is called, which consults `Attributes.get_value()` to check for sufficient resources and cooldowns.
4.  **Action Execution:** When an action is performed (e.g., movement, ability use), `TurnBasedGridTimespace` handles AP expenditure. Movement actions delegate to `LogicGridMap.move_actor()` for spatial updates. Successful actions emit `action_performed` and `ap_changed` signals. If an ability is used, `Abilities.execute()` is called.
5.  **Reactions:** After certain actions (like movement), `TurnBasedGridTimespace` might check for reactions (e.g., using `LogicGridMap.has_line_of_sight()`). If a reaction is triggered, the `Reactions` module is notified to queue and resolve it.
6.  **Status Handling:** Throughout the turn, abilities or other game effects can call `TurnBasedGridTimespace.apply_status_to_actor()`, which interacts with the `Statuses` module. `Statuses` emits `status_applied` and `status_removed` signals as effects begin or end.
7.  **Event Logging:** Crucially, at each significant step, modules push structured event dictionaries to the `EventBus` using its `push()` method. This creates a complete, chronological record of the game state.
8.  **Turn End:** `TurnBasedGridTimespace.end_turn()` is called, emitting `turn_ended`, processing `turn_end` statuses, and advancing to the next actor or ending the round.

This coordinated dance of method calls and signals ensures that all game logic is processed consistently and that other systems can react appropriately.

### Headless Tooling & Testing

The Golom project is designed to support headless execution, which is invaluable for automated testing, continuous integration (CI), documentation generation, and even playing the game in a text-based (ASCII) console.

*   **Unified Runner (`godot4` scripts):** The `godot4.ps1` (PowerShell for Windows) and `godot4.sh` (bash for Linux/WSL) scripts provide a unified way to invoke the Godot executable with various arguments. They abstract away platform-specific paths and commands.
*   **Doctool XML Generation:** The `scripts/doc_regen.ps1` / `scripts/doc_regen.sh` scripts automate the generation of XML API documentation from GDScript files, which are then converted to HTML.
*   **Headless Test Runner (`scripts/test_runner.gd`):** This is the main headless test harness. It iterates over module instances, calls their `run_tests()` methods, prints pass/fail summaries, and exits with the number of failures.
	*   **Command:** `godot4 --headless --path . --script scripts/test_runner.gd`
*   **Tests + ASCII Smoke Test:** The `scripts/run_headless.ps1 -Strict` script runs the full suite of module tests and then initiates an ASCII smoke test of the game, leveraging `GridRealtimeRenderer` for console output.
*   **Headless ASCII Mode:** The engine can render the tactical grid directly in the terminal. This is powered by `GridRealtimeRenderer`'s ASCII output capabilities (`generate_ascii_field()`, `ascii_update_sec`, `ascii_use_color`). You can interact with it using `w`, `a`, `s`, `d` for movement and `quit` to exit.
	*   **Interactive Play:** `pwsh -File scripts/ascii_play.ps1`
	*   **Piped (Non-Interactive):** `PIPE=1 bash scripts/ascii_play.sh < logs/ascii_commands.txt`
*   **ASCII Headless Console (`scripts/tools/ascii_console.gd`):** Provides a minimal command-line interface for inspecting the project without a windowed display.
	*   **Command:** `godot4 --headless --path . --script scripts/tools/ascii_console.gd`
	*   **Commands within console:** `spawn NAME X Y`, `move_actor NAME X Y`, `list`, `select X Y`, `move X Y`, `target X Y`, `click X Y`, `clear`, `quit`.
*   **Workspace Launcher (`scripts/core/workspace.gd`):** Powers `scenes/Workspace.tscn`. When executed headlessly, it can load one or more logic modules and report their self-test results.
	*   **Example:** `godot4 --headless --path . -- --modules grid_logic,other_module`
*   **Running Grid Tests:** The comprehensive grid test suite lives in `scenes/TestGrid.tscn` and is driven by the `test_grid.gd` script. It instantiates `LogicGridMap` and runs scenario tests covering movement, pathfinding, line-of-sight, and more.
	*   **Command:** `godot4 --headless --path . scenes/TestGrid.tscn`
*   **Logs:** All generated logs and output from headless operations are typically stored under the `logs/` directory.

### Integration Tips for Developers

*   **Treat Modules as Services:** Think of each module (e.g., `Attributes`, `Statuses`) as a self-contained service. Instantiate the ones you need and inject them into your game scenes or other modules. This promotes modularity and reusability.
*   **Leverage Signals for Loose Coupling:** Use Godot's signals (`turn_started`, `ap_changed`, `status_applied`, etc.) extensively. This is the primary mechanism for modules to communicate without directly knowing about each other's internal implementations. This keeps UI and AI layers loosely coupled from the core game logic.
*   **Run Module Self-Tests Frequently:** The `scripts/test_runner.gd` script is your best friend. Run it often with `godot4 --headless --path . --script scripts/test_runner.gd` to ensure deterministic behavior across platforms and to catch regressions early. Each module's `run_tests()` method provides a quick way to verify its functionality.
*   **Minimal Public APIs, Data-Driven Rules:** When extending modules or adding new features, strive to keep public APIs minimal and well-defined. Prefer using data-driven dictionaries for new rules (e.g., ability definitions, status effects) rather than hardcoding them into scripts. This allows designers to iterate on gameplay without requiring code changes.
*   **Resource Management in Tests:** When running headless tests, always ensure that you explicitly free instantiated modules (e.g., `services.free()`) to prevent memory leaks, especially for `Node`s.
*   **`timespace.set_grid_map()`:** It is crucial that `timespace.set_grid_map()` is invoked before starting the timespace (e.g., `timespace.start_round()`). `RuntimeServices` handles this internally during its `_ready()` method, but if you are setting up modules manually, you must call it explicitly to link the turn manager to the game grid.
*   **Consult Specific Manuals:** This overview provides a map. For in-depth API usage, examples, and specific implementation details for each module, refer to its dedicated manual in the `docs/` folder and its corresponding HTML API documentation in `docs/html/`.

## Outline for the Future: Towards an XCOM-Style Battle Mode Vertical Slice

The current Golom engine provides a strong foundation for turn-based tactical combat. The next major milestone is to develop a "Vertical Slice" of an XCOM-style battle mode. A vertical slice is a fully playable, but limited, section of the game that demonstrates core gameplay mechanics and visual fidelity.

### Vision for the Vertical Slice

The vertical slice will focus on a single, small tactical encounter: a player-controlled squad of 2-3 units against a small group of 2-3 AI-controlled enemies on a procedurally generated map. The goal is to demonstrate the core loop of movement, attacking, cover, and basic AI decision-making.

### Key Features to Implement for the Vertical Slice

Here's a breakdown of the features needed and how existing engine components will be leveraged or extended:

1.  **Player Squad Management & UI:**
	*   **Goal:** Allow the player to select and control multiple units. Display unit health, action points, and available abilities.
	*   **Leveraging Existing:**
		*   `BaseActor`: Will be extended for player-controlled units with specific stats.
		*   `RuntimeServices`: Will provide access to `Attributes` (for health/AP display), `Loadouts` (for available abilities), and `TurnBasedGridTimespace` (for current actor).
		*   `GridInteractor`: For selecting units and target tiles.
		*   `GridRealtimeRenderer`: For highlighting selected units, movement paths, and target areas.
	*   **New Development:** Basic UI elements (unit portraits, health bars, AP indicators, ability hotbar) and input handling for switching between units.

2.  **Basic Combat Loop (Player Turn -> Enemy Turn):**
	*   **Goal:** Implement the fundamental turn order between player and enemy factions.
	*   **Leveraging Existing:**
		*   `TurnBasedGridTimespace`: Already handles `start_round()`, `end_turn()`, `get_current_actor()`, and emits `turn_started`/`turn_ended` signals. This is the core of the turn management.
		*   `EventBus`: Will log all turn-based events for debugging and analysis.
	*   **New Development:** Logic to switch control between player input and AI decision-making based on `TurnBasedGridTimespace` signals.

3.  **Movement & Action System:**
	*   **Goal:** Allow players to move units on the grid, visualize movement ranges, and execute basic actions (e.g., attack).
	*   **Leveraging Existing:**
		*   `LogicGridMap`: For pathfinding (`find_path()`), checking valid moves (`can_move()`), and spatial queries.
		*   `TurnBasedGridTimespace`: For `perform()`ing move actions and deducting AP.
		*   `GridRealtimeRenderer`: For visualizing movement ranges (e.g., using `set_cell_color()` or `apply_heatmap()`) and selected paths (`stroke_outline_for()`).
		*   `Abilities`: For defining and executing basic attack abilities.
		*   `Loadouts`: To determine which movement/attack abilities are available.
	*   **New Development:** UI for displaying movement range, confirming moves, and selecting attack targets.

4.  **Cover System:**
	*   **Goal:** Implement tactical cover (e.g., half cover, full cover) that provides defensive bonuses.
	*   **Leveraging Existing:**
		*   `LogicGridMap`: Already supports `set_cover()` and `get_cover()`. This will be used to define cover properties on tiles.
		*   `Attributes`: Will be used to apply defensive modifiers (e.g., `add_modifier()` for defense bonus) based on cover.
		*   `TurnBasedGridTimespace`: Will need to integrate cover checks into combat calculations (e.g., when an attack is performed).
	*   **New Development:** Visual representation of cover (e.g., different tile visuals, UI indicators).

5.  **Line of Sight (LOS):**
	*   **Goal:** Implement clear line of sight rules for attacks and abilities.
	*   **Leveraging Existing:**
		*   `LogicGridMap`: Already has `has_line_of_sight()` and `set_los_blocker()`. This is the core LOS calculation.
		*   `GridRealtimeRenderer`: Can be used to visualize LOS for selected units.
	*   **New Development:** UI to show valid attack targets based on LOS.

6.  **Basic Enemy AI:**
	*   **Goal:** Implement simple AI for enemy units (e.g., move to cover, attack closest player unit).
	*   **Leveraging Existing:**
		*   `TurnBasedGridTimespace`: Will provide the AI with the current actor's turn.
		*   `LogicGridMap`: For pathfinding to cover, finding closest targets (`get_actors_in_radius()`), and checking LOS.
		*   `Attributes`: To query enemy stats.
		*   `Abilities`: To execute enemy attacks.
		*   `Reactions`: To handle basic enemy reactions (e.g., overwatch).
	*   **New Development:** A dedicated AI module or script for enemy decision-making, integrating with the existing game logic.

7.  **Ability Integration (Basic Attack & One Special Ability):**
	*   **Goal:** Implement a basic ranged/melee attack and one unique special ability per unit type.
	*   **Leveraging Existing:**
		*   `Abilities`: For `register_ability()`, `can_use()`, `execute()`, and `tick_cooldowns()`.
		*   `Attributes`: For managing resource costs (AP, Chi) and damage calculations.
		*   `Loadouts`: To grant abilities to specific units.
		*   `EventBus`: To log ability usage.
	*   **New Development:** Data definitions for abilities (in `data/actions.json`), visual effects for abilities (e.g., simple particle systems, animations).

8.  **Win/Loss Conditions:**
	*   **Goal:** Define simple objectives for the battle (e.g., eliminate all enemies, reach an exit point).
	*   **Leveraging Existing:**
		*   `TurnBasedGridTimespace`: Can emit `battle_over` signal.
		*   `LogicGridMap`: To check if units reach specific tiles.
	*   **New Development:** Game state manager to track objectives and trigger win/loss screens.

### Areas for Expansion/New Development

Beyond the vertical slice, these are areas that will require significant future work:

*   **Advanced AI:** More sophisticated enemy behaviors, tactical decision-making, squad AI.
*   **Comprehensive UI Framework:** Full-fledged UI for menus, inventory, character customization, mission briefings, etc.
*   **Visual Effects & Animations:** Richer particle effects, character animations, hit reactions, environmental destruction.
*   **Sound & Music System:** Integration of sound effects and background music.
*   **Save/Load System:** Persistence of game state beyond a single battle.
*   **Campaign Layer:** Strategic map, base management, research, soldier progression (XCOM-style meta-game).
*   **Multiplayer:** Networked play for tactical battles.
*   **Content Pipeline:** Tools and workflows for artists and designers to create new units, abilities, maps, and items efficiently.
*   **Modding Support:** Design for extensibility and community content creation.

### Milestones/Phases for Vertical Slice Development

A rough breakdown of development phases for the XCOM-style battle mode vertical slice:

1.  **Phase 1: Core Grid & Movement (2-4 weeks)**
	*   Implement basic `LogicGridMap` setup with terrain.
	*   Player unit movement with pathfinding visualization (`GridRealtimeRenderer`).
	*   Basic turn switching (player -> enemy -> player).
	*   Simple win/loss (e.g., player unit reaches exit).
	*   Automated tests for movement and turn order.

2.  **Phase 2: Basic Combat & Cover (3-5 weeks)**
	*   Implement basic attack ability (`Abilities`).
	*   Damage calculation using `Attributes`.
	*   Cover system (`LogicGridMap`, `Attributes`) with visual indicators.
	*   Line of Sight (`LogicGridMap`) for attacks.
	*   Simple enemy AI: move towards player, attack if in range.
	*   Health bars and basic combat feedback in UI.

3.  **Phase 3: Polish & Iteration (2-3 weeks)**
	*   Refine UI/UX for movement and combat.
	*   Add one unique special ability per unit type.
	*   Improve visual feedback (e.g., attack animations, hit effects).
	*   Balance unit stats and abilities.
	*   Comprehensive test coverage for all new features.
	*   Performance optimization for the vertical slice.

This roadmap provides a clear path forward for developing the core tactical combat experience in Golom, building upon the strong foundation already established by the engine's modular design.
