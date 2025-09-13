# Future Upgrade Plan

This outline captures recommended enhancements for Golom's logic layer based on current code reviews and design goals. Items are grouped by area and intentionally verbose so future contributors can gauge scope and rationale, understanding how existing API elements lay the groundwork for these upgrades.

## Core Infrastructure

### Robust `GridLogic` Implementation

*   **Current Status & Rationale:** The `GridLogic` module (`scripts/modules/grid_logic.gd`) is currently a placeholder. The plan is to evolve it into a central coordinator for high-level grid queries.
*   **API Integration:**
    *   **Delegation to `LogicGridMap`:** The upgraded `GridLogic` will delegate core spatial operations (movement validation, Line of Sight (LOS), cover queries) to the `LogicGridMap` (`scripts/grid/grid_map.gd`). This ensures `LogicGridMap` remains the single source of truth for spatial data.
    *   **High-Level Helpers:** It will expose simplified, high-level helper methods for AI and UI layers, such as `can_move(actor: Object, to: Vector2i) -> bool` (which internally uses `LogicGridMap.find_path()` and `is_occupied()`) and `threatened_tiles(actor: Object) -> Array[Vector2i]` (which might use `LogicGridMap.get_zone_of_control()`).
    *   **Testing:** The module will include its own `run_tests()` method to cover edge cases like multi-tile actors and impassable terrain, ensuring its robustness.
*   **Further Reading:** [GridLogic API Documentation](html/GridLogic.html), [LogicGridMap API Documentation](html/GridLogic.html), [Grid Logic Manual](grid_logic_manual.md)

### Workspace Quality-of-Life

*   **Current Status & Rationale:** The `Workspace` (`scripts/core/workspace.gd`) is a developer tool for running tests. Enhancements aim to improve developer experience.
*   **API Integration:**
    *   **Persistence:** Implement saving and loading of module selection and loop intervals to `user://` config files. This would involve using Godot's `ConfigFile` or JSON serialization to persist `Workspace`'s internal state (e.g., `selected_modules` array, `loop_interval` float).
    *   **"Run Selected" Option:** Add a GUI option to `Workspace` to run only specific modules' tests. This would involve modifying `Workspace`'s UI and its interaction with `scripts/test_runner.gd` to pass a filtered list of modules.
*   **Further Reading:** [Developer Codebase Overview](developer_overview.md) (for `Workspace` context)

## Spatial Systems

### `LogicGridMap` Extensions

*   **Current Status & Rationale:** `LogicGridMap` (`scripts/grid/grid_map.gd`) is already a feature-rich spatial data container. These are plans to extend its capabilities.
*   **API Integration:**
    *   **Hex Grids/Variable Movement:** This would involve significant internal changes to `LogicGridMap`'s coordinate system and neighbor-finding algorithms. The current `find_path()` and distance helpers are based on square grids, so new methods or configurable parameters would be needed.
    *   **Pathfinding Caching:** Implement caching mechanisms for `find_path()` results. This would involve storing computed paths (e.g., in a `Dictionary` keyed by start/end points) to accelerate repeated queries, especially for AI.
    *   **Dynamic Terrain Changes:** Add methods to `LogicGridMap` to dynamically alter tile properties (e.g., `set_height(pos, new_height)`, `toggle_los_blocker(pos, enable)`). These changes would need to trigger updates in pathfinding and LOS calculations. Corresponding events would be pushed to the `EventBus` (`EventBus.push()`) to log these changes.
*   **Further Reading:** [LogicGridMap API Documentation](html/GridLogic.html), [Grid Map Manual](grid_map_manual.md), [EventBus API Documentation](html/EventBus.html)

### `GridInteractor` Polish

*   **Current Status & Rationale:** `GridInteractor` (`scripts/grid/grid_interactor.gd`) handles mouse input for grid interactions. Enhancements focus on improving user experience.
*   **API Integration:**
    *   **Camera Panning/Selection Cancellation:** Implement right-click drag for camera panning (interacting with a `Camera2D` or `Camera3D` node) or to cancel active selections. This would involve adding new input handling logic within `GridInteractor` and potentially new signals (e.g., `pan_started`, `selection_canceled`).
    *   **Hover Previews:** Leverage `GridRealtimeRenderer`'s capabilities (e.g., `set_cell_color()`, `set_mark()`, `stroke_outline_for()`) to provide visual feedback on hover, querying `LogicGridMap` for threatened zones (`LogicGridMap.get_zone_of_control()`) or reachable tiles (`LogicGridMap.find_path()`).
    *   **Keyboard Modifiers for Drag Selection:** Extend `GridInteractor`'s input processing to interpret keyboard modifiers (e.g., Shift, Alt) for snapping drag selections to orthogonal lines or other patterns.
