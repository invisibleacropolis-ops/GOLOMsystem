# LogicGridMap Manual

`grid/grid_map.gd` defines the `LogicGridMap` class, a pure data `Resource` describing the tactical board. It supports spatial queries, pathfinding, terrain tags, and area calculations without relying on visual nodes. This separation of concerns allows for headless operation (e.g., for server-side logic or automated testing) and flexible visual representations.

## Responsibilities

-   Track actor positions and occupancy on the grid.
-   Provide methods for movement validation and execution through `move_actor()` and `remove_actor()`.
-   Compute distances, line of sight (LOS), and pathfinding routes.
-   Calculate various area-of-effect (AoE) shapes.
-   Manage zones of control and flanking detection.
-   Store per-tile metadata such as movement costs, height levels, terrain tags, and cover information.
-   Support optional directional obstacles and diagonal movement rules for richer tactical constraints.

## Core Concepts and API Details

The `LogicGridMap` is the authoritative source for all spatial information in the game. It's designed to be a robust and efficient data structure for tactical gameplay.

### Class: `LogicGridMap` (inherits from `Resource`)

As a `Resource`, `LogicGridMap` can be saved and loaded independently of scenes, making it highly reusable and persistent.

#### Members

*   **`map`** (`Grid`, Default: `new()`): This is the internal representation of the grid itself, likely a 2D array or similar structure that stores tile data.
*   **`event_log`** (`Array`, Default: `[]`): An internal log for recording events related to grid operations, useful for debugging.

#### Methods

### Actor Placement

*   **`has_actor_at(pos: Vector2i) -> bool`**
    Checks if there is any actor present at the specified grid position.
    *   `pos`: The `Vector2i` coordinates to check.
    *   **Returns:** `true` if an actor occupies the tile, `false` otherwise.
*   **`get_actor_at(pos: Vector2i) -> Variant`**
    Retrieves the actor object located at the specified grid position.
    *   `pos`: The `Vector2i` coordinates to query.
    *   **Returns:** The `Object` representing the actor at `pos`, or `null` if no actor is found.
*   **`move_actor(actor: Object, from_pos: Vector2i, to_pos: Vector2i) -> bool`**
    Handles the movement of an `actor` from `from_pos` to `to_pos`. This method validates multi-tile footprints and updates the internal `occupied` and `actor_positions` dictionaries.
    *   `actor`: The actor object to move.
    *   `from_pos`: The actor's current position.
    *   `to_pos`: The target position.
    *   **Returns:** `true` if the move was successful, `false` otherwise.
*   **`remove_actor(actor: Object) -> void`**
    Clears an actor's entries from the map, effectively removing it from the grid's tracking.
    *   `actor`: The actor object to remove.
*   **`get_occupied_tiles(actor: Object) -> Array[Vector2i]`**
    Returns an array of all `Vector2i` tiles that a given `actor` currently occupies, considering its size and footprint.

### Spatial Queries

*   **`is_in_bounds(pos: Vector2i) -> bool`**
    Checks if a given `Vector2i` position is within the defined boundaries of the grid map.
*   **`is_occupied(pos: Vector2i) -> bool`**
    Checks if a specific tile at `pos` is currently occupied by any actor.
*   **Distance Helpers:**
    *   `get_distance(from: Vector2i, to: Vector2i) -> int`: Calculates the Manhattan distance (taxicab geometry) between two points.
    *   `get_chebyshev_distance(from: Vector2i, to: Vector2i) -> int`: Calculates the Chebyshev distance (chessboard distance) between two points, useful for square-radius checks.
*   **`has_line_of_sight(a: Vector2i, b: Vector2i) -> bool`**
    Determines if there is an unobstructed line of sight between two points `a` and `b` on the grid. This method typically uses Bresenham's algorithm and considers any defined LOS blockers or cover elements on the map.

### Range Queries

*   **`get_actors_in_radius(center: Vector2i, radius: int) -> Array[Object]`**
    Returns an array of actor objects located within a specified `radius` around a `center` point, often using Chebyshev distance.
*   **`get_positions_in_range(center: Vector2i, radius: int) -> Array[Vector2i]`**
    Returns an array of `Vector2i` positions that are within a specified `radius` around a `center` point.

### Pathfinding

*   **`find_path(start: Vector2i, facing: Vector2i, goal: Vector2i, size: Vector2i) -> Array[Vector2i]`**
    Implements the A* pathfinding algorithm to find the shortest path between a `start` and `goal` position. It considers movement costs, turning penalties (`TURN_COST` constant), climb restrictions, and supports multi-tile actors.
*   **`find_path_for_actor(actor: Object, start: Vector2i, goal: Vector2i) -> Array[Vector2i]`**
    A convenience wrapper around `find_path` that automatically uses the `actor`'s size and facing for path calculation.
*   **`set_diagonal_movement(enable: bool) -> void`**
    Toggles whether diagonal movements are considered valid during pathfinding and other spatial calculations.
*   **`place_obstacle(pos: Vector2i, orientation: int) -> void`**
    Inserts directional obstacles (e.g., walls) at a given position that block movement in a specific `orientation`.

### Area of Effect (AoE)

*   **`get_aoe_tiles(shape: String, origin: Vector2i, direction: Vector2i, range: int) -> Array[Vector2i]`**
    Dispatches to internal helpers to calculate and return an array of `Vector2i` tiles covered by various AoE shapes, such as `burst`, `cone`, `line`, and `wall`.

### Tactical Logic

*   **`get_zone_of_control(actor: Object, radius: int, arc: float) -> Array[Vector2i]`**
    Calculates and returns an array of "threatened tiles" around an `actor`, representing its zone of control or influence.
*   **`get_cover(pos: Vector2i) -> Dictionary`**
    Retrieves cover information for a specific tile.
*   **`set_cover(pos: Vector2i, type: int, direction: Vector2i, height: int) -> void`**
    Sets directional cover information for a tile, including type, direction, and optional height.
*   **Utility Functions:** Provides internal utility functions to determine flanking status, retrieve tile tags, query height levels, and calculate per-tile movement costs.

## Integration Notes

-   **Resource-Based:** Because `LogicGridMap` is a `Resource`, it can be saved and loaded independently of scenes. This makes it ideal for persistent world data or for generating maps dynamically and then saving them.
-   **Pairing with Visuals:** `LogicGridMap` is purely data. To visualize the grid and its contents, you will typically pair it with a rendering module like `GridVisualLogic` (for simple debugging) or `GridRealtimeRenderer` (for high-performance visual overlays).
-   **Gameplay System Integration:** It forms the backbone for gameplay systems such as `TurnBasedGridTimespace` (for movement validation and actor placement) and `GridInteractor` (for translating user input into grid selections).
-   **Debugging with `event_log`:** Use the internal `event_log` array to record operations when debugging complex movement or spatial query bugs.

## Testing

While `LogicGridMap` currently lacks a dedicated `run_tests()` method, it is exercised extensively by the tests for `turn_timespace.gd` and other modules that rely on its spatial capabilities. When adding new features or modifying existing ones, it is highly recommended to implement a `run_tests()` method similar to other modules to ensure deterministic behavior and prevent regressions.