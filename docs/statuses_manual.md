# Statuses Module Manual

`statuses.gd` manages buffs, debuffs, and stances applied to actors or tiles.  Each status tracks stacks, duration, and any attribute modifiers applied when the status is active.

## Responsibilities

- Store applied statuses in `actor_statuses` keyed by actor.
- `apply_status(actor, id, stacks, duration, modifiers)` increments stacks, sets duration, and applies modifiers through `Attributes`.
- `tick()` decrements all durations, removes expired statuses, clears modifiers, emits signals, and logs events.

## Usage

```gdscript
var statuses := Statuses.new()
statuses.set_attributes_service(attrs)
statuses.apply_status(hero, "stunned", 1, 1, [{"key": "STR", "add": -5}])
statuses.tick() # removes "stunned", clears modifiers, and emits `status_removed`
```

## Integration Notes

- Status changes emit `status_applied` and `status_removed` signals so `Attributes` or AI layers can react automatically.
- Extend `apply_status()` to support tile-based statuses by storing them in a separate dictionary.

## Testing

Invoke the test runner to validate expiration and modifier cleanup:

```bash
godot4 --headless --path . --script scripts/test_runner.gd -- --module=statuses
```

