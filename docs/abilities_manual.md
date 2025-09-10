# Abilities Module Manual

`abilities.gd` validates and executes active abilities loaded from data files. Definitions include resource costs, cooldowns, and optional follow-up chains to support combo systems.

## Responsibilities

- Register ability definitions in the `catalog` dictionary or load them from JSON.
- Verify that an actor can use an ability through `can_use()` which checks cooldowns and resource costs (`ACT`, `CHI`).
- Execute ability logic, deduct resources, track cooldowns, and push structured entries into the `event_log`.

## Core Concepts and API Details

The `Abilities` module manages the lifecycle of in-game abilities. It provides a centralized system for defining, validating, and executing actions that characters can perform.

### Class: `Abilities` (inherits from `Node`)

This is the main class for managing abilities. It's a `Node`, meaning it can be added to your game scene tree and benefit from Godot's node features.

#### Members

*   **`catalog`** (`Dictionary`, Default: `{}`): This dictionary stores all registered ability definitions. When you `register_ability` or `load_from_file`, the ability data is added here, keyed by a unique ability ID. This acts as the central repository for all ability blueprints.
*   **`cooldowns`** (`Dictionary`, Default: `{}`): This dictionary tracks the current cooldown status for active abilities. When an ability is used, its cooldown is set here, and `tick_cooldowns()` reduces these counters over time.
*   **`event_log`** (`Array`, Default: `[]`): An array that records significant events related to abilities, such as an ability being used or damage being applied. This log is crucial for debugging, analytics, and potentially for replaying game states.

#### Methods

*   **`log_event(t: String, actor: Object = null, pos: Variant = null, data: Variant = null) -> void`**
    Records a structured event into the `event_log`. This is a general-purpose logging method used internally by the module to track ability-related occurrences.
*   **`register_ability(id: String, data: Dictionary) -> void`**
    Adds a new ability definition to the `catalog`.
    *   `id`: A unique string identifier for the ability (e.g., "fireball", "heal").
    *   `data`: A dictionary containing all the properties of the ability, such as its cost, cooldown, effects, and any follow-up abilities.
*   **`load_from_file(path: String) -> void`**
    Loads multiple ability definitions from a JSON file located at `path`. This is the primary way to populate the `catalog` with abilities defined by game designers.
*   **`tick_cooldowns() -> void`**
    Decrements all active cooldown counters by one. This method should be called once per game round or turn to advance the cooldowns of all abilities.
*   **`can_use(actor: Object, id: String, attrs: Variant = null) -> bool`**
    Checks if a given `actor` can currently use the ability identified by `id`. This method validates against cooldowns and resource costs (e.g., Action Points, Chi, etc., often managed by an `Attributes` module).
    *   `actor`: The game object attempting to use the ability.
    *   `id`: The ID of the ability to check.
    *   `attrs`: Optional additional attributes or context for the check.
    *   **Returns:** `true` if the actor can use the ability, `false` otherwise.
*   **`execute(actor: Object, id: String, target: Variant, attrs: Variant = null) -> Array`**
    Executes the logic for the ability identified by `id` for the given `actor` on a `target`. This method handles deducting costs, setting cooldowns, logging the usage, and returning any follow-up ability IDs (for combo systems).
    *   `actor`: The game object performing the ability.
    *   `id`: The ID of the ability to execute.
    *   `target`: The target of the ability (can be a position, another actor, etc.).
    *   `attrs`: Optional additional attributes or context for execution.
    *   **Returns:** An `Array` of follow-up ability IDs, if any.
*   **`run_tests() -> Dictionary`**
    Executes internal self-tests for the `Abilities` module, returning a dictionary of test results. Useful for continuous integration and development.

#### Signals

*   **`damage_applied(attacker: Variant, defender: Variant, amount: Variant)`**
    This signal is emitted whenever an ability successfully reduces a target's HP. External systems (like UI for damage numbers, or other game logic) can connect to this signal to react to damage events.
    *   `attacker`: The object that dealt the damage.
    *   `defender`: The object that received the damage.
    *   `amount`: The amount of HP removed.

### Class: `Abilities.DummyActor` (inherits from `RefCounted`)

This is a simple helper class, likely used for testing or as a basic placeholder for game entities that interact with the `Abilities` system. Being `RefCounted` means it's memory-managed by Godot and doesn't need to be part of the scene tree.

#### Members

*   **`HLTH`** (`int`, Default: `0`): Represents the health of this dummy actor. This suggests that the `Abilities` module (or related systems like `Attributes`) might interact with an `HLTH` property on actors to manage health-related effects.

## Example

```gdscript
var abilities := Abilities.new()
abilities.load_from_file("res://data/actions.json")

# Assuming 'player_actor' is an Object with relevant properties (like health, resources)
# and 'enemy_target' is another Object.
# 'attrs' could be a dictionary of additional context, e.g., {"critical_hit": true}
var follow_up_abilities = abilities.execute(player_actor, "strike", enemy_target, {"damage_multiplier": 1.5})

if follow_up_abilities.size() > 0:
    print("Player performed a combo! Follow-up abilities: " + str(follow_up_abilities))

# Advance cooldowns each round
abilities.tick_cooldowns()
```

## Integration Notes

-   **External Systems Interaction:** Systems like `Loadouts` (which manage what abilities an actor has equipped) or UI hotbars should call `can_use()` before enabling an ability button or option. This ensures that players only see actionable abilities.
-   **Data-Driven Design:** Ability data is externalized to `data/actions.json` and similar files. This is a crucial design choice that allows game designers to tweak ability costs, effects, and other parameters without requiring code changes or recompilation. This speeds up iteration and balancing.
-   **Event Logging for Analysis:** The `event_log` array is a powerful feature. Each entry is a structured dictionary (e.g., `{"t": "ability", "actor": actor, "id": id, "target": target}`). This log can be used for:
    *   **Debugging:** Understanding the sequence of events that led to a particular game state.
    *   **Analytics:** Collecting data on ability usage, effectiveness, and player behavior.
    *   **Deterministic Replay:** Potentially replaying game sessions by re-executing events from the log, which is valuable for testing and competitive play analysis.

## Testing

Invoke the module's self-test through the shared runner:

```bash
godot4 --headless --path . --script scripts/test_runner.gd -- --module=abilities
```

The test loads actions from JSON and verifies cost spending, cooldown ticking, and follow-up chains, ensuring the core mechanics of the `Abilities` module function as expected.