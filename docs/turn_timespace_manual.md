# Turn-Based Grid Timespace Manual

`turn_timespace.gd` defines the `TurnBasedGridTimespace` module, which orchestrates the tactical timeline of the game. It is the central authority for managing initiative order, action points (AP), overwatch reactions, explicit reaction windows, status ticking, and the serialization of the game state for replay support.

## Responsibilities

-   Maintain the game's round and turn state via an internal state machine.
-   Track actors with initiative, action points, and positions on a `LogicGridMap`.
-   Emit signals (`round_started`, `turn_started`, `ap_changed`, `action_performed`, etc.) to allow UI or AI layers to react to game flow changes.
-   Register actions with validators and executors through `register_action()` and invoke them via `perform()`.
-   Apply and tick status effects on actors and tiles, delegating to the `Statuses` module and emitting callbacks to update `Attributes`.
-   Enable deterministic snapshots of the entire timeline state with `create_snapshot()` and `to_dict()` / `from_dict()`.
-   Provide serialization and replay functionality for the `event_log`.

## Core Concepts and API Details

The `TurnBasedGridTimespace` module is the heart of the turn-based combat system. It ensures that all actions and events occur in a predictable and ordered manner.

### Class: `TurnBasedGridTimespace` (inherits from `Node`)

As a `Node`, `TurnBasedGridTimespace` can be integrated into your game's scene tree, typically as part of a `RuntimeServices` aggregation.

#### Members

*   **`state`** (`int`, Enum: `TurnBasedGridTimespace.State`, Default: `0`): Represents the current state of the turn-based system (e.g., `IDLE`, `ROUND_START`, `ACTING`, `REACTION_WINDOWS`).
*   **`grid_map`** (`Resource`): A reference to the `LogicGridMap` instance. This is crucial for the timespace to understand the spatial layout of the game world and validate movements.
*   **`_actors`** (`Array`, Default: `[]`): An internal array tracking all actors currently participating in the turn order.
*   **`_objects`** (`Array`, Default: `[]`): An internal array tracking static objects that participate in the timeline.
*   **`_actor_status`** (`Dictionary`, Default: `{}`): Internal tracking of actor statuses.
*   **`_tile_status`** (`Dictionary`, Default: `{}`): Internal tracking of tile statuses.
*   **`event_log`** (`Array`, Default: `[]`): An internal log for recording events related to the timespace, useful for debugging and replay.
*   **`_actions`** (`Dictionary`, Default: `{}`): Stores registered action definitions.
*   **`reaction_watchers`** (`Callable[]`, Default: `[]`): A list of callables that are notified when reaction windows open.

#### Methods

*   **`add_actor(actor: Object, initiative: int, action_points: int, pos: Vector2i, tie_break: int = -1) -> void`**
    Adds an `actor` to the turn order. The actor is sorted into the initiative queue based on its `initiative` value.
    *   `actor`: The game object (e.g., `BaseActor`) to add.
    *   `initiative`: An integer determining turn order (higher values act first).
    *   `action_points`: The initial action points for the actor.
    *   `pos`: The actor's starting `Vector2i` position on the grid.
    *   `tie_break`: An optional integer for deterministic tie-breaking in initiative.
*   **`start_round() -> void`**
    Resets action points for all actors and initiates a new round. This method triggers the `round_started` signal.
*   **`end_turn() -> void`**
    Advances the timeline to the next actor in the initiative order. This method triggers the `turn_ended` signal for the current actor and prepares for the next turn.
*   **`get_current_actor() -> Object`**
    Returns the `Object` representing the actor whose turn is currently active.
*   **`move_current_actor(to: Vector2i) -> bool`**
    A convenience method for performing the registered "move" action for the current actor. It delegates to the underlying `LogicGridMap` for spatial updates.
    *   `to`: The target `Vector2i` position for the move.
    *   **Returns:** `true` if the move was successful, `false` otherwise.
*   **`add_overwatcher(actor: Object, once_per_turn: bool = true) -> void`**
    Registers an `actor` to react when others move into its line of sight. This is part of the reaction system.
*   **`register_reaction_watcher(cb: Callable) -> void`**
    Allows external systems to subscribe a `Callable` that will be invoked when reaction windows open, providing details about the reaction opportunity.
*   **`serialize_event_log() -> String`**
    Serializes the internal `event_log` into a JSON string, suitable for saving or network transmission.
*   **`replay_event_log(json: String, handler: Callable) -> void`**
    Replays a sequence of events from a serialized JSON string, invoking the provided `handler` for each event. This is crucial for deterministic replays.
