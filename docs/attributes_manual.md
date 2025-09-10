# Attributes Module Manual

`attributes.gd` centralizes all numeric statistics for actors.  By funnelling reads through a single service, formulas remain consistent and easy to audit. The module now supports percentage modifiers and clamped ranges to keep values within defined bounds.

## Responsibilities

- Store base values per actor/key pair.
- Apply additive, multiplicative, and percentage modifiers with optional sources and durations.
- Provide `get_value()` to query the final stat after all modifiers and ranges.
- Record operations in `event_log` for debugging.

## Key Methods

| Method | Description |
|-------|-------------|
| `set_base(actor, key, value)` | Define the unmodified value for a stat. |
| `add_modifier(actor, key, add, mul, source, duration, perc)` | Push a modifier entry with additive and percentage components. |
| `clear_modifiers(actor, source)` | Remove all modifiers originating from `source`. |
| `set_range(key, min, max)` | Clamp a stat to a range. |
| `get_value(actor, key)` | Compute the base plus modifiers and clamp to range. |

## Usage Pattern

```gdscript
var attrs := Attributes.new()
attrs.set_base(hero, "HLTH", 50)
attrs.set_range("HLTH", 0, 100)
attrs.add_modifier(hero, "HLTH", 25, 1.0, "buff")
attrs.add_modifier(hero, "HLTH", 0.0, 1.0, "buff2", 0, 0.5)
var total := attrs.get_value(hero, "HLTH") # 100 after clamp
```

## Integration Notes

- Always query stats via `get_value()`; do not read actor fields directly.
- `duration` is stored but not decremented automatically.  Higher-level systems such as `Statuses` should call `clear_modifiers` when needed.
- Persist `base_values` and `modifiers` dictionaries if you need to save actor state.

## Testing

Run the module's built-in test:

```bash
godot4 --headless --path . --script scripts/test_runner.gd -- --module=attributes
```

The test clamps health to 100 even after additive and percentage bonuses.

