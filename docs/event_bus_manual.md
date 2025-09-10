# EventBus Module Manual

The `event_bus.gd` module provides a lightweight, append-only log of game events.  Other systems push structured dictionaries here so analytics, replays, or debuggers can consume them later.

## Responsibilities

- Maintain the `entries` array of event dictionaries.
- Offer `push(evt)` to append events.
- Serialize and replay logs via `serialize()` and `replay()` for deterministic testing.

## Usage

```gdscript
var bus := EventBus.new()
bus.push({"t": "round_start", "round": 1})
var json := bus.serialize()
bus.replay(json, func(evt): print(evt))
```

## Integration Notes

- Standardize events to include a `t` field indicating the type.  Additional keys are free-form but should stay consistent for tooling.
- For deterministic replays, capture events from modules like `TurnBasedGridTimespace` and `Attributes` and persist the JSON returned by `serialize()`.
- `replay()` accepts a callback so tests or analytics tools can process events without mutating state.

## Testing

Run the shared test runner and ensure the module records a dummy entry and can replay it:

```bash
godot4 --headless --path . --script scripts/test_runner.gd -- --module=event_bus
```