*   **Further Reading:** [Grid Interactor Manual](grid_interactor_manual.md), [GridRealtimeRenderer API Documentation](html/GridRealtimeRenderer.html), [LogicGridMap API Documentation](html/GridLogic.html)

## Timeline & Combat

### `TurnBasedGridTimespace` Depth

*   **Current Status & Rationale:** `TurnBasedGridTimespace` (`scripts/modules/turn_timespace.gd`) is the core turn manager. These are plans to add more sophisticated combat mechanics.
*   **API Integration:**
    *   **Explicit Reaction Windows:** Introduce new states or phases within `TurnBasedGridTimespace`'s internal state machine to represent explicit reaction windows between action phases. This would involve new signals (e.g., `reaction_window_opened`) and methods to allow multiple watchers (e.g., `Reactions` module) to respond with priority rules.
    *   **Expanded Status Handling:** Enhance the integration with `Statuses` (`scripts/modules/statuses.gd`). Implement callbacks or signals within `Statuses` (e.g., `status_applied`, `status_removed`) that automatically trigger updates to `Attributes` (`scripts/modules/attributes.gd`) when modifiers are applied or removed. (Note: `status_applied` and `status_removed` signals already exist and are used by `Statuses` to notify, so this is more about ensuring `Attributes` reacts to them).
    *   **Serialization and Replay:** The `TurnBasedGridTimespace` already supports `serialize_event_log()` and `replay_event_log()`. The plan is to fully leverage these for deterministic unit tests and full game replays, ensuring all state changes are captured.
*   **Further Reading:** [TurnBasedGridTimespace API Documentation](html/TurnBasedGridTimespace.html), [Turn Timespace Manual](turn_timespace_manual.md), [Statuses API Documentation](html/Statuses.html), [Statuses Manual](statuses_manual.md), [Attributes API Documentation](html/Attributes.html), [Attributes Manual](attributes_manual.md), [Reactions API Documentation](html/Reactions.html), [Reactions Manual](reactions_manual.md), [EventBus API Documentation](html/EventBus.html)

### Action System

*   **Current Status & Rationale:** The game has a basic action system. The plan is to make it more flexible and data-driven.
*   **API Integration:**
    *   **Data-Driven Action Definitions:** Move action definitions (e.g., "strike", "move") into external data files (JSON or Godot `Resource`s). This would involve `Abilities` (`scripts/modules/abilities.gd`) using `load_from_file()` or a similar mechanism to load these definitions at runtime.
    *   **Cooldown Tracking & Resource Costs:** `Abilities` already supports `tick_cooldowns()` and `can_use()` (which checks costs via `Attributes`). The upgrade would involve fully integrating these features into the data-driven action definitions, ensuring that all actions respect cooldowns and resource costs.
*   **Further Reading:** [Abilities API Documentation](html/Abilities.html), [Abilities Manual](abilities_manual.md), [Attributes API Documentation](html/Attributes.html)

## Actor Data & Effects

### `Attributes` and `Statuses` Integration

*   **Current Status & Rationale:** `Attributes` and `Statuses` are separate modules. The plan is to enhance their interaction for automatic modifier management.
*   **API Integration:**
    *   **Automatic Modifier Removal:** Implement a `tick()` or observer pattern within `Statuses` (`scripts/modules/statuses.gd`) so that when a status expires, it automatically calls `Attributes.clear_modifiers()` to remove its associated numerical effects. (Note: `Statuses.tick()` already handles this, so this is about emphasizing its role).
    *   **Percentage-Based Modifiers & Clamped Ranges:** `Attributes` (`scripts/modules/attributes.gd`) already supports `add_modifier()` with a `perc` parameter for percentage-based modifiers and `set_range()` for clamped stat ranges. The plan is to fully utilize and expand these capabilities.
*   **Further Reading:** [Attributes API Documentation](html/Attributes.html), [Attributes Manual](attributes_manual.md), [Statuses API Documentation](html/Statuses.html), [Statuses Manual](statuses_manual.md)

### `Loadouts`/`Abilities` Growth

