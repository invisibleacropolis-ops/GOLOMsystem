# Game Logic Overview

This project organizes tactical role-playing game logic into discrete Godot modules. Each module owns a narrow slice of the ruleset and communicates with others through simple method calls or Godot signals. This section gives outside engineers a high-level map for navigating the runtime, explaining how these tools work together and why.

## Core Concepts: The Building Blocks of Golom

Golom's game logic is built upon several interconnected modules, each specializing in a core aspect of the game. Understanding these modules and their APIs is key to building and extending the game.

*   **`LogicGridMap`**
    *   **Purpose:** This module (`grid_map.gd`) is the pure data container for all spatial information in the game world. It handles grid coordinates, terrain tags, and the physical presence of actors. It's the foundation for anything that needs to know about "where" things are.
    *   **Key API Role:** Provides methods for spatial queries (e.g., `is_in_bounds()`, `is_occupied()`), pathfinding (`find_path()`), and line of sight (`has_line_of_sight()`). It doesn't handle visual rendering directly but provides the data for it.
    *   **Why it's separate:** By separating spatial data from visual representation, the game can run headless (without graphics) for testing or server-side logic, and allows for flexible visual layers.
    *   **Further Reading:** [LogicGridMap API Documentation](html/GridLogic.html), [Grid Map Manual](grid_map_manual.md)

*   **`TurnBasedGridTimespace`**
    *   **Purpose:** This module (`turn_timespace.gd`) acts as the central state machine for turn-based combat. It orchestrates the flow of rounds and turns, manages action points (AP), and handles the initiative order of all actors.
    *   **Key API Role:** Methods like `start_round()` and `end_turn()` drive the game's temporal progression. It manages actor AP and triggers status effect processing. It also emits crucial signals like `round_started`, `turn_started`, and `ap_changed` to notify other systems of game state changes.
    *   **Why it's central:** By centralizing turn management, the game ensures consistent application of rules and provides clear points for other modules (like UI or AI) to synchronize with the game's flow.
    *   **Further Reading:** [TurnBasedGridTimespace API Documentation](html/TurnBasedGridTimespace.html), [Turn Timespace Manual](turn_timespace_manual.md)

*   **`Attributes`**
    *   **Purpose:** This module (`attributes.gd`) is the central authority for all numeric statistics (attributes) of actors. It handles base values, applies various types of modifiers (additive, multiplicative, percentage), and enforces clamped ranges.
    *   **Key API Role:** The `get_value(actor, key)` method is paramount; **all systems must query attribute values through this method** to ensure modifiers and ranges are correctly applied. Methods like `set_base()` and `add_modifier()` allow for dynamic changes to attributes.
    *   **Why it's centralized:** Funneling all attribute reads and modifications through this single service ensures consistency, prevents bugs from direct field manipulation, and makes auditing attribute calculations much easier.
    *   **Further Reading:** [Attributes API Documentation](html/Attributes.html), [Attributes Manual](attributes_manual.md)

*   **`Statuses`**
    *   **Purpose:** This module (`statuses.gd`) manages temporary or persistent status effects (buffs and debuffs) applied to actors or even specific tiles.
    *   **Key API Role:** `apply_status()` adds effects, and `tick()` (called by `TurnBasedGridTimespace`) reduces durations and purges expired statuses. Signals like `status_applied` and `status_removed` inform other modules of changes.
    *   **Why it's separate:** Isolating status effect logic simplifies their management, allowing for complex interactions without cluttering actor definitions. It also ensures consistent application and removal of effects.
    *   **Further Reading:** [Statuses API Documentation](html/Statuses.html), [Statuses Manual](statuses_manual.md)

