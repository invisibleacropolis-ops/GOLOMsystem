# Loadouts Module Manual

`loadouts.gd` defines the `Loadouts` module, which is responsible for determining and managing the set of abilities an actor can currently access. Abilities can originate from various sources, such as base grants, equipped items, current status effects, or class features. This module centralizes the logic for aggregating these abilities.

## Responsibilities

-   Maintain separate internal dictionaries for abilities granted from different sources (base, equipment, status, class).
-   Provide methods to grant abilities from these specific sources.
-   Return a merged list of all currently available abilities for a given actor via `get_available()`.
-   Offer cleanup helpers to prevent stale actor references and resource leaks.

## Core Concepts and API Details

The `Loadouts` module acts as a flexible system for managing an actor's active ability set. By categorizing abilities by their source, it allows for clear logic regarding how abilities are gained and lost (e.g., an ability from an equipped item is lost when the item is unequipped).

### Class: `Loadouts` (inherits from `Node`)

As a `Node`, `Loadouts` can be integrated into your game's scene tree, often as part of a `RuntimeServices` aggregation.

#### Members

*   **`base_abilities`** (`Dictionary`, Default: `{}`): Stores abilities that an actor possesses inherently or permanently, not tied to temporary effects or equipment.
*   **`equipment_abilities`** (`Dictionary`, Default: `{}`): Stores abilities granted specifically by equipped items.
*   **`status_abilities`** (`Dictionary`, Default: `{}`): Stores abilities granted by active status effects (buffs/debuffs).
*   **`class_abilities`** (`Dictionary`, Default: `{}`): Stores abilities granted by an actor's class or profession.
*   **`event_log`** (`Array`, Default: `[]`): An internal log for recording events related to loadout changes, useful for debugging.

The module automatically prunes entries associated with freed actors whenever `get_available()` is called.

#### Methods

*   **`log_event(t: String, actor: Object = null, pos: Variant = null, data: Variant = null) -> void`**
    Records structured events for debugging and tests. This is a general-purpose logging method used internally.
*   **`grant(actor: Object, ability_id: String) -> void`**
    Grants a base ability to the specified `actor`. This is typically for abilities an actor always has.
    *   `actor`: The actor receiving the ability.
    *   `ability_id`: The unique string ID of the ability to grant.
*   **`grant_from_equipment(actor: Object, ability_id: String) -> void`**
    Grants an ability to the `actor` specifically due to an equipped item.
    *   `actor`: The actor receiving the ability.
    *   `ability_id`: The unique string ID of the ability from equipment.
*   **`grant_from_status(actor: Object, ability_id: String) -> void`**
    Grants an ability to the `actor` due to an active status effect.
    *   `actor`: The actor receiving the ability.
    *   `ability_id`: The unique string ID of the ability from a status.
*   **`grant_from_class(actor: Object, ability_id: String) -> void`**
    Grants an ability to the `actor` based on its class or profession.
    *   `actor`: The actor receiving the ability.
    *   `ability_id`: The unique string ID of the ability from a class.
*   **`get_available(actor: Object) -> String[]`**
    Returns a merged `Array` of unique string IDs for all abilities currently available to the specified `actor` from all sources (base, equipment, status, class). This is the primary method for querying an actor's current ability set.
    *   `actor`: The actor whose available abilities are being queried.
    *   **Returns:** An `Array` of `String`s, where each string is an ability ID.
*   **`cleanup_actor(actor: Object) -> void`**
    Removes any ability references for the specified `actor`. Call this when an actor leaves the game to avoid holding onto stale references.
*   **`clear() -> void`**
    Wipes all internal dictionaries and the event log. Useful for tests and verifying that no residual data remains.
*   **`run_tests() -> Dictionary`**
    Executes internal self-tests for the `Loadouts` module, returning a dictionary of test results.

## Usage

```gdscript
var loadouts := Loadouts.new()
var hero_actor = get_node("PlayerCharacter") # Assuming you have a player character node

# Grant a base ability
loadouts.grant(hero_actor, "basic_attack")

# Grant an ability from equipped gear
loadouts.grant_from_equipment(hero_actor, "shield_bash")

# Grant an ability from a temporary buff status
loadouts.grant_from_status(hero_actor, "berserk_rage")

# Grant an ability from the actor's class
loadouts.grant_from_class(hero_actor, "fireball")

# Get all abilities currently available to the hero
var available_abilities := loadouts.get_available(hero_actor)
print("Hero's available abilities: " + str(available_abilities))
# Expected output (order may vary): ["basic_attack", "shield_bash", "berserk_rage", "fireball"]

# Example: If the "berserk_rage" status expires, you would remove its granted ability
# loadouts.remove_from_status(hero_actor, "berserk_rage") # (Assuming a remove method exists or you manage it by clearing the status)
# available_abilities = loadouts.get_available(hero_actor)
# print("Hero's abilities after status expires: " + str(available_abilities))
```

## Integration Notes

-   **Categorized Ability Management:** The `Loadouts` module's internal structure (separate dictionaries for `base_abilities`, `equipment_abilities`, etc.) is key. This allows for precise control over when abilities are gained or lost. For example, when an item is unequipped, you would call a corresponding "remove from equipment" method (if implemented) to ensure the ability is no longer available.
-   **Pairing with `Abilities` Module:** The `Loadouts` module works hand-in-hand with the `Abilities` module. `get_available()` provides the list of *what* abilities an actor has. This list then feeds into UI hotbars or AI planners, which then call `Abilities.can_use()` to check if an ability is currently usable (considering cooldowns, resource costs) and `Abilities.execute()` to perform the ability.
-   **Debugging with `event_log`:** The `event_log` array records grant events. Inspecting this log can be very helpful for debugging issues related to abilities not appearing or disappearing as expected.

## Testing

Execute the module's self-test through the shared runner to verify its functionality:

```bash
godot4 --headless --path . --script scripts/test_runner.gd -- --module=loadouts
```

This test typically grants abilities from multiple sources (simulating equipment, statuses, etc.) and then ensures that `get_available()` correctly returns all granted abilities, confirming the module's ability aggregation logic.