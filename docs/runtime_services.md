# Runtime Service Overview

This document summarizes the core logic modules that power the tactical runtime. Each module lives under `scripts/modules` and exposes a `run_tests()` helper so CI and engineers can validate behavior headlessly.

## Timespace (turn manager)
- Phases: `ROUND_START → ACTOR_START → ACTING → REACTION_WINDOWS → ACTOR_END → NEXT_ACTOR/ROUND_END`.
- Handles initiative, action point refresh, and deterministic ordering.
- Emits signals such as `round_started`, `turn_started(actor)`, `ap_changed(actor, old, new)`, and `action_performed(actor, action_id, payload)` so UI or AI layers can respond without tight coupling.

## Grid (spatial authority)
- Tracks bounds, occupancy, line of sight and area-of-effect templates.
- Supplies pathfinding, cover, and zone-of-control queries to other systems.

## Attributes
- Single source of truth for all numeric stats.
- Supports base values plus additive and multiplicative modifiers with sources and durations.
- All gameplay logic reads numbers via `get_value(actor, key)`.

## Statuses
- Buffs, debuffs, and stances applied to actors or tiles.
- Manage stacks and durations and notify when statuses expire so modifiers can be un-applied cleanly.

## Abilities
- Validates requirements (tags, resources, range) and executes ordered effect lists.
- Spends costs, sets cooldowns, and records to the event log.

## Loadouts
- Computes the abilities an actor can currently use based on traits, equipment, and active statuses.
- Feeds both UI hotbars and AI planners: "what can I use right now?"

## Reactions
- Subscribes to movement or action triggers and queues reaction abilities.
- Resolves queued reactions by priority while enforcing once-per-turn caps.

## Event Bus
- Append-only stream of structured entries describing every state change.
- Drives logging, analytics, and deterministic replays.

## Terrain
- Central registry of terrain types (grass, dirt, stone, etc.).
- Applies movement cost, LOS blockers, and tags to `LogicGridMap` tiles and allows runtime mutation.

## Real-world Usage

The `RuntimeServices` node lets gameplay scenes wire up core logic with minimal boilerplate.

```gdscript
var services := RuntimeServices.new()
add_child(services)
services.grid_map.width = 8
services.grid_map.height = 8
services.timespace.start_round()
```

Abilities can be customized at runtime before execution:

```gdscript
services.abilities.register_ability("fire_bolt", {
    "act_cost": 1,
    "chi_cost": 2,
    "cooldown": 1,
})
```

UI widgets can subscribe to timespace or status signals to react to changes:

```gdscript
func _ready() -> void:
    services.timespace.ap_changed.connect(_on_ap_changed)
    services.statuses.status_applied.connect(_on_status_applied)

func _on_ap_changed(actor, old_ap, new_ap) -> void:
    if actor == watched_actor:
        ap_label.text = str(new_ap)

func _on_status_applied(actor, id) -> void:
    if actor == watched_actor:
        status_panel.show_status(id)
```

## Testing

Execute the service's integration test and all module self-tests via the shared runner:

```bash
godot4 --headless --path . --script scripts/test_runner.gd -- --module=runtime_services
```

The test moves an actor through the timespace and delegates to each module's `run_tests()`.

**Pitfalls**

- When running headless tests, free instantiated modules (`services.free()`) to avoid leaking resources.
- Ensure `timespace.set_grid_map()` is invoked before starting the timespace; `RuntimeServices` handles this internally, but manual setups must call it explicitly.
