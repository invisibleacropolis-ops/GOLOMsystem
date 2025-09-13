# Grid Logic Module Manual

`grid_logic.gd` coordinates high-level tactical queries atop `LogicGridMap` and now supports procedural world generation using noise-driven biomes. It acts as an intermediary, providing convenient methods for common grid-related operations that might involve multiple underlying systems.

## Responsibilities

-   Wraps and manages a `LogicGridMap` instance, exposing simplified helpers for common queries.
-   Provides methods to check for actor presence and retrieve actors at specific locations.
-   Determines if an actor can move to a target tile, considering pathfinding and obstacles.
-   Computes "threatened tiles" (e.g., tiles within an actor's zone of control or attack range).
-   Orchestrates procedural world generation, replacing the current map with a newly generated one.

## Core Concepts and API Details

The `GridLogic` module serves as a facade over the more granular `LogicGridMap` and `ProceduralWorld` modules. This simplifies interactions for higher-level game logic, allowing developers to perform complex grid operations with single method calls.

### Class: `GridLogic` (inherits from `Node`)

As a `Node`, `GridLogic` can be easily integrated into your game scene. It holds a reference to the active `LogicGridMap` instance.

#### Members

*   **`map`** (`Grid`, Default: `new()`): This member holds the active instance of the `LogicGridMap` (referred to as `Grid` in the API documentation). All spatial queries and updates performed by `GridLogic` are delegated to this underlying map.
*   **`event_log`** (`Array`, Default: `[]`): An internal log for recording events related to grid logic, useful for debugging.

#### Methods

*   **`log_event(t: String, actor: Object = null, pos: Variant = null, data: Variant = null) -> void`**
    Records structured events for debugging and tests. This is a general-purpose logging method used internally.
*   **`has_actor_at(pos: Vector2i) -> bool`**
    Checks if there is any actor present at the specified grid position.
    *   `pos`: The `Vector2i` coordinates to check.
    *   **Returns:** `true` if an actor occupies the tile, `false` otherwise.
*   **`get_actor_at(pos: Vector2i) -> Variant`**
    Retrieves the actor object located at the specified grid position.
    *   `pos`: The `Vector2i` coordinates to query.
    *   **Returns:** The `Object` representing the actor at `pos`, or `null` if no actor is found.
*   **`generate_world(width: int, height: int, seed: int = 0) -> Color[]`**
    Generates a new procedural world map and replaces the current `map` (`LogicGridMap`) with the result. This method leverages the `ProceduralWorld` module internally.
    *   `width`: The desired width of the new map in tiles.
    *   `height`: The desired height of the new map in tiles.
    *   `seed`: An optional integer seed for deterministic world generation. Using the same seed will produce the same map.
    *   **Returns:** An `Array` of `Color` objects representing the generated map, which can be used by visualizers (like `GridVisualLogic` or `GridRealtimeRenderer`) to display the terrain.
*   **`can_move(actor: Object, to: Vector2i) -> bool`**
    Determines if a given `actor` can legally move to the specified target tile. This method internally uses the `LogicGridMap`'s pathfinding capabilities to check reachability and considers obstacles.
    *   `actor`: The `Object` representing the actor attempting to move.
    *   `to`: The `Vector2i` coordinates of the target tile.
    *   **Returns:** `true` if the actor can reach the tile, `false` otherwise.
*   **`threatened_tiles(actor: Object) -> Vector2i[]`**
    Calculates and returns an array of `Vector2i` coordinates representing tiles that are "threatened" by the given `actor`. This could include tiles within the actor's attack range, zone of control, or any other area where the actor exerts influence.
    *   `actor`: The `Object` representing the actor whose threatened tiles are to be calculated.
    *   **Returns:** An `Array` of `Vector2i` coordinates.
*   **`run_tests() -> Dictionary`**
    Executes internal self-tests for the `GridLogic` module, returning a dictionary of test results.

### Interaction with `ProceduralWorld`

The `generate_world()` method within `GridLogic` delegates the actual map generation process to the `ProceduralWorld` module.

#### Class: `ProceduralWorld` (inherits from `Node`)

*   **Purpose:** This module (`procedural_world.gd`) is responsible for generating new game worlds based on various parameters, typically using noise algorithms to create varied terrain.
*   **Key API Role:**
    *   `generate(width: int, height: int, seed: int = 0) -> Dictionary`: This is the core method that creates the raw map data. It returns a dictionary containing the generated map information, which `GridLogic` then uses to populate its `LogicGridMap`.
*   **Why it's separate:** By separating the world generation logic, `GridLogic` remains focused on managing the active grid, while `ProceduralWorld` can be independently developed and tested for its generation algorithms.

## Usage Example

```gdscript
# Assuming GridLogic is instantiated and added to the scene tree
@onready var grid_logic: GridLogic = $Path/To/GridLogic

func _ready() -> void:
    # Generate a new 64x64 world with a specific seed
    var map_colors = grid_logic.generate_world(64, 64, 12345)
    print("Generated a new world map.")
    # You can then use map_colors to update a visual renderer, e.g.:
    # grid_visual_renderer.apply_color_map(map_colors)

    # Check if an actor exists at a specific position
    var check_pos = Vector2i(10, 15)
    if grid_logic.has_actor_at(check_pos):
        var actor_at_pos = grid_logic.get_actor_at(check_pos)
        print("Actor found at " + str(check_pos) + ": " + str(actor_at_pos.name))
    else:
        print("No actor at " + str(check_pos))

    # Assuming 'player_actor' is an instance of BaseActor
    var target_tile = Vector2i(12, 17)
    if grid_logic.can_move(player_actor, target_tile):
        print("Player can move to " + str(target_tile))
    else:
        print("Player cannot move to " + str(target_tile))

    # Get tiles threatened by the player
    var threatened = grid_logic.threatened_tiles(player_actor)
    print("Player threatens " + str(threatened.size()) + " tiles.")
    # You could then visualize these threatened tiles using GridRealtimeRenderer
    # grid_realtime_renderer.set_cells_color_bulk(threatened, Color(1, 0, 0, 0.2))
```

## Testing

To ensure the `GridLogic` module functions correctly, execute its self-tests via the shared test runner:

```bash
godot4 --headless --path . --script scripts/test_runner.gd -- --module=grid_logic
```

This command runs the tests headlessly, verifying that the module correctly wraps `LogicGridMap` operations, performs actor queries, and integrates with the procedural world generation.