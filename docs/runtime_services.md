# Runtime Service Overview

This document summarizes the core logic modules that power the tactical runtime and explains how the `RuntimeServices` node aggregates them into a single, easily accessible point. Each module lives under `scripts/modules` and exposes a `run_tests()` helper so Continuous Integration (CI) systems and engineers can validate behavior headlessly.

## Core Logic Modules

These are the independent, self-contained modules that `RuntimeServices` brings together:

### `TurnBasedGridTimespace` (Turn Manager)

*   **Purpose:** Orchestrates the flow of combat rounds and turns. It manages initiative, action point (AP) refresh, and deterministic ordering of actor actions.
*   **Key API Role:**
    *   **Phases:** Manages the combat through distinct phases: `ROUND_START → ACTOR_START → ACTING → REACTION_WINDOWS → ACTOR_END → NEXT_ACTOR/ROUND_END`.
    *   **Signals:** Emits crucial signals such as `round_started()`, `turn_started(actor)`, `ap_changed(actor, old, new)`, and `action_performed(actor, action_id, payload)`. These signals allow UI or AI layers to respond to game state changes without tight coupling to the internal logic.
*   **Further Reading:** [TurnBasedGridTimespace API Documentation](html/TurnBasedGridTimespace.html), [Turn Timespace Manual](turn_timespace_manual.md)

### `LogicGridMap` (Spatial Authority)

*   **Purpose:** The authoritative source for all spatial data on the tactical grid. It tracks bounds, occupancy, line of sight (LOS), and area-of-effect (AoE) templates.
*   **Key API Role:** Supplies essential queries to other systems, including pathfinding (`find_path()`), cover calculations (`get_cover()`), and zone-of-control projections (`get_zone_of_control()`).
*   **Further Reading:** [LogicGridMap API Documentation](html/GridLogic.html), [Grid Map Manual](grid_map_manual.md)

### `Attributes`

*   **Purpose:** The single source of truth for all numeric statistics (attributes) of actors. It handles base values and applies additive, multiplicative, and percentage modifiers with defined sources and durations.
*   **Key API Role:** All gameplay logic must read attribute values via `get_value(actor, key)` to ensure modifiers are correctly applied.
*   **Further Reading:** [Attributes API Documentation](html/Attributes.html), [Attributes Manual](attributes_manual.md)

### `Statuses`

*   **Purpose:** Manages buffs, debuffs, and other temporary or persistent stances applied to actors or tiles.
*   **Key API Role:** `apply_status()` records new effects, while `tick()` decrements durations and notifies when statuses expire (via `status_removed` signal) so modifiers can be cleanly un-applied.
*   **Further Reading:** [Statuses API Documentation](html/Statuses.html), [Statuses Manual](statuses_manual.md)

### `Abilities`

*   **Purpose:** Defines, validates requirements (tags, resources, range), and executes ordered effect lists for in-game abilities.
*   **Key API Role:** Handles spending costs, setting cooldowns, and recording ability usage to the event log. `can_use()` checks if an ability is currently available, and `execute()` performs its effects.
*   **Further Reading:** [Abilities API Documentation](html/Abilities.html), [Abilities Manual](abilities_manual.md)

### `Loadouts`

*   **Purpose:** Computes the set of abilities an actor can currently use based on their inherent traits, equipped items, and active statuses.
*   **Key API Role:** `get_available(actor)` returns a list of ability IDs, feeding both UI hotbars and AI planners with the answer to "what can I use right now?"
*   **Further Reading:** [Loadouts API Documentation](html/Loadouts.html), [Loadouts Manual](loadouts_manual.md)

### `Reactions`

*   **Purpose:** Manages a queue of interrupt abilities, such as attacks of opportunity or overwatch shots.
*   **Key API Role:** Subscribes to movement or action triggers and queues reaction abilities. `resolve_next()` processes queued reactions by priority, while enforcing "once-per-turn" caps or other limits.
*   **Further Reading:** [Reactions API Documentation](html/Reactions.html), [Reactions Manual](reactions_manual.md)

### `EventBus`

*   **Purpose:** An append-only stream of structured entries describing every significant state change in the game.
*   **Key API Role:** Drives logging, analytics, and deterministic replays. Modules push events using `push()`, and the entire log can be serialized (`serialize()`) or replayed (`replay()`).
*   **Further Reading:** [EventBus API Documentation](html/EventBus.html), [Event Bus Manual](event_bus_manual.md)

