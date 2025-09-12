# Reactions Module Manual

`reactions.gd` defines the `Reactions` module, which is designed to queue and manage interrupt abilities such as attacks of opportunity or overwatch shots. This module ensures that reactive actions are handled in a structured and prioritized manner, allowing for complex tactical gameplay.

## Responsibilities

-   Accumulate reaction triggers via the `trigger()` method.
-   Prioritize queued reactions so that higher-priority entries resolve first.
-   Expose `resolve_next()` to pop the highest-priority reaction from the queue.
-   Allow AI planners or other systems to inspect the current queue through `get_pending()` and the `reaction_queued` signal.
-   Log each reaction trigger in the `event_log` for later inspection and debugging.
-   Provide utilities to prune released actors and clear the queue during teardown.

## Core Concepts and API Details

The `Reactions` module provides a flexible system for handling actions that occur in response to other events, outside of the normal turn order. This is crucial for dynamic and responsive combat systems.

### Class: `Reactions` (inherits from `Node`)

As a `Node`, `Reactions` can be integrated into your game's scene tree, often as part of a `RuntimeServices` aggregation.

#### Members

*   **`queued`** (`Array`, Default: `[]`): This array stores all the reaction entries that have been triggered and are awaiting resolution. Entries are typically dictionaries containing information about the reacting actor, the type of reaction, and any relevant data.
*   **`event_log`** (`Array`, Default: `[]`): An internal log for recording events related to reactions, useful for debugging.

Stale reactions referencing freed actors are automatically removed when resolving or inspecting the queue.

#### Methods

*   **`log_event(t: String, actor: Object = null, pos: Variant = null, data: Variant = null) -> void`**
    Records structured events for debugging and tests. This is a general-purpose logging method used internally.
*   **`trigger(actor: Object, data: Variant, priority: int = 0) -> void`**
    Queues a new reaction. This method is called by other modules when a condition for a reaction is met.
    *   `actor`: The `Object` representing the actor that is reacting.
    *   `data`: A `Variant` (typically a `Dictionary`) containing details about the reaction (e.g., type of reaction, target, specific ability ID).
    *   `priority`: An `int` value that determines the order of resolution. Higher priority reactions are resolved before lower priority ones.
*   **`resolve_next() -> Variant`**
    Pops and returns the highest-priority reaction from the `queued` array. Once a reaction is resolved, it is removed from the queue.
    *   **Returns:** A `Variant` (typically a `Dictionary`) representing the reaction entry, or `null` if the queue is empty.
*   **`get_pending() -> Array`**
    Returns a copy of the `queued` array, allowing other systems to inspect the reactions that are currently awaiting resolution without modifying the queue.
    *   **Returns:** An `Array` of `Variant`s (reaction entries).
*   **`cleanup_actor(actor: Object) -> void`**
    Removes any queued reactions associated with `actor`. Call this when an actor exits the game to prevent leaks.
*   **`clear() -> void`**
    Empties the queue and event log entirely. Primarily intended for tests and debugging.
*   **`run_tests() -> Dictionary`**
    Executes internal self-tests for the `Reactions` module, returning a dictionary of test results.

#### Signals

*   **`reaction_queued(reaction: Variant)`**
    Emitted whenever a new reaction is added to the `queued` array via the `trigger()` method. Other systems (e.g., UI to display a "reaction window" or AI to re-evaluate its plan) can connect to this signal.
    *   `reaction`: The `Variant` (reaction entry) that was just queued.

## Usage

```gdscript
var reactions := Reactions.new()

# Example: A movement event triggers an overwatch reaction
var enemy_actor = get_node("Enemy") # Assuming an enemy actor
var hero_actor = get_node("Player") # Assuming a player actor

# Trigger an overwatch reaction with a priority of 10
reactions.trigger(enemy_actor, {"type": "overwatch", "target": hero_actor, "ability_id": "overwatch_shot"}, 10)

# Trigger another reaction with a lower priority
reactions.trigger(hero_actor, {"type": "defensive_stance"}, 5)

# Resolve the next highest-priority reaction
var next_reaction := reactions.resolve_next()
if next_reaction:
    print("Reacting actor: %s" % next_reaction.actor.name)
    print("Reaction data: %s" % next_reaction.data)
    # Now, you would typically execute the ability associated with this reaction
    # For example: Abilities.execute(next_reaction.actor, next_reaction.data.ability_id, next_reaction.data.target)
else:
    print("No pending reactions.")

# Inspect the remaining queue
var pending_reactions := reactions.get_pending()
print("Pending reactions count: " + str(pending_reactions.size()))
```

## Integration Notes

-   **Decoupled Execution:** The `Reactions` module does not automatically execute abilities. It only queues and resolves the *opportunity* for a reaction. Once `resolve_next()` returns an item, your game logic (e.g., within `TurnBasedGridTimespace` or an AI system) should then call `Abilities.execute()` (or similar) to perform the actual ability. This separation allows for more complex decision-making (e.g., AI deciding whether to use a reaction).
-   **Limiting Reactions:** To enforce limits like "once per turn" or "only one reaction per actor," you should store additional metadata within the queued reaction entry (`data` dictionary) and implement filtering logic when calling `trigger()`. This ensures that only valid reactions are added to the queue.
-   **Event-Driven Triggers:** Extend the `trigger()` method or create wrapper functions that subscribe to signals from other core modules like `TurnBasedGridTimespace` (for movement, action events) or `LogicGridMap` (for spatial events like entering a specific area). This allows reactions to be automatically queued based on game events.
-   **AI Integration:** AI systems can observe the `reaction_queued` signal or periodically call `get_pending()` to inspect the reactions awaiting resolution. This allows AI to make informed decisions about whether to use a reaction, potentially considering its own resources or tactical situation, before calling `resolve_next()`.

## Testing

Run the module's self-test through the standard runner to verify its functionality:

```bash
godot4 --headless --path . --script scripts/test_runner.gd -- --module=reactions
```

The test typically enqueues two reactions with different priorities and verifies that the higher-priority entry resolves first, confirming the module's prioritization logic.