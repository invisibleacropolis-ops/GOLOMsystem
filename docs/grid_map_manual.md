# LogicGridMap Manual

`grid/grid_map.gd` is a pure data Resource describing the tactical board.  It supports spatial queries, pathfinding, terrain tags, and area calculations without relying on visual nodes.

## Responsibilities

- Track actor positions and occupancy.
- Provide movement validation and execution through `move_actor()` and `remove_actor()`.
- Compute distances, line of sight, pathfinding, area-of-effect shapes, zones of control, and flanking detection.
- Store per-tile metadata such as movement costs, height, tags, and cover.
- Optional directional obstacles and diagonal movement rules for richer tactical constraints.

## Key Sections

### Actor Placement
- `is_in_bounds(pos)` and `is_occupied(pos)` guard movement.
- `move_actor(actor, to)` handles multi-tile footprints and updates `occupied` and `actor_positions` dictionaries.
- `get_occupied_tiles(actor)` returns all tiles an actor covers.

### Spatial Queries
- Distance helpers: `get_distance()` (Manhattan) and `get_chebyshev_distance()` (square radius).
- `has_line_of_sight(a, b)` uses Bresenham's algorithm with blockers and cover checks.
- `get_actors_in_radius()` and `get_positions_in_range()` support radial searches.

### Pathfinding
- `find_path(start, facing, goal, size)` implements A* with movement costs, turning penalties, and climb costs.
- `find_path_for_actor(actor, start, goal)` wraps `find_path` using the actor's size and facing.
- `set_diagonal_movement(enable)` toggles whether diagonals are considered during pathfinding.
- `place_obstacle(pos, orientation)` inserts walls that block movement in a given direction.

### Area of Effect
- `get_aoe_tiles(shape, origin, direction, range)` dispatches to helpers for burst, cone, line, and wall shapes.

### Tactical Logic
 - `get_zone_of_control(actor, radius, arc)` calculates threatened tiles around an actor.
 - `get_cover(pos)` and `set_cover(pos, type, direction, height)` manage directional cover with optional height.
 - Utility functions determine flanking, tile tags, height, and movement costs.

## Integration Notes

- Because `LogicGridMap` is a `Resource`, it can be saved and loaded without scene dependencies.
- Pair with `GridVisualLogic` for debugging visuals or with gameplay systems such as `TurnBasedGridTimespace` for movement validation.
- Use the `event_log` array to record operations when debugging complex movement bugs.

## Testing

While `LogicGridMap` lacks a dedicated self-test, it is exercised extensively by `turn_timespace.gd` tests.  When adding features, consider implementing a `run_tests()` similar to other modules.