*   **`Abilities` & `Loadouts`**
    *   **Purpose:**
        *   **`Abilities`** (`abilities.gd`): Defines, validates, and executes active abilities. It handles resource costs, cooldowns, and the core logic of what an ability does.
        *   **`Loadouts`** (`loadouts.gd`): Determines which abilities an actor currently has access to, based on factors like equipment, class, or active status effects.
    *   **Key API Role:** `Abilities.can_use()` checks if an actor meets the requirements (e.g., AP, cooldowns via `Attributes`). `Abilities.execute()` performs the ability. `Loadouts.get_available()` provides the list of usable abilities to UI or AI.
    *   **Why they work together:** `Loadouts` acts as a filter or grant system for `Abilities`. This separation allows designers to easily define new abilities and then control their availability to different actors without modifying core ability logic.
    *   **Further Reading:** [Abilities API Documentation](html/Abilities.html), [Loadouts API Documentation](html/Loadouts.html), [Abilities Manual](abilities_manual.md), [Loadouts Manual](loadouts_manual.md)

*   **`Reactions`**
    *   **Purpose:** This module (`reactions.gd`) provides a lightweight interrupt system for "opportunity actions" or reactions that occur in response to specific game events (e.g., an attack of opportunity when an enemy moves into range).
    *   **Key API Role:** `trigger()` queues a reaction, and `resolve_next()` processes the next one.
    *   **Why it's separate:** It allows for complex reactive behaviors without tightly coupling them into the main turn sequence, making the game logic more flexible and extensible.
    *   **Further Reading:** [Reactions API Documentation](html/Reactions.html), [Reactions Manual](reactions_manual.md)

*   **`EventBus`**
    *   **Purpose:** This module (`event_bus.gd`) is an append-only log that captures every significant state change or event in the game.
    *   **Key API Role:** `push(evt)` is used by all other modules to record structured event dictionaries. `serialize()` and `replay()` enable saving, loading, and replaying game sessions deterministically.
    *   **Why it's crucial:** It's fundamental for debugging (seeing the exact sequence of events), analytics (collecting data on gameplay), and enabling deterministic replays (recreating a game session exactly as it happened).
    *   **Further Reading:** [EventBus API Documentation](html/EventBus.html), [Event Bus Manual](event_bus_manual.md)

*   **`GridVisualLogic`**
    *   **Purpose:** This module (`grid_visual_logic.gd`) is an immediate-mode renderer primarily used for debugging grid state or powering a minimal UI. It allows developers to draw colors or custom shapes directly onto grid cells.
    *   **Key API Role:** `set_cell_state()` and `update_cells()` allow for dynamic visual feedback on the grid.
    *   **Why it's separate:** It provides a quick and easy way to visualize the underlying `LogicGridMap` data without needing complex 3D models or extensive UI setup, making debugging much faster.
    *   **Further Reading:** [GridVisualLogic API Documentation](html/GridVisualLogic.html), [Grid Visual Logic Manual](grid_visual_logic.md)

Modules are intentionally decoupled so they can be instantiated or swapped independently inside tests or gameplay scenes. The `scripts/test_runner.gd` scene shows how to run their self-tests headlessly.

## Execution Flow: A Turn in Action

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

## Integration Tips for Developers

-   **Treat Modules as Services:** Think of each module (e.g., `Attributes`, `Statuses`) as a self-contained service. Instantiate the ones you need and inject them into your game scenes or other modules. This promotes modularity and reusability.
-   **Leverage Signals for Loose Coupling:** Use Godot's signals (`turn_started`, `ap_changed`, `status_applied`, etc.) extensively. This is the primary mechanism for modules to communicate without directly knowing about each other's internal implementations. This keeps UI and AI layers loosely coupled from the core game logic.
-   **Run Module Self-Tests Frequently:** The `scripts/test_runner.gd` script is your best friend. Run it often with `godot4 --headless --path . --script scripts/test_runner.gd` to ensure deterministic behavior across platforms and to catch regressions early. Each module's `run_tests()` method provides a quick way to verify its functionality.
-   **Minimal Public APIs, Data-Driven Rules:** When extending modules or adding new features, strive to keep public APIs minimal and well-defined. Prefer using data-driven dictionaries for new rules (e.g., ability definitions, status effects) rather than hardcoding them into scripts. This allows designers to iterate on gameplay without requiring code changes.
-   **Consult Specific Manuals:** This overview provides a map. For in-depth API usage, examples, and specific implementation details for each module, refer to its dedicated manual in the `docs/` folder and its corresponding HTML API documentation in `docs/html/`.