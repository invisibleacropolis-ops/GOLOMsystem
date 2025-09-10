# Terrain Module Manual

`terrain.gd` defines the `Terrain` module, which centralizes terrain type definitions used by `LogicGridMap`. It loads a default set of terrain rules from `data/terrain.json` and allows runtime modification or registration of new types. This service can apply terrain properties to tiles on a `LogicGridMap`, dynamically updating movement costs, line-of-sight (LOS) blockers, and tag arrays in real time.

## Responsibilities

-   Load and store a catalog of terrain definitions.
-   Provide helpers to register new terrain types and mutate existing ones.
-   Apply terrain data to map tiles, synchronizing tags, movement cost and
    LOS blockers.
-   Query terrain IDs by tag for grouping or procedural generation.

## Core Concepts and API Details

The `Terrain` module acts as a registry for all terrain types in the game. By centralizing terrain definitions, it ensures consistency across the game world and allows for easy modification and extension of terrain properties.

### Class: `Terrain` (inherits from `Node`)

As a `Node`, `Terrain` can be integrated into your game's scene tree, often as part of a `RuntimeServices` aggregation.

#### Members

*   **`definitions`** (`Dictionary`, Default: `{}`): This dictionary stores all loaded and registered terrain definitions, keyed by their unique string ID. Each value is a dictionary containing the properties of that terrain type.
*   **`event_log`** (`Array`, Default: `[]`): An internal log for recording events related to terrain changes, useful for debugging.

#### Methods

*   **`log_event(t: String, actor: Object = null, pos: Variant = null, data: Variant = null) -> void`**
    Records structured events for debugging and tests. This is a general-purpose logging method used internally.
*   **`load_from_file(path: String) -> void`**
    Replaces the current set of terrain definitions with those loaded from a JSON file at the specified `path`. This is typically used to load the initial terrain data.
    *   `path`: The file path to the JSON file containing terrain definitions.
*   **`register_type(id: String, data: Dictionary) -> void`**
    Adds a new terrain definition or overrides an existing one. This allows for dynamic creation or modification of terrain types at runtime.
    *   `id`: The unique string ID for the terrain type (e.g., "forest", "swamp").
    *   `data`: A `Dictionary` containing the properties of the terrain type (e.g., `{"move_cost": 2, "blocks_vision": false, "tags": ["natural", "forest"]}`).
*   **`get_type(id: String) -> Dictionary`**
    Fetches a specific terrain definition by its ID.
    *   `id`: The unique string ID of the terrain type.
    *   **Returns:** A `Dictionary` containing the terrain properties, or `null` if not found.
*   **`set_property(id: String, key: String, value: Variant) -> void`**
    Mutates a single property of an existing terrain definition. This is useful for dynamic changes to terrain behavior (e.g., making a "water" tile temporarily walkable).
    *   `id`: The ID of the terrain type to modify.
    *   `key`: The name of the property to change (e.g., "move_cost", "blocks_vision").
    *   `value`: The new value for the property.
*   **`get_with_tag(tag: String) -> Array[String]`**
    Returns an array of terrain IDs that include a specific `tag`. This is useful for querying terrain types based on shared characteristics.
    *   `tag`: The tag to search for (e.g., "walkable", "liquid").
    *   **Returns:** An `Array` of `String`s, where each string is a terrain ID.
*   **`apply_to_map(map: LogicGridMap, pos: Vector2i, id: String) -> void`**
    Applies the properties of a specified terrain type (`id`) to a tile at `pos` on a `LogicGridMap`. This method updates the `LogicGridMap`'s internal data, synchronizing properties like movement cost, LOS blockers, and tags.
    *   `map`: The `LogicGridMap` instance to modify.
    *   `pos`: The `Vector2i` coordinates of the tile to update.
    *   `id`: The ID of the terrain type to apply.
*   **`run_tests() -> Dictionary`**
    Executes internal self-tests for the `Terrain` module, returning a dictionary of test results.

## Default Terrain Types

The default terrain types are defined in `data/terrain.json`. These include:

-   `grass`
-   `dirt`
-   `stone`
-   `wood_floor`
-   `stone_floor`
-   `water`
-   `paved`
-   `road`

Each terrain type typically includes properties like `move_cost` (how many AP it costs to move onto), `is_walkable`, `is_buildable`, `is_flammable`, `is_liquid`, `blocks_vision` (for LOS calculations), and custom `tags` (e.g., "natural", "urban").

## Usage Example

```gdscript
var terrain_service := Terrain.new()
add_child(terrain_service) # Add to scene tree if not part of RuntimeServices

# Load default terrain definitions from file
terrain_service.load_from_file("res://data/terrain.json")

# Register a new custom terrain type at runtime
terrain_service.register_type("lava", {
    "move_cost": 5,
    "is_walkable": false,
    "is_flammable": true,
    "blocks_vision": false,
    "tags": ["hazard", "hot"]
})

# Mutate a property of an existing terrain type
terrain_service.set_property("water", "move_cost", 3) # Make water more difficult to traverse

# Get terrain IDs that are "walkable"
var walkable_terrains = terrain_service.get_with_tag("walkable")
print("Walkable terrains: " + str(walkable_terrains))

# Apply a terrain type to a tile on your LogicGridMap
var my_logic_grid_map := LogicGridMap.new() # Assuming you have a LogicGridMap instance
my_logic_grid_map.width = 10
my_logic_grid_map.height = 10
terrain_service.apply_to_map(my_logic_grid_map, Vector2i(5, 5), "lava")
print("Tile at (5,5) is now lava.")
```

## Integration Notes

-   **Synchronization with `LogicGridMap`:** The `apply_to_map()` method is crucial for synchronizing terrain properties with the `LogicGridMap`. When you change a terrain type on a tile, this method ensures that the `LogicGridMap`'s internal data (movement costs, LOS blockers, tags) is updated accordingly.
-   **Data-Driven Design:** By defining terrain types in a JSON file, designers can easily modify and add new terrain behaviors without requiring code changes.
-   **Dynamic World:** The `register_type()` and `set_property()` methods allow for dynamic changes to the game world, enabling events like floods, fires, or magical transformations that alter terrain properties.

## Testing

The `run_tests()` method verifies applying terrain to a map, updating a property at runtime, and filtering by tags. You can execute these tests via the shared runner:

```bash
godot4 --headless --path . --script scripts/test_runner.gd -- --module=terrain
```

This ensures the `Terrain` module functions correctly and consistently applies its definitions to the game's logical grid.