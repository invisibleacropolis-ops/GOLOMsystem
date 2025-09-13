# Backend Architecture

This document outlines how Golom's tactical backend modules communicate during a turn, providing a comprehensive understanding for an entry-level engineer.

## Data Flow Overview

The diagram below illustrates the core modules and their primary communication channels. Each module is designed to be loosely coupled, interacting primarily through signals and well-defined method calls, with all significant events flowing into a central `EventBus` for logging and analysis.

```
                      +----------------+
                      |    EventBus    |
                      +--------^-------+
                               |
                               | push()/log_event
+----------------------+-------+----------------------+
|          TurnBasedGridTimespace                      |
|  - Orchestrates turn order, action points, statuses  |
|  - Emits round/turn and AP signals                   |
|  - Records structured events                         |
+----^-----------+-------------+-----------^-----------+
     |           |             |           |
     |           |             |           +-- reaction_triggered (Signal)
     |           |             |                      |
     |           |             |                      v
     |           |             |                +------------+
     |           |             |                | Reactions  |
     |           |             |                | - Manages queued reactions |
     |           |             |                +------------+
     |           |     status_applied/removed (Signals)
     |           v             |
     |     +-----------+       |
     |     | Statuses  |-------+
     |     | - Applies/removes status effects |
     |     +-----------+       |
     |           ^             |
     |           | modifiers   |
     |       +-----------+     |
     |       | Attributes|<----+
     |       | - Manages numeric stats & modifiers |
     |       +-----------+
     |           ^
     |           | checks costs (via get_value)
     |     +-----------+
     |     | Abilities |
     |     | - Validates & executes abilities |
     |     +-----------+
     |           ^
     |           | grants (via grant/get_available)
     |     +-----------+
     |     | Loadouts  |
     |     | - Manages actor's available abilities |
     |     +-----------+
     |
move_actor()/LOS (LogicGridMap methods)
     |
     v
+-----------+
|LogicGridMap|
| - Manages spatial data & pathfinding |
+-----------+
```

## Module Breakdown and Interactions

### `EventBus`

*   **Purpose:** The `EventBus` acts as a central, append-only log for all significant game events. It's crucial for debugging, analytics, and enabling deterministic replays of game sessions.
*   **Key API:**
    *   `push(evt: Dictionary) -> void`: Modules use this method to add structured event dictionaries to the log.
    *   `serialize() -> String`: Converts the event log into a string format (e.g., JSON) for saving or transmission.
    *   `replay(json: String, handler: Callable) -> void`: Allows replaying a game session from a serialized log.
*   **Interaction:** Almost all other modules, particularly `TurnBasedGridTimespace`, push events to the `EventBus` using its `push()` or `log_event()` methods. This ensures a comprehensive record of game state changes.

### `TurnBasedGridTimespace`

*   **Purpose:** This module is the orchestrator of the tactical turn-based combat. It manages initiative order, action points (AP), and coordinates the flow of rounds and turns.
*   **Key API:**
    *   `start_round() -> void`: Resets AP for all actors and initiates a new round.
    *   `end_turn() -> void`: Advances the turn to the next actor in the initiative order.
    *   `get_current_actor() -> Object`: Returns the actor whose turn is currently active.
    *   `register_action(id: String, cost: int, tags: Array, validator: Callable, executor: Callable) -> void`: Defines actions that actors can perform.
    *   `can_perform(actor: Object, action_id: String, payload: Variant) -> bool`: Checks if an actor can perform a specific action.
    *   `perform(actor: Object, action_id: String, payload: Variant) -> bool`: Executes a registered action.
    *   `add_actor(actor: Object, initiative: int, action_points: int, pos: Vector2i, tie_break: int) -> void`: Adds an actor to the timespace.
    *   `apply_status_to_actor(actor: Object, status: String, duration: int, timing: String) -> void`: Applies a status effect to an actor.
    *   `damage_applied(attacker: Variant, defender: Variant, amount: Variant)` (Signal): Emitted when damage is dealt.
    *   `round_started()` (Signal): Emitted when a new round begins.
    *   `turn_started(actor: Variant)` (Signal): Emitted at the start of an actor's turn.
    *   `turn_ended(actor: Variant)` (Signal): Emitted after an actor finishes its turn.
    *   `ap_changed(actor: Variant, old: Variant, new: Variant)` (Signal): Emitted when an actor's AP changes.
    *   `action_performed(actor: Variant, action_id: Variant, payload: Variant)` (Signal): Emitted when an action is successfully executed.
*   **Interaction:** It's the central hub. It calls methods on `Statuses` (for ticking and applying effects), `Abilities` (for executing actions), and `LogicGridMap` (for spatial updates). It also emits numerous signals that other modules (like UI or `Reactions`) can listen to.

