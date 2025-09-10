# Grid Logic Module Manual

`grid_logic.gd` coordinates high-level tactical queries atop `LogicGridMap` and
now supports procedural world generation using noise-driven biomes.

## Responsibilities

- Wraps a `LogicGridMap` instance and exposes convenience helpers like
  `has_actor_at()` and `can_move()`.
- Computes threatened tiles through `threatened_tiles()`.
- Generates and swaps in new maps via `generate_world()`.

## Key Methods

| Method | Description |
|-------|-------------|
| `generate_world(width, height, seed)` | Replaces the current map with a noise-generated one and returns a color array for visualizers. |
| `can_move(actor, to)` | Pathfinds using the map and reports if the destination is reachable. |
| `threatened_tiles(actor)` | Returns tiles inside the actor's zone of control. |

## Testing

Run module tests via the shared runner:

```bash
godot4 --headless --path . --script scripts/test_runner.gd -- --module=grid_logic
```
