# Abilities Module Manual

`abilities.gd` validates and executes active abilities loaded from data files.  Definitions include resource costs, cooldowns, and optional follow-up chains to support combo systems.

## Responsibilities

- Register ability definitions in the `catalog` dictionary or load them from JSON.
- Verify that an actor can use an ability through `can_use()` which checks cooldowns and resource costs (`ACT`, `CHI`).
- Execute ability logic, deduct resources, track cooldowns, and push structured entries into the `event_log`.

## Key Methods

| Method | Description |
|-------|-------------|
| `register_ability(id, data)` | Adds an ability definition.  `data` can include costs, cooldown, effects, and follow-up chains. |
| `load_from_file(path)` | Reads a JSON file of ability definitions at runtime. |
| `can_use(actor, id, attrs)` | Validates cooldowns and resource availability via `Attributes`. |
| `execute(actor, id, target, attrs)` | Spends costs, sets cooldowns, logs usage, and returns any follow-up ability IDs. |
| `tick_cooldowns()` | Decrements all cooldown counters each round. |

## Example

```gdscript
var abilities := Abilities.new()
abilities.load_from_file("res://data/actions.json")
var follow := abilities.execute(actor, "strike", target, attrs)
```

## Integration Notes

- Outside systems such as `Loadouts` or UI hotbars should call `can_use()` before enabling an ability.
- Ability data is externalized to `data/actions.json` and similar files so designers can tweak numbers without touching code.
- Use the `event_log` array for analytics or deterministic replay; each entry uses the form `{"t": "ability", "actor": actor, "id": id, "target": target}`.

## Testing

Invoke the module's self-test through the shared runner:

```bash
godot4 --headless --path . --script scripts/test_runner.gd -- --module=abilities
```

The test loads actions from JSON and verifies cost spending, cooldown ticking, and follow-up chains.