### `Reactions`

*   **Purpose:** The `Reactions` module handles reactive abilities or events that occur in response to specific game state changes (e.g., an "attack of opportunity" when an enemy moves).
*   **Key API:**
    *   `trigger(actor: Object, data: Variant, priority: int) -> void`: Queues a reaction to be resolved.
    *   `resolve_next() -> Variant`: Resolves the next pending reaction.
    *   `get_pending() -> Array`: Returns a list of currently queued reactions.
    *   `reaction_queued(reaction: Variant)` (Signal): Emitted when a reaction is added to the queue.
*   **Interaction:** `TurnBasedGridTimespace` can trigger reactions (e.g., via `_check_overwatch` after movement), and the `Reactions` module manages their resolution.

### `Statuses`

*   **Purpose:** This module manages temporary or persistent status effects (buffs, debuffs) on actors and even tiles.
*   **Key API:**
    *   `apply_status(actor: Object, id: String, stacks: int, duration: int, modifiers: Array) -> void`: Applies a status effect.
    *   `tick() -> void`: Reduces the duration of all active statuses and removes expired ones.
    *   `status_applied(actor: Variant, id: Variant)` (Signal): Emitted when a status is applied.
    *   `status_removed(actor: Variant, id: Variant)` (Signal): Emitted when a status is removed.
*   **Interaction:** `TurnBasedGridTimespace` calls `tick()` on `Statuses` at appropriate times (e.g., start/end of turn). `Statuses` interacts with `Attributes` to apply modifiers associated with status effects.

### `Attributes`

*   **Purpose:** Manages all numeric statistics (attributes) for actors, including base values, modifiers (additive, multiplicative, percentage), and clamped ranges.
*   **Key API:**
    *   `set_base(actor: Object, key: String, value: float) -> void`: Sets an actor's base attribute value.
    *   `add_modifier(actor: Object, key: String, add: float, mul: float, source: String, duration: int, perc: float) -> void`: Adds a modifier to an attribute.
    *   `clear_modifiers(actor: Object, source: String) -> void`: Removes modifiers from a specific source.
    *   `get_value(actor: Object, key: String) -> float`: **The primary way to query an attribute's effective value**, considering all modifiers and ranges.
    *   `set_range(key: String, min_value: float, max_value: float) -> void`: Defines min/max for an attribute.
*   **Interaction:** `Abilities` checks costs via `Attributes.get_value()`. `Statuses` applies and removes modifiers using `Attributes.add_modifier()` and `Attributes.clear_modifiers()`.

### `Abilities`

*   **Purpose:** Validates and executes active abilities, managing costs, cooldowns, and effects.
*   **Key API:**
    *   `register_ability(id: String, data: Dictionary) -> void`: Adds an ability definition.
    *   `load_from_file(path: String) -> void`: Loads abilities from JSON.
    *   `can_use(actor: Object, id: String, attrs: Variant) -> bool`: Checks if an actor can use an ability (checks cooldowns and costs via `Attributes`).
    *   `execute(actor: Object, id: String, target: Variant, attrs: Variant) -> Array`: Executes ability logic, deducts resources, sets cooldowns, and returns follow-up abilities.
    *   `tick_cooldowns() -> void`: Decrements all ability cooldowns.
*   **Interaction:** `Loadouts` determines which abilities an actor has. `Abilities` uses `Attributes` to check resource costs and `TurnBasedGridTimespace` to log events and potentially trigger signals like `damage_applied`.

### `Loadouts`

*   **Purpose:** Manages which abilities are available to a specific actor, potentially based on equipment, class, or status effects.
*   **Key API:**
    *   `grant(actor: Object, ability_id: String) -> void`: Grants a specific ability to an actor.
    *   `get_available(actor: Object) -> String[]`: Returns a list of ability IDs available to an actor.
*   **Interaction:** External logic (e.g., UI) queries `Loadouts.get_available()` to display options. `Loadouts` might interact with `Abilities` to ensure granted abilities are properly registered.

### `LogicGridMap`

*   **Purpose:** Manages the spatial data of the game world, including tile properties, actor positions, and pathfinding. It's the core for anything related to the grid.
*   **Key API:**
    *   `move_actor(actor: Object, from_pos: Vector2i, to_pos: Vector2i) -> bool`: Moves an actor on the grid.
    *   `has_line_of_sight(from_pos: Vector2i, to_pos: Vector2i) -> bool`: Checks if there's an unobstructed line of sight between two points.
    *   `get_actor_at(pos: Vector2i) -> Variant`: Returns the actor at a given position.
    *   `has_actor_at(pos: Vector2i) -> bool`: Checks if an actor is present at a position.
