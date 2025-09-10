# Turn-Based Grid Timespace Manual

`turn_timespace.gd` orchestrates the tactical timeline.  It owns initiative order, action points, overwatch reactions, explicit reaction windows, status ticking, and serialization with replay support.

## Responsibilities

- Maintain round and turn state via an internal state machine.
- Track actors with initiative, action points, and positions on a `LogicGridMap`.
- Emit signals (`round_started`, `turn_started`, `ap_changed`, `action_performed`, etc.) so UI or AI layers can react.
- Register actions with validators and executors through `register_action()` and invoke them via `perform()`.
- Apply and tick status effects on actors and tiles, emitting callbacks to update `Attributes`.
- Create deterministic snapshots with `to_dict()` / `from_dict()` and serialize the `event_log` for replay.

## Core API

| Function | Purpose |
|----------|---------|
| `add_actor(actor, init, ap, pos, tie_break)` | Insert an actor and sort by initiative. |
| `start_round()` / `end_turn()` | Advance the timeline and emit signals. |
| `get_current_actor()` | Returns the actor whose turn is active. |
| `move_current_actor(to)` | Convenience for performing the registered `move` action. |
| `add_overwatcher(actor, once_per_turn)` | Register actors that should react when others move into line of sight. |
| `register_reaction_watcher(cb)` | Subscribe a callable that receives reaction windows after actions. |
| `serialize_event_log()` / `replay_event_log(json, handler)` | Persist and replay timeline events. |
| `apply_status_to_actor(actor, status, duration, timing)` | Attach a status effect evaluated at specific timing windows. |
| `create_snapshot()` | Produce a serializable dictionary capturing the entire timeline state. |

## Integration Notes

- Always seed `_rng` for deterministic initiative order in tests.
- Actions are data driven; validators and executors are `Callable` objects so you can inject game-specific logic.
- Use `event_log` for audit trails or replay functionality and serialize it with `serialize_event_log()`.
- Status ticks occur on `round_start`, `turn_start`, and `turn_end`.  Ensure external modifiers are cleaned up when `status_removed` is emitted.

## Testing

The module includes extensive self-tests covering ordering, AP spend, overwatch, reaction windows, status durations, serialization, and event log schema.
Run them via:

```bash
godot4 --headless --path . --script scripts/test_runner.gd -- --module=turn_timespace
```