*   **`apply_status_to_actor(actor: Object, status: String, duration: int = 0, timing: String = "turn_start") -> void`**
    Applies a status effect to an `actor`. This method delegates to the `Statuses` module.
    *   `actor`: The actor to apply the status to.
    *   `status`: The ID of the status to apply.
    *   `duration`: How long the status lasts (0 for permanent).
    *   `timing`: When the status effect is evaluated (e.g., "turn_start", "turn_end").
*   **`create_snapshot() -> Dictionary`**
    Produces a serializable `Dictionary` capturing the entire current state of the timeline, useful for saving/loading game progress.
*   **`to_dict() -> Dictionary`** / **`from_dict(data: Dictionary) -> void`**
    Methods for serializing and deserializing the timespace's state to/from a dictionary.
*   **`register_action(id: String, cost: int, tags: Array, validator: Callable, executor: Callable) -> void`**
    Registers an action definition with the timespace.
    *   `id`: Unique ID for the action.
    *   `cost`: AP cost to perform.
    *   `tags`: Array of tags for the action.
    *   `validator`: A `Callable` to check if the action can be performed.
    *   `executor`: A `Callable` to execute the action's effects.
*   **`can_perform(actor: Object, action_id: String, payload: Variant = null) -> bool`**
    Checks if an actor can perform a registered action, using the action's validator.
*   **`perform(actor: Object, action_id: String, payload: Variant = null) -> bool`**
    Executes a registered action, using the action's executor.

#### Signals

*   **`round_started()`**: Emitted when a new round begins.
*   **`round_ended()`**: Emitted when a round ends.
*   **`battle_over(faction: Variant)`**: Emitted when all actors of a faction are defeated.
*   **`turn_started(actor: Variant)`**: Fired at the start of an actor's turn.
*   **`turn_ended(actor: Variant)`**: Fired after an actor finishes its turn.
*   **`ap_changed(actor: Variant, old: Variant, new: Variant)`**: Emitted when an actor's action points change.
*   **`action_performed(actor: Variant, action_id: Variant, payload: Variant)`**: Emitted when an action is successfully executed.
*   **`status_applied(target: Variant, status: Variant)`**: Emitted when a status is applied (delegated from `Statuses`).
*   **`status_removed(target: Variant, status: Variant)`**: Emitted when a status is removed (delegated from `Statuses`).
*   **`damage_applied(attacker: Variant, defender: Variant, amount: Variant)`**: Emitted when damage is dealt.
*   **`reaction_triggered(actor: Variant, data: Variant)`**: Emitted when a reaction opportunity occurs.
*   **`timespace_snapshot_created(snapshot: Variant)`**: Emitted when a game state snapshot is created.

## Integration Notes

-   **Deterministic Initiative:** For consistent and repeatable test results, always seed the random number generator (`_rng` member) if you are using it for initiative ordering. This ensures that the same sequence of turns occurs every time.
-   **Data-Driven Actions:** Actions are defined in a data-driven manner. The `validator` and `executor` parameters of `register_action()` are `Callable` objects. This allows you to inject game-specific logic (e.g., a function in another script) for validating and executing actions, making the system highly flexible.
-   **Event Logging for Audit and Replay:** The `event_log` is a powerful feature for debugging and replay functionality. Use `serialize_event_log()` to save the entire sequence of events, which can then be replayed later using `replay_event_log()` to perfectly recreate a game session.
-   **Status Tick Windows:** Status effects are evaluated at specific timing windows (`round_start`, `turn_start`, `turn_end`). When `status_removed` is emitted (from the `Statuses` module, often triggered by `timespace.tick_statuses()`), ensure that any external modifiers applied by that status are cleanly removed from the `Attributes` module.

## Testing

The `TurnBasedGridTimespace` module includes extensive self-tests covering various aspects of its functionality:

*   **Ordering:** Verifies correct initiative order.
*   **AP Spend:** Ensures action points are correctly deducted.
*   **Overwatch:** Tests the overwatch reaction system.
*   **Reaction Windows:** Validates the queuing and resolution of reactions.
*   **Status Durations:** Confirms that status effects tick down and expire correctly.
*   **Serialization:** Checks that the game state can be saved and loaded accurately.
*   **Event Log Schema:** Ensures that events are logged in a consistent and usable format.

You can run these tests headlessly via the shared test runner:

```bash
godot4 --headless --path . --script scripts/test_runner.gd -- --module=turn_timespace
```