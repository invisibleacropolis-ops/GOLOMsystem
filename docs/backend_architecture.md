# Backend Architecture

This document outlines how Golom's tactical backend modules communicate during a turn.

## Data Flow Overview

```
                      +----------------+
                      |    EventBus    |
                      +--------^-------+
                               |
                               | push()/log_event
+----------------------+-------+----------------------+
|          TurnBasedGridTimespace                      |
|  - emits round/turn and AP signals                   |
|  - records structured events                         |
+----^-----------+-------------+-----------^-----------+
     |           |             |           |
     |           |             |           +-- reaction_triggered
     |           |             |                      |
     |           |             |                      v
     |           |             |                +------------+
     |           |             |                | Reactions  |
     |           |             |                +------------+
     |           |             |
     |           |     status_applied/removed
     |           v             |
     |     +-----------+       |
     |     | Statuses  |-------+
     |     +-----------+       |
     |           ^             |
     |           | modifiers   |
     |       +-----------+     |
     |       | Attributes|<----+
     |       +-----------+
     |           ^
     |           | checks costs
     |     +-----------+
     |     | Abilities |
     |     +-----------+
     |           ^
     |           | grants
     |     +-----------+
     |     | Loadouts  |
     |     +-----------+
     |
move_actor()/LOS
     |
     v
+-----------+
|LogicGridMap|
+-----------+
```

## Typical Turn Sequence

1. **Round start** – `TurnBasedGridTimespace.start_round()` resets each actor's action points, emits `round_started`, logs the event, and ticks statuses before the first turn begins【F:scripts/modules/turn_timespace.gd†L139-L147】.
2. **Turn begins** – `_begin_actor_turn()` fires `turn_started` and applies any `turn_start` statuses to the active actor【F:scripts/modules/turn_timespace.gd†L149-L160】.
3. **Ability selection** – External logic queries `Loadouts.get_available()` to list an actor's abilities, then `Abilities.can_use()` checks costs via the `Attributes` service【F:scripts/modules/loadouts.gd†L39-L45】【F:scripts/modules/abilities.gd†L35-L46】【F:scripts/modules/attributes.gd†L21-L66】.
4. **Action execution** – Movement calls `move_current_actor()`, which performs the registered `move` action and delegates to `LogicGridMap.move_actor()` for spatial updates【F:scripts/modules/turn_timespace.gd†L60-L68】【F:scripts/modules/turn_timespace.gd†L244-L250】【F:scripts/grid/grid_map.gd†L162-L195】. AP changes emit `ap_changed` and an `action_performed` signal【F:scripts/modules/turn_timespace.gd†L208-L229】.
5. **Reactions** – After movement, `_check_overwatch()` uses `LogicGridMap.has_line_of_sight()` to determine if any watchers should react, emitting `reaction_triggered` and handing the window to reaction watchers such as the `Reactions` module【F:scripts/modules/turn_timespace.gd†L263-L281】【F:scripts/grid/grid_map.gd†L297-L336】【F:scripts/modules/reactions.gd†L17-L21】.
6. **Status handling** – Abilities or other effects may call `apply_status_to_actor()`, emitting `status_applied`; durations tick and expired effects emit `status_removed` at turn or round boundaries【F:scripts/modules/turn_timespace.gd†L285-L345】【F:scripts/modules/statuses.gd†L1-L52】.
7. **Event logging** – Each module records structured dictionaries that can be pushed to the shared `EventBus` for analytics and replay【F:scripts/modules/event_bus.gd†L4-L10】【F:scripts/modules/turn_timespace.gd†L70-L72】【F:scripts/modules/attributes.gd†L17-L19】.
8. **Turn end** – `end_turn()` emits `turn_ended`, ticks `turn_end` statuses, and advances to the next actor or ends the round with `round_ended`【F:scripts/modules/turn_timespace.gd†L168-L185】.

Together these modules form a loosely coupled backend where signals and method calls coordinate spatial updates, ability usage, and reactive effects while all significant events flow into a central log.
