# GridVisualLogic Module Manual

`GridVisualLogic` is a `Node2D` that renders a rectangular grid using Godot's immediate drawing API (`_draw()` method). It serves as the visual companion to `LogicGridMap` by painting each tile according to a supplied state. This module is primarily intended for debugging, visualizing game state, or powering a minimal, lightweight UI.

## Features

-   Configurable grid dimensions (`grid_size`) and individual `cell_size`.
-   Optional connection to a `LogicGridMap` resource to automatically adopt its width and height, ensuring visual and logical grids are synchronized.
-   Per-cell state dictionary (`cell_states`) accepting either:
    -   A `Color` to fill the tile, allowing for simple color-coding of grid cells.
    -   A `Callable` that receives `(self, Rect2)` to perform custom drawing operations (e.g., drawing circles, lines, or textures) within the cell's bounds.
-   Lightweight `run_tests()` helper verifying basic state management.
-   Batch `update_cells(states)` helper for efficiently applying many tile changes at once.

## Core Concepts and API Details

The `GridVisualLogic` module provides a flexible way to visually represent the underlying game grid. It's important to remember that this module is purely for visualization; it does not manage game state or logic itself.

### Class: `GridVisualLogic` (inherits from `Node2D`)

As a `Node2D`, `GridVisualLogic` can be added to your scene tree and positioned like any other 2D node. Its drawing operations occur within its local coordinate space.

#### Members

*   **`cell_size`** (`int`, Default: `32`): The pixel dimensions (width and height) of each individual grid cell.
*   **`grid_size`** (`Vector2i`, Default: `Vector2i(8, 8)`): A `Vector2i` representing the number of tiles in the X and Y dimensions of the grid. This is automatically updated when a `LogicGridMap` is assigned.
*   **`grid_map`** (`LogicGridMap`, Default: `null`): A reference to an instance of `LogicGridMap`. When set, `GridVisualLogic` will automatically adjust its `grid_size` to match the dimensions of the `LogicGridMap`.
*   **`cell_states`** (`Dictionary`, Default: `{}`): This dictionary stores the custom state for each cell. Keys are `Vector2i` positions, and values are either `Color` objects or `Callable` functions.
*   **`event_log`** (`Array`, Default: `[]`): An internal log for recording events related to visual logic, useful for debugging.

#### Methods

*   **`set_grid_map(map: LogicGridMap) -> void`**
    Assigns a `LogicGridMap` instance to the visualizer. When a map is assigned, `GridVisualLogic` automatically adopts its dimensions (`width` and `height`) for its own `grid_size`. This ensures that the visual representation matches the logical grid.
    *   `map`: The `LogicGridMap` instance to associate with this visualizer.
*   **`set_grid_size(width: int, height: int) -> void`**
    Manually specifies the width and height of the grid in tiles. This method can be used if you don't have a `LogicGridMap` or want to override its dimensions.
    *   `width`: The desired width of the grid in tiles.
    *   `height`: The desired height of the grid in tiles.
*   **`set_cell_state(pos: Vector2i, state: Variant) -> void`**
    Assigns a `state` to a specific grid cell at `pos`. The `state` can be either:
    *   A `Color`: The cell will be filled with this color.
    *   A `Callable`: This function will be called during the `_draw()` process for this cell, receiving `(self, Rect2)` as arguments. `self` refers to the `GridVisualLogic` instance, and `Rect2` is the bounding rectangle of the cell in local coordinates. This allows for highly customized drawing.
    *   `pos`: The `Vector2i` coordinates of the cell to update.
    *   `state`: The `Color` or `Callable` to apply to the cell.
*   **`clear_cell_state(pos: Vector2i) -> void`**
    Removes any custom state (color or callable) for the specified cell, making it transparent.
    *   `pos`: The `Vector2i` coordinates of the cell to clear.
*   **`update_cells(states: Dictionary, clear_existing: bool = true) -> void`**
    Replaces the entire `cell_states` dictionary with the provided `states` dictionary and redraws the grid. This is an efficient way to update many tiles at once.
    *   `states`: A `Dictionary` where keys are `Vector2i` positions and values are `Color` or `Callable` states.
    *   `clear_existing`: If `true` (default), all existing cell states are cleared before applying the new ones. If `false`, new states are merged with existing ones.
*   **`log_event(t: String, actor: Object = null, pos: Variant = null, data: Variant = null) -> void`**
    Appends a structured event to the module's internal `event_log`. Useful for debugging the visualizer's behavior.
*   **`_draw() -> void`**
    This is Godot's built-in callback method for custom drawing. `GridVisualLogic` overrides this to render the grid based on its `cell_states`. You typically don't call this directly; instead, you call `queue_redraw()` to trigger a redraw.
*   **`run_tests() -> Dictionary`**
    Executes a minimal self-test ensuring basic state management and drawing capabilities work as expected.

## Usage

```gdscript
# Assuming LogicGridMap is available (e.g., from a RuntimeServices instance)
var map := LogicGridMap.new()
map.width = 4
map.height = 3

var vis := GridVisualLogic.new()
add_child(vis) # Add the visualizer to the scene tree

# Option 1: Connect to a LogicGridMap
vis.set_grid_map(map)

# Option 2: Manually set grid size if no LogicGridMap
# vis.set_grid_size(4, 3)

# Set a cell to a solid color (e.g., highlight a selected tile)
vis.set_cell_state(Vector2i(1, 1), Color.RED)

# Example of custom drawing using a Callable: Draw a yellow circle in a cell
vis.set_cell_state(Vector2i(0, 0), func(self_ref, rect_bounds):
    # self_ref refers to the GridVisualLogic instance
    # rect_bounds is the Rect2 for the current cell
    self_ref.draw_circle(rect_bounds.position + rect_bounds.size / 2, rect_bounds.size.x / 2, Color.YELLOW)
)

# To make changes visible, you must call queue_redraw()
vis.queue_redraw()

# Example of batch updating cells
var new_states = {
    Vector2i(2, 0): Color.BLUE,
    Vector2i(2, 1): Color.GREEN,
    Vector2i(2, 2): Color.PURPLE
}
vis.update_cells(new_states) # This will clear previous states and apply new ones
```

## Integration Notes

-   **Pure Visualization:** Use this node strictly for visualization or debugging. It does not own game state or logic. All game logic should reside in other modules (like `LogicGridMap`, `TurnBasedGridTimespace`, etc.).
-   **Triggering Redraws:** After modifying cell states (e.g., with `set_cell_state()` or `update_cells()`), you **must** call `queue_redraw()` on the `GridVisualLogic` instance to force the visualizer to update its display. Godot's immediate drawing API only redraws when explicitly requested or when the node's `_draw()` method is triggered by the engine.
-   **Resource Management in Tests:** When using `GridVisualLogic` in unit tests, especially those that instantiate it in code, remember to free instances that inherit from `CanvasItem` (like `Node2D`) once you are done with them to avoid memory leaks.

## Testing

The module can be tested headlessly via the shared test runner:

```bash
godot4 --headless --path . --script scripts/test_runner.gd -- --module=grid_visual_logic
```

The test verifies cell size assignment, color storage, and callable handling, ensuring the visualizer behaves correctly even without a graphical interface.