# Game Logic Overview

This project organizes tactical role-playing game logic into discrete Godot modules.  Each module owns a narrow slice of the ruleset and communicates with others through simple method calls or Godot signals.  This section gives outside engineers a high-level map for navigating the runtime.

## Core Concepts

- **LogicGridMap** – Pure data container for spatial queries, pathfinding, line of sight, and terrain tags.
- **TurnBasedGridTimespace** – State machine that advances rounds and turns, spends action points, and applies status effects.
- **Attributes** – Central authority for numeric stats.  All formulas read values through `get_value()` rather than touching actor fields directly.
- **Statuses** – Buffs and debuffs attached to actors or tiles.  Durations tick automatically when the timeline advances.
- **Abilities & Loadouts** – Definitions for active abilities and the rules that determine which abilities an actor can use right now.
- **Reactions** – Lightweight interrupt system for opportunity actions such as overwatch.
- **EventBus** – Append-only log capturing every significant state change for debugging or replay.
- **GridVisualLogic** – Immediate‑mode renderer for debugging grid state or powering a minimal UI.

Modules are intentionally decoupled so they can be instantiated or swapped independently inside tests or gameplay scenes.  The `scripts/test_runner.gd` scene shows how to run their self-tests headlessly.

## Execution Flow

1. `TurnBasedGridTimespace` starts a round and refreshes action points.
2. The current actor performs actions.  Validators consult `LogicGridMap`, `Attributes`, and `Statuses` for legality.
3. Reactions and overwatch may trigger, drawing on `Loadouts` and `Abilities`.
4. The `EventBus` records each change for telemetry or deterministic replays.

## Integration Tips

- Treat each module as a service.  Instantiate the ones you need and inject them into your game scene.
- Use signals (`turn_started`, `ap_changed`, `status_applied`, etc.) to keep UI and AI layers loosely coupled.
- Run module self-tests frequently with `godot4 --headless --path . --script scripts/test_runner.gd` to ensure deterministic behavior across platforms.
- When extending modules, keep public APIs minimal and prefer data‑driven dictionaries for new rules.

