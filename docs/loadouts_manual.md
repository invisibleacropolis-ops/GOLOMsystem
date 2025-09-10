# Loadouts Module Manual

`loadouts.gd` determines which abilities an actor can currently access.  Abilities can originate from base grants, equipped items, current statuses, or class features.

## Responsibilities

- Maintain separate lists for base, equipment, status, and class abilities.
- Provide `grant()`, `grant_from_equipment()`, `grant_from_status()`, and `grant_from_class()` helpers.
- Return the merged ability list via `get_available()`.

## Usage

```gdscript
var loadouts := Loadouts.new()
loadouts.grant(hero, "fireball")
loadouts.grant_from_equipment(hero, "slash")
var abilities := loadouts.get_available(hero) # ["fireball", "slash"]
```

## Integration Notes

- Class, equipment, and status effects can all contribute abilities without duplicating logic elsewhere.
- Consider pairing with the `Abilities` module: `get_available()` feeds UI hotbars or AI planners which then call `Abilities.execute()`.
- The `event_log` array records grant events and can be inspected for debugging.

## Testing

Execute the module test through the runner:

```bash
godot4 --headless --path . --script scripts/test_runner.gd -- --module=loadouts
```

The test grants abilities from multiple sources and ensures all appear in `get_available()`.

