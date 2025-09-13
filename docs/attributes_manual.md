# Attributes Module Manual

`attributes.gd` centralizes all numeric statistics for actors. By funnelling reads through a single service, formulas remain consistent and easy to audit. The module now supports percentage modifiers and clamped ranges to keep values within defined bounds.

## Responsibilities

- Store base values per actor/key pair.
- Apply additive, multiplicative, and percentage modifiers with optional sources and durations.
- Provide `get_value()` to query the final stat after all modifiers and ranges.
- Record operations in `event_log` for debugging.

## Core Concepts and API Details

The `Attributes` module is designed to manage all numerical statistics (attributes) for game entities (actors). This centralized approach ensures consistency and simplifies debugging by providing a single source of truth for all attribute calculations.

### Class: `Attributes` (inherits from `Node`)

This is the main class for managing attributes. It's a `Node`, meaning it can be integrated into your game scene tree.

#### Members

*   **`base_values`** (`Dictionary`, Default: `{}`): This dictionary stores the fundamental, unmodified values for each attribute, keyed by actor and then by attribute name (e.g., `base_values[actor_id]["HLTH"] = 100`). These are the starting points before any modifiers are applied.
*   **`modifiers`** (`Dictionary`, Default: `{}`): This complex dictionary holds all active modifiers. Modifiers can be temporary (e.g., from buffs, debuffs, equipment) and are applied on top of `base_values`. They are typically structured to allow for additive, multiplicative, and percentage-based changes.
*   **`ranges`** (`Dictionary`, Default: `{}`): This dictionary defines the minimum and maximum allowed values for specific attributes. When `get_value()` is called, the final calculated value is clamped within these defined ranges.
*   **`event_log`** (`Array`, Default: `[]`): An array that records significant events related to attribute changes, such as a base value being set or a modifier being added/removed. This log is useful for debugging and analysis.

#### Methods

*   **`log_event(t: String, actor: Object = null, pos: Variant = null, data: Variant = null) -> void`**
    Records a structured event into the `event_log`. This is a general-purpose logging method used internally by the module to track attribute-related occurrences.
*   **`set_base(actor: Object, key: String, value: float) -> void`**
    Sets the fundamental, unmodified `value` for a specific `key` (attribute name) for a given `actor`. This is the starting point for all calculations.
    *   `actor`: The game object whose attribute is being set.
    *   `key`: The name of the attribute (e.g., "HLTH", "STR", "DEX").
    *   `value`: The base numerical value for the attribute.
*   **`add_modifier(actor: Object, key: String, add: float = 0.0, mul: float = 1.0, source: String = "", duration: int = 0, perc: float = 0.0) -> void`**
    Adds a new modifier entry to an actor's attribute. Modifiers are applied in a specific order: `add` (additive) first, then `mul` (multiplicative), and finally `perc` (percentage).
    *   `actor`: The game object affected by the modifier.
    *   `key`: The attribute being modified.
    *   `add`: An additive bonus (e.g., +5 HP).
    *   `mul`: A multiplicative factor (e.g., 1.2 for +20% damage).
    *   `source`: A string identifying the origin of the modifier (e.g., "buff", "equipment_sword", "poison_status"). This is crucial for `clear_modifiers`.
    *   `duration`: How many turns/ticks the modifier lasts (0 for permanent).
    *   `perc`: A percentage bonus (e.g., 0.1 for +10% of base value).
*   **`clear_modifiers(actor: Object, source: String) -> void`**
    Removes all modifiers that originated from a specific `source` for a given `actor`. This is essential for removing temporary effects like buffs or debuffs.
    *   `actor`: The game object whose modifiers are being cleared.
    *   `source`: The identifier of the modifiers to remove.
*   **`get_value(actor: Object, key: String) -> float`**
    Computes and returns the final, effective value of an attribute for a given `actor` and `key`. This method takes into account the base value, all active modifiers, and then clamps the result within any defined ranges. **Always use this method to query an actor's stats.**
    *   `actor`: The game object whose attribute value is being queried.
    *   `key`: The name of the attribute.
    *   **Returns:** The calculated final attribute value (float).
*   **`set_range(key: String, min_value: float, max_value: float) -> void`**
    Defines a clamped numerical range for a specific attribute `key`. Any value calculated for this attribute will not go below `min_value` or above `max_value`.
    *   `key`: The attribute name for which to define the range.
    *   `min_value`: The minimum allowed value.
    *   `max_value`: The maximum allowed value.
*   **`run_tests() -> Dictionary`**
    Executes internal self-tests for the `Attributes` module, returning a dictionary of test results. Useful for continuous integration and development.

## Usage Pattern

```gdscript
var attrs := Attributes.new()

# Define base health for 'hero' actor
attrs.set_base(hero, "HLTH", 50.0) # Base health is 50

# Define a clamped range for "HLTH" between 0 and 100
attrs.set_range("HLTH", 0.0, 100.0)

# Add a temporary buff that adds 25 to HLTH from source "buff"
attrs.add_modifier(hero, "HLTH", 25.0, 1.0, "buff", 5) # Lasts 5 turns

# Add a permanent percentage buff that adds 50% of base HLTH from source "permanent_buff"
attrs.add_modifier(hero, "HLTH", 0.0, 1.0, "permanent_buff", 0, 0.5)

# Calculate current health:
# Base (50) + Additive (25) + Percentage (50% of 50 = 25) = 100
var total_health := attrs.get_value(hero, "HLTH") # Result: 100 (clamped by range)

print("Hero's current health: " + str(total_health))

# After some turns, clear the "buff" modifier
# (Note: higher-level systems like Statuses would typically manage this duration)
# attrs.clear_modifiers(hero, "buff")
# total_health = attrs.get_value(hero, "HLTH") # Now: Base (50) + Percentage (25) = 75
```

## Integration Notes

-   **Centralized Queries:** It is critical to **always query an actor's statistics via `get_value()`**. Do not attempt to read actor fields directly, as this bypasses the modifier and clamping logic, leading to inconsistent and incorrect values.
-   **Duration Management:** The `duration` parameter in `add_modifier` is stored by the `Attributes` module but **not automatically decremented**. Higher-level systems, such as the `Statuses` module, are responsible for tracking the passage of time and calling `clear_modifiers` when a temporary effect expires. This separation of concerns keeps the `Attributes` module focused solely on calculation.
-   **State Persistence:** To save and load an actor's complete attribute state (for game saving/loading), you must persist the contents of the `base_values` and `modifiers` dictionaries. The `ranges` are typically static definitions and might not need to be saved per actor.

## Testing

Run the module's built-in test to verify its functionality:

```bash
godot4 --headless --path . --script scripts/test_runner.gd -- --module=attributes
```

The test suite specifically checks scenarios like health clamping (e.g., health not exceeding 100 even after additive and percentage bonuses), ensuring the core calculation and range enforcement mechanisms of the `Attributes` module function as expected.