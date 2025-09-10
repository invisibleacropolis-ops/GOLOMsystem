# Terrain Module Manual

`terrain.gd` centralizes terrain type definitions used by `LogicGridMap`.
It loads a default set of terrain rules from `data/terrain.json` and allows
runtime modification or registration of new types. The service can apply
terrain properties to tiles on a `LogicGridMap`, updating movement costs,
line-of-sight blockers, and tag arrays in real time.

## Responsibilities

- Load and store terrain definitions.
- Provide helpers to register new terrain types and mutate existing ones.
- Apply terrain data to map tiles, synchronizing tags, movement cost and
  LOS blockers.
- Query terrain IDs by tag for grouping or procedural generation.

## Key Methods

| Method | Description |
|-------|-------------|
| `load_from_file(path)` | Replaces current definitions from a JSON file. |
| `register_type(id, data)` | Adds or overrides a terrain definition. |
| `set_property(id, key, value)` | Mutates a single property. |
| `get_with_tag(tag)` | Returns terrain IDs that include a tag. |
| `apply_to_map(map, pos, id)` | Writes terrain properties to a tile. |

## Default Terrain Types

Defined in `data/terrain.json`:
- grass
- dirt
- stone
- wood_floor
- stone_floor
- water
- paved
- road

Each includes properties like `move_cost`, `is_walkable`, `is_buildable`,
`is_flammable`, `is_liquid`, `blocks_vision`, and custom `tags`.

## Testing

`run_tests()` verifies applying terrain to a map, updating a property at
runtime, and filtering by tags.