*   **Current Status & Rationale:** `Loadouts` and `Abilities` manage what an actor can do. The plan is to make this more dynamic.
*   **API Integration:**
    *   **Comprehensive Ability Computation:** `Loadouts` (`scripts/modules/loadouts.gd`) already has methods like `grant_from_equipment()`, `grant_from_status()`, and `grant_from_class()`. The upgrade involves fully leveraging these to compute an actor's available abilities based on all traits, equipment, and active statuses, and then using `Loadouts.get_available()` to query this merged list.
    *   **Ability Chaining/Combo Systems:** `Abilities.execute()` already returns an `Array` of follow-up ability IDs. The plan is to build robust ability chaining or combo systems that utilize this return value to trigger subsequent abilities in an ordered effect list.
*   **Further Reading:** [Loadouts API Documentation](html/Loadouts.html), [Loadouts Manual](loadouts_manual.md), [Abilities API Documentation](html/Abilities.html), [Abilities Manual](abilities_manual.md)

### `Reactions` Engine

*   **Current Status & Rationale:** The `Reactions` module (`scripts/modules/reactions.gd`) queues reactions. The plan is to refine its prioritization and AI integration.
*   **API Integration:**
    *   **Prioritized Resolution:** Enhance `Reactions.resolve_next()` to prioritize queued reactions not just by insertion order, but by proximity to the event, initiative of the reacting actor, or other custom rules. This would involve modifying the internal sorting logic of the `queued` array.
    *   **AI Hooks:** Offer explicit hooks for AI systems to inspect pending reactions (`Reactions.get_pending()`) before execution. This allows AI to make strategic decisions about whether to use a reaction, rather than just blindly executing it.
*   **Further Reading:** [Reactions API Documentation](html/Reactions.html), [Reactions Manual](reactions_manual.md)

## Visualization

### `GridRealtimeRenderer` Features

*   **Current Status & Rationale:** `GridRealtimeRenderer` (`scripts/modules/GridRealtimeRenderer.gd`) is a high-performance visual overlay. The plan is to add more advanced rendering capabilities.
*   **API Integration:**
    *   **GPU-Based Text Rendering:** `GridRealtimeRenderer` already supports `use_gpu_labels`, `begin_labels()`, `push_label()`, and `end_labels()` for GPU-based text rendering, reducing draw calls. This feature is already implemented.
    *   **Shader Variations:** Implement new shader variations (e.g., night vision, fog of war, colorblind-friendly palettes) and expose them via `set_shader_mode()`.
    *   **Benchmark Harness:** Develop a benchmark harness to measure the performance of `GridRealtimeRenderer` under heavy updates (e.g., large grids, many dynamic overlays).
*   **Further Reading:** [GridRealtimeRenderer API Documentation](html/GridRealtimeRenderer.html), [GridRealtimeRenderer Manual](grid_realtime_renderer_manual.md)

### Documentation and Tooling

*   **Current Status & Rationale:** The project aims for comprehensive documentation.
*   **API Integration:**
    *   **Step-by-Step Tutorials:** Create more tutorials demonstrating how to combine `GridRealtimeRenderer` with `TurnBasedGridTimespace` in gameplay scenes, similar to the existing `renderer_turn_timespace_tutorial.md`.
    *   **API Reference Docs:** The project already generates API reference documentation using `godot --doctool` for all modules, which are then converted to HTML. The plan is to ensure this process is robust and covers all new APIs.
*   **Further Reading:** [Developer Codebase Overview](developer_overview.md), [Headless Tooling & Runner Scripts](headless_tooling.md)

## Testing & CI

*   **Current Status & Rationale:** The project has a `test_runner.gd` for headless testing. The plan is to automate and expand testing in CI.
*   **API Integration:**
    *   **Automated CI Runs:** Automate `godot4 --headless` test runs in CI pipelines (e.g., GitHub Actions) with log artifact uploads. This leverages the existing headless capabilities of Godot and the `test_runner.gd` script.
    *   **Regression Tests:** Add more regression tests for pathfinding (`LogicGridMap.find_path()`), LOS (`LogicGridMap.has_line_of_sight()`), and Zone of Control (ZOC) calculations (`LogicGridMap.get_zone_of_control()`) using deterministic seed scenarios.
    *   **Documentation Build Validation:** Implement CI checks to validate documentation build steps, ensuring that updates to `docs/` do not drift from code behavior. This would involve running the `doc_regen` scripts and potentially comparing generated output.
*   **Further Reading:** [Headless Tooling & Runner Scripts](headless_tooling.md)