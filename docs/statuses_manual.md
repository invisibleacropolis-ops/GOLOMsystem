# Statuses Module Manual

`statuses.gd` defines the `Statuses` module, which is responsible for managing buffs, debuffs, and stances applied to actors or tiles. Each status tracks its stacks, duration, and any attribute modifiers that are applied when the status is active. This module centralizes the logic for applying, tracking, and removing these effects.

## Responsibilities

-   Store applied statuses in `actor_statuses` (and potentially `tile_statuses`) keyed by the affected entity.
-   Apply new statuses, increment stacks, set durations, and apply associated attribute modifiers through the `Attributes` module.
-   Provide a `tick()` method to decrement all status durations, remove expired statuses, clear their modifiers, emit relevant signals, and log events.
-   Notify other systems when statuses are applied or removed via signals.

## Core Concepts and API Details

The `Statuses` module is crucial for implementing dynamic gameplay effects that change an entity's properties over time or in response to events. It works closely with the `Attributes` module to modify an actor's stats.

### Class: `Statuses` (inherits from `Node`)

As a `Node`, `Statuses` can be integrated into your game's scene tree, often as part of a `RuntimeServices` aggregation.

#### Members

*   **`actor_statuses`** (`Dictionary`, Default: `{}`): This dictionary stores all active statuses applied to actors. It's typically keyed by the actor object, with values being arrays or dictionaries of status effects applied to that actor.
*   **`event_log`** (`Array`, Default: `[]`): An internal log for recording events related to status changes, useful for debugging.
*   **`attributes`** (`Variant`): A reference to the `Attributes` service. This is crucial because `Statuses` relies on `Attributes` to apply and remove the numerical effects of status modifiers. It must be set via `set_attributes_service()`.

#### Methods

*   **`log_event(t: String, actor: Object = null, pos: Variant = null, data: Variant = null) -> void`**
    Records structured events for debugging and tests. This is a general-purpose logging method used internally.
*   **`set_attributes_service(svc: Variant) -> void`**
    Sets the reference to the `Attributes` service. This method must be called before applying any statuses that have attribute modifiers.
    *   `svc`: An instance of the `Attributes` module.
*   **`apply_status(actor: Object, id: String, stacks: int = 1, duration: int = 1, modifiers: Array = []) -> void`**
    Applies a status effect to an `actor`.
    *   `actor`: The `Object` to which the status is applied.
    *   `id`: The unique string ID of the status (e.g., "poisoned", "stunned", "blessed").
    *   `stacks`: The number of stacks to apply (default: 1).
    *   `duration`: The number of turns/ticks the status will last (default: 1). A duration of 0 typically means permanent.
    *   `modifiers`: An `Array` of dictionaries, where each dictionary describes an attribute modifier to apply (e.g., `[{"key": "STR", "add": -5}]`). These modifiers are passed directly to `Attributes.add_modifier()`.
*   **`tick() -> void`**
    This method should be called once per game turn or round (typically by `TurnBasedGridTimespace`). It iterates through all active statuses, decrements their durations, removes any that have expired, clears their associated modifiers via `Attributes.clear_modifiers()`, and emits signals.
    *   **Returns:** `void`
*   **`run_tests() -> Dictionary`**
    Executes internal self-tests for the `Statuses` module, returning a dictionary of test results.

#### Signals

*   **`status_applied(target: Variant, status: Variant)`**
    Emitted whenever a new status effect is successfully applied to an actor or tile.
    *   `target`: The `Object` or `Vector2i` (for tiles) that received the status.
    *   `status`: The ID of the status that was applied.
*   **`status_removed(target: Variant, status: Variant)`**
    Emitted whenever a status effect is removed from an actor or tile (e.g., due to duration expiring, being dispelled).
    *   `target`: The `Object` or `Vector2i` from which the status was removed.
    *   `status`: The ID of the status that was removed.

## Usage

```gdscript
var statuses := Statuses.new()
var attrs := Attributes.new() # Assuming Attributes is also instantiated
statuses.set_attributes_service(attrs) # Link the Attributes service

var hero_actor = get_node("PlayerCharacter") # Assuming you have a player character node

# Apply a "stunned" status to the hero: 1 stack, lasts 1 turn, reduces Strength by 5
statuses.apply_status(hero_actor, "stunned", 1, 1, [{"key": "STR", "add": -5}])
print("Hero is stunned!")

# Simulate the passage of a turn
# This would typically be called by your TurnBasedGridTimespace module
statuses.tick()
print("Statuses ticked. Stunned status should now be removed.")

# Apply a "poisoned" status: 3 stacks, lasts 3 turns, deals 2 damage per tick
statuses.apply_status(hero_actor, "poisoned", 3, 3, [{"key": "HLTH", "add": -2, "source": "poison_tick"}])
print("Hero is poisoned!")

# You would then call statuses.tick() at the end of each turn to advance the poison.
```

## Integration Notes

-   **Dependency on `Attributes`:** The `Statuses` module relies heavily on the `Attributes` module to manage the numerical impact of status effects. Ensure that the `Attributes` service is properly set via `set_attributes_service()` before applying any statuses with modifiers.
-   **Duration Management:** The `tick()` method is the core of duration management. It should be called by your game's turn manager (e.g., `TurnBasedGridTimespace`) at appropriate intervals (e.g., at the start or end of each turn/round).
-   **Signals for Reactivity:** The `status_applied` and `status_removed` signals are crucial for keeping other parts of your game synchronized. UI elements can listen to these to display status icons, AI can react to buffs/debuffs, and other game systems can trigger effects based on status changes.
-   **Tile-Based Statuses:** The current `actor_statuses` member is for actors. To support tile-based statuses, you would extend the `Statuses` module to include a separate dictionary (e.g., `tile_statuses`) and corresponding `apply_status_to_tile()`, `get_statuses_for_tile()`, and `remove_status_from_tile()` methods. The `tick()` method would then need to iterate through both actor and tile statuses.

## Testing

Invoke the test runner to validate expiration and modifier cleanup:

```bash
godot4 --headless --path . --script scripts/test_runner.gd -- --module=statuses
```

This test ensures that statuses are correctly applied, their durations decrement as expected, and their associated attribute modifiers are properly cleared when the status expires, confirming the module's core functionality.