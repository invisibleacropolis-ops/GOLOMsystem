# Reactions Module Manual

`reactions.gd` queues interrupt abilities such as attacks of opportunity or overwatch shots.  Reactions are prioritized so higher scores resolve first and AI can inspect the queue before execution.

## Responsibilities

- Accumulate triggers via `trigger(actor, data, priority)`.
- Expose `resolve_next()` to pop the highest-priority reaction.
- Allow planners to inspect the queue through `get_pending()` and the `reaction_queued` signal.
- Log each trigger in `event_log` for later inspection.

## Usage

```gdscript
var reactions := Reactions.new()
reactions.trigger(enemy, {"type": "overwatch", "target": hero}, 10)
var next := reactions.resolve_next()
if next:
    print("Reacting actor: %s" % next.actor)
```

## Integration Notes

- The module does not automatically execute abilities.  Call `Abilities.execute()` once `resolve_next()` returns an item.
- To enforce limits like "once per turn," store additional metadata in the queued entry and filter when triggering.
- Extend `trigger()` to subscribe to signals from `TurnBasedGridTimespace` or `LogicGridMap` for movement and action events.
- AI systems can observe `reaction_queued` or call `get_pending()` to inspect reactions before resolving them.

## Testing

Run the self-test through the standard runner:

```bash
godot4 --headless --path . --script scripts/test_runner.gd -- --module=reactions
```

The test enqueues two reactions and verifies the higher-priority entry resolves first.