*   **Interaction:** `TurnBasedGridTimespace` delegates movement actions to `LogicGridMap`. `GridRealtimeRenderer` uses `LogicGridMap` data for visualization.

## Typical Turn Sequence: A Detailed Walkthrough

Understanding the sequence of operations during a turn is key to grasping the backend's flow.

1.  **Round Start:**
    *   `TurnBasedGridTimespace.start_round()` is called.
    *   **Logic:** This method resets each actor's action points (AP) for the new round.
    *   **Signals:** It emits the `round_started` signal, notifying any listening systems (e.g., UI, other game logic) that a new round has begun.
    *   **Logging:** An event is logged to the `EventBus` to record the round start.
    *   **Status Tick:** Before the first turn, `TurnBasedGridTimespace` calls `Statuses.tick()` to process any round-start status effects.

2.  **Turn Begins:**
    *   `_begin_actor_turn()` (an internal method of `TurnBasedGridTimespace`) is invoked for the current actor.
    *   **Signals:** The `turn_started` signal is fired, indicating which actor's turn it is.
    *   **Status Application:** Any `turn_start` statuses relevant to the active actor are applied or processed by the `Statuses` module.

3.  **Ability Selection:**
    *   **Loadouts:** External logic (e.g., the player's UI) queries `Loadouts.get_available(actor)` to retrieve a list of abilities that the current actor possesses and can potentially use.
    *   **Abilities & Attributes:** For each available ability, `Abilities.can_use(actor, id, attrs)` is called. This method internally interacts with the `Attributes` service (`Attributes.get_value()`) to check if the actor has sufficient resources (e.g., Action Points, Mana) and if the ability is off cooldown. This ensures only valid abilities are presented to the player.

4.  **Action Execution:**
    *   When an actor performs an action (e.g., moving, attacking):
    *   **Movement:** If it's a movement action, `TurnBasedGridTimespace.move_current_actor()` is called. This method then delegates the actual spatial update to `LogicGridMap.move_actor()`, which handles changing the actor's position on the grid.
    *   **AP & Signals:** Regardless of the action, `TurnBasedGridTimespace` manages the actor's Action Points. Changes to AP trigger the `ap_changed` signal. A successful action execution also emits an `action_performed` signal, providing details about the action.
    *   **Abilities:** If the action is an ability, `Abilities.execute()` is called, which handles resource deduction, cooldown tracking, and any immediate effects of the ability.

5.  **Reactions:**
    *   After an actor completes its movement or action, `TurnBasedGridTimespace` might call `_check_overwatch()` (an internal method).
    *   **Line of Sight:** This method uses `LogicGridMap.has_line_of_sight()` to determine if any other actors (watchers) have a clear line of sight to the moved actor.
    *   **Triggering Reactions:** If conditions are met (e.g., an enemy enters a watcher's line of sight), a `reaction_triggered` signal is emitted. This signal is typically listened to by the `Reactions` module, which then queues and manages the resolution of these reactive abilities (e.g., an "attack of opportunity").

6.  **Status Handling:**
    *   Throughout the turn, abilities or other game effects can call `TurnBasedGridTimespace.apply_status_to_actor()`. This method then interacts with the `Statuses` module to apply the status effect.
    *   **Signals:** When a status is applied, the `Statuses` module emits a `status_applied` signal. Similarly, when a status expires or is removed, a `status_removed` signal is emitted.
    *   **Duration & Ticking:** `Statuses` manages the duration of effects. `TurnBasedGridTimespace` ensures `Statuses.tick()` is called at appropriate turn or round boundaries to decrement durations and purge expired effects.

7.  **Event Logging:**
    *   Crucially, throughout this entire sequence, each module (e.g., `TurnBasedGridTimespace`, `Attributes`, `Abilities`) records structured dictionaries representing significant events.
    *   **Centralized Log:** These event dictionaries are then pushed to the shared `EventBus` using its `push()` method. This creates a chronological, detailed log of everything that happened during the turn, invaluable for debugging, analytics, and game state reconstruction.

8.  **Turn End:**
    *   `TurnBasedGridTimespace.end_turn()` is called.
    *   **Signals:** It emits the `turn_ended` signal for the current actor.
    *   **Status Tick:** Any `turn_end` statuses are processed by the `Statuses` module.
    *   **Next Actor/Round End:** The `TurnBasedGridTimespace` then advances to the next actor in the initiative order. If all actors have taken their turn, it signals the end of the round by emitting `round_ended`.

Together, these modules form a loosely coupled backend where signals and method calls coordinate spatial updates, ability usage, and reactive effects, while all significant events flow into a central log. This modular design allows for easier development, testing, and maintenance of complex game logic.