### `Terrain`

*   **Purpose:** A central registry of terrain types (e.g., grass, dirt, stone).
*   **Key API Role:** Applies movement cost, Line of Sight (LOS) blockers, and tags to `LogicGridMap` tiles. It also allows for runtime mutation of terrain properties.
*   **Further Reading:** [Terrain API Documentation](html/Terrain.html), [Terrain Manual](terrain_manual.md)

## Real-world Usage: The `RuntimeServices` Aggregator

The `RuntimeServices` node (`scripts/modules/runtime_services.gd`) is designed to simplify the setup and access of all these core logic modules within your gameplay scenes. Instead of instantiating and wiring each module individually, `RuntimeServices` does it for you.

### Class: `RuntimeServices` (inherits from `Node`)

`RuntimeServices` is a `Node` that acts as a container and central access point for all the core backend logic.

#### Members

`RuntimeServices` exposes direct references to instances of all the core modules as its members. This means you can access any module's API through a single `services` object:

*   **`grid_map`** (`LogicGridMap`): Access to spatial queries, pathfinding, etc.
*   **`timespace`** (`TurnBasedGridTimespace`): Access to turn management, actor registration, etc.
*   **`attributes`** (`Attributes`): Access to attribute management, `get_value()`, etc.
*   **`statuses`** (`Statuses`): Access to status application and management.
*   **`abilities`** (`Abilities`): Access to ability validation and execution.
*   **`loadouts`** (`Loadouts`): Access to actor ability loadouts.
*   **`reactions`** (`Reactions`): Access to reaction queuing and resolution.
*   **`event_bus`** (`EventBus`): Access to the central event log.

#### Example Usage

```gdscript
# In your main game scene script (e.g., Root.gd or a specific level scene)
var services := RuntimeServices.new()
add_child(services) # Add the RuntimeServices node to the scene tree

# Configure the grid map (e.g., its dimensions)
services.grid_map.width = 8
services.grid_map.height = 8

# Start the first round of the game
services.timespace.start_round()

# Abilities can be customized at runtime before execution:
services.abilities.register_ability("fire_bolt", {
    "act_cost": 1,
    "chi_cost": 2,
    "cooldown": 1,
    "effect": "deal_damage", # Example custom effect data
    "damage_amount": 10
})

# UI widgets or AI can subscribe to timespace or status signals to react to changes:
func _ready() -> void:
    # Connect to signals from the aggregated modules
    services.timespace.ap_changed.connect(_on_ap_changed)
    services.statuses.status_applied.connect(_on_status_applied)

func _on_ap_changed(actor: Object, old_ap: int, new_ap: int) -> void:
    # Example: Update a UI label showing an actor's AP
    if actor == watched_actor: # Assuming 'watched_actor' is a reference to the player
        ap_label.text = str(new_ap)

func _on_status_applied(actor: Object, id: String) -> void:
    # Example: Display a visual indicator for a new status effect
    if actor == watched_actor:
        status_panel.show_status(id)
```

## Testing

`RuntimeServices` includes its own integration test to verify that all aggregated modules can operate together.

*   **Execute the service's integration test and all module self-tests via the shared runner:**

    ```bash
    godot4 --headless --path . --script scripts/test_runner.gd -- --module=runtime_services
    ```

    This command runs the tests headlessly. The `RuntimeServices` test typically involves moving an actor through the timespace, which in turn exercises the interactions between `TurnBasedGridTimespace`, `LogicGridMap`, `Attributes`, and `Statuses`. It also delegates to each individual module's `run_tests()` method, ensuring comprehensive coverage.

### Pitfalls to Avoid

*   **Resource Leaks in Headless Tests:** When running headless tests, always ensure that you explicitly free instantiated modules (e.g., `services.free()`) to prevent memory leaks, especially for `Node`s.
*   **`timespace.set_grid_map()`:** It is crucial that `timespace.set_grid_map()` is invoked before starting the timespace (e.g., `timespace.start_round()`). `RuntimeServices` handles this internally during its `_ready()` method, but if you are setting up modules manually, you must call it explicitly to link the turn manager to the game grid.