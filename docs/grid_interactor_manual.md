# Grid Interactor Manual

`grid_interactor.gd` is a crucial component that translates raw mouse input into meaningful grid interactions, such as selecting tiles or actors. It acts as a bridge between the user's mouse movements and the game's grid-based logic and visual feedback systems.

## Core Concepts and API Details

The `GridInteractor` works by observing mouse events and, based on its internal state and configuration, emitting signals that other parts of your game can listen to. It relies on two key external modules: a `GridRealtimeRenderer` for visual feedback (like highlighting selected areas) and a `LogicGridMap` (or a similar logic node) to query information about the grid and its occupants.

### Class: `GridInteractor` (inherits from `Node2D`)

As a `Node2D`, the `GridInteractor` can be placed in your scene tree and will process input events within its defined area.

#### Key Properties (to be set in the editor or code)

*   **`grid_renderer_path`**: A `NodePath` pointing to an instance of `GridRealtimeRenderer` in your scene. This renderer is used by the interactor to draw visual cues like selection boxes or drag paths.
*   **`grid_logic_path`**: A `NodePath` pointing to an instance of your grid logic (e.g., `LogicGridMap` or a node that wraps it). The interactor queries this node to understand the grid's dimensions and what occupies its cells.

#### Signals

The `GridInteractor` emits the following signals, which you can connect to in your game logic to react to user input:

*   **`tile_clicked(tile: Vector2i, button: int, mods: int)`**
    Emitted when a single grid tile is clicked.
    *   `tile`: The `Vector2i` coordinates of the clicked tile.
    *   `button`: The mouse button that was pressed (e.g., `MOUSE_BUTTON_LEFT`).
    *   `mods`: A bitmask representing modifier keys held down (e.g., `KEY_MASK_SHIFT`, `KEY_MASK_CTRL`).
*   **`tiles_selected(tiles: Array[Vector2i])`**
    Emitted after a drag-selection operation is completed, providing a list of all tiles within the selected rectangle.
    *   `tiles`: An `Array` of `Vector2i` coordinates representing the selected tiles.
*   **`actor_clicked(actor: Object)`**
    Emitted when an actor on the grid is clicked. The `GridInteractor` determines if an actor is present at the clicked location by querying its `grid_logic_path`.
    *   `actor`: The `Object` representing the clicked actor.
*   **`actors_selected(actors: Array[Object])`**
    Emitted after a drag-selection operation that encompasses multiple actors, providing a list of all actors within the selected area.
    *   `actors`: An `Array` of `Object`s representing the selected actors.

#### Internal Logic & Features

*   **Drag-Selection Previews:** The interactor uses the `GridRealtimeRenderer` to draw a dynamic rectangle as the user drags the mouse, providing visual feedback for area selection.
*   **Modifier Bitmasks:** It interprets modifier keys (Shift, Ctrl) to allow for advanced selection behaviors (e.g., adding to a selection, toggling selection state).
*   **Stateful Drag Handling:** The interactor intelligently differentiates between a simple click and the start/end of a drag operation, ensuring appropriate signals are emitted.

### External Module Interactions

The `GridInteractor` relies heavily on other modules to function:

*   **`GridRealtimeRenderer` (from `scripts/modules/GridRealtimeRenderer.gd`)
    *   **Purpose:** This high-performance renderer is used by `GridInteractor` to draw visual overlays on the grid.
    *   **Key Methods Used by Interactor:**
        *   `set_cell_color(p: Vector2i, color: Color)`: To highlight individual cells.
        *   `set_mark(p: Vector2i, mark_type: int, color: Color, size01: float, rotation_rad: float, thickness01: float)`: To place markers (e.g., a cross on a target).
        *   `set_stroke(p: Vector2i, color: Color, thickness01: float, corner01: float)`: To draw outlines around cells.
        *   `clear_all()`: To clear all visual overlays.
        *   `stroke_outline_for(tiles: PackedVector2Array, color: Color, thickness01: float, corner01: float)`: Used for drawing the drag-selection rectangle.
    *   **API Reference:** [GridRealtimeRenderer API Documentation](html/GridRealtimeRenderer.html)

*   **`LogicGridMap` (from `scripts/grid/grid_map.gd`)
    *   **Purpose:** Provides the underlying grid data and information about what occupies each cell.
    *   **Key Methods Used by Interactor:**
        *   `get_actor_at(pos: Vector2i) -> Variant`: To determine if an actor is present at a clicked or selected tile.
        *   `is_in_bounds(pos: Vector2i) -> bool`: To ensure interactions are within the valid grid area.
    *   **API Reference:** [LogicGridMap API Documentation](html/GridLogic.html)

## Usage Example

To use the `GridInteractor`, you typically instantiate it, set its `grid_renderer_path` and `grid_logic_path` properties, and connect to its signals.

```gdscript
# Preload the necessary scripts/scenes
const GridInteractor = preload("res://scripts/grid/grid_interactor.gd")
const GridRealtimeRenderer = preload("res://scripts/modules/GridRealtimeRenderer.gd")
const LogicGridMapScene = preload("res://scenes/modules/GridLogic.tscn") # Assuming LogicGridMap is part of a scene

@onready var renderer: GridRealtimeRenderer
@onready var logic_grid_map: LogicGridMap # Or whatever node wraps your LogicGridMap

func _ready() -> void:
    # Instantiate and add the renderer and logic_grid_map to the scene tree if they are not already there
    # For this example, let's assume they are already set up or instantiated elsewhere
    # and we just need to get their references.
    # If they are in the scene, you might use @onready var renderer = $Path/To/GridRealtimeRenderer

    # Example: If you instantiate them in code:
    renderer = GridRealtimeRenderer.new()
    add_child(renderer) # Add to the scene tree

    # Assuming LogicGridMap is part of a scene, instantiate it
    logic_grid_map = LogicGridMapScene.instantiate()
    add_child(logic_grid_map) # Add to the scene tree

    var interactor: GridInteractor = GridInteractor.new()
    add_child(interactor) # Add the interactor to the scene tree

    # Set the paths to the renderer and logic_grid_map
    interactor.grid_renderer_path = renderer.get_path()
    interactor.grid_logic_path = logic_grid_map.get_path()

    # Connect to the interactor's signals
    interactor.tile_clicked.connect(_on_tile_clicked)
    interactor.tiles_selected.connect(_on_tiles_selected)
    interactor.actor_clicked.connect(_on_actor_clicked)
    interactor.actors_selected.connect(_on_actors_selected)

func _on_tile_clicked(tile: Vector2i, button: int, mods: int) -> void:
    print("Tile clicked: " + str(tile) + ", Button: " + str(button) + ", Mods: " + str(mods))
    # Clear previous highlights
    renderer.clear_all()
    # Highlight the clicked tile in yellow
    renderer.set_cell_color(tile, Color(1, 1, 0, 0.5)) # Yellow with 50% alpha

func _on_tiles_selected(tiles: Array[Vector2i]) -> void:
    print("Tiles selected: " + str(tiles.size()) + " tiles")
    renderer.clear_all()
    for tile in tiles:
        renderer.set_cell_color(tile, Color(0, 0.5, 1, 0.3)) # Blue with 30% alpha

func _on_actor_clicked(actor: Object) -> void:
    print("Actor clicked: " + str(actor.name))
    renderer.clear_all()
    # Assuming actor has a grid_pos property
    if actor.has_method("get_grid_pos"): # Or check if it's a BaseActor
        renderer.set_mark(actor.get_grid_pos(), 2, Color(1, 0, 0, 0.8)) # Red Cross mark

func _on_actors_selected(actors: Array[Object]) -> void:
    print("Actors selected: " + str(actors.size()) + " actors")
    renderer.clear_all()
    for actor in actors:
        if actor.has_method("get_grid_pos"): # Or check if it's a BaseActor
            renderer.set_stroke(actor.get_grid_pos(), Color(0, 1, 0, 0.7)) # Green stroke
```

For a more comprehensive example, including selection rectangles and actor highlighting, refer to `scripts/examples/grid_interactor_demo.gd`.

## Testing

To ensure the `GridInteractor` and its dependencies are functioning correctly, execute the module self-tests:

```bash
godot4 --headless --path . --script scripts/test_runner.gd -- --module=grid_interactor
```

This command runs the tests headlessly, ensuring deterministic behavior across different platforms and verifying that the interactor correctly processes input and interacts with the renderer and logic nodes.