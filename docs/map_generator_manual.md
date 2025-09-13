# Map Generator Manual

`map_generator.gd` defines the `MapGenerator` module, which orchestrates the creation of procedural grids and acts as a crucial bridge between the game's core logic and the [Tile to Gridmap](https://github.com/godotengine/godot-tile-to-gridmap-addon) addon. This module simplifies the complex process of generating a game world from abstract parameters.

## Responsibilities

-   **Procedural Map Generation:** Invokes the `ProceduralMapGenerator` to produce a `LogicGridMap` instance, which is a pure data representation of the game world filled with terrain tags (e.g., "grass", "water", "mountain").
-   **Visual Grid Generation:** Translates these terrain tags into `TileSet` atlas coordinates through a `T2GTerrainLayer` (part of the Tile to Gridmap addon) and generates a populated 3D `GridMap` node. This `GridMap` is the visual representation of your game world.
-   **Synchronization Bridge:** Creates a `TileToGridMapBridge` that maintains synchronization between the `LogicGridMap` (data), the `GridMap` (visuals), and the `GridRealtimeRenderer` (debug/overlay visuals) for future updates or rebuilds.
-   **Debug Visualization:** Provides a `GridRealtimeRenderer` instance, ready for debug visualization or integration into tests, allowing you to see the generated logical grid.

## Core Concepts and API Details

The `MapGenerator` streamlines the process of creating a game world by combining the power of procedural generation with Godot's 3D grid capabilities.

### Class: `MapGenerator` (inherits from `Node`)

As a `Node`, `MapGenerator` can be instantiated and used within your game scenes or headless scripts.

#### Methods

*   **`build(params: Dictionary) -> Dictionary`**
    This is the primary method for generating a game map. It takes a dictionary of parameters and returns a dictionary containing the generated map components.
    *   `params`: A `Dictionary` containing configuration for map generation. It accepts all fields used by `ProceduralMapGenerator.generate()`, plus additional parameters for visual integration:
        *   `width` (`int`): The width of the map in tiles.
        *   `height` (`int`): The height of the map in tiles.
        *   `seed` (`String` or `int`): A seed for deterministic generation.
        *   `terrain` (`String`): Selects a preset terrain profile.
        *   `tileset` (`TileSet`): **Required.** The Godot `TileSet` resource that contains the visual tiles used by the `T2GTerrainLayer` to build the `GridMap`.
        *   `terrain_atlas` (`Dictionary`): **Required.** A dictionary mapping terrain tags (from `LogicGridMap`) to `Vector2i` atlas coordinates within the `tileset`. Example: `{"grass": Vector2i(0,0), "water": Vector2i(1,0)}`.
        *   `mesh_library` (`MeshLibrary`, optional): An optional `MeshLibrary` resource to be used by the generated `GridMap`.
        *   `tile_size` (`int`, optional): The pixel size for tiles, used by `T2GTerrainLayer`.
    *   **Returns:** A `Dictionary` containing the generated components:
        *   `map` (`LogicGridMap`): The generated logical grid map.
        *   `grid_map` (`GridMap`): The generated 3D visual grid map.
        *   `renderer` (`GridRealtimeRenderer`): An instance of the debug renderer.
        *   `bridge` (`TileToGridMapBridge`): The bridge object for synchronization.
*   **`run_tests() -> Dictionary`**
    Executes a lightweight self-test for CI usage, ensuring the map generation process is functional.

### Interaction with Other Modules

The `MapGenerator` acts as an orchestrator, calling methods on several other modules:

*   **`ProceduralMapGenerator` (from `scripts/modules/procedural_map_generator.gd`)
    *   **Purpose:** This module is solely responsible for generating the raw `LogicGridMap` data based on procedural algorithms (e.g., noise-based biomes).
    *   **Key API Role:** `MapGenerator` calls `ProceduralMapGenerator.generate(params)` to get the initial `LogicGridMap`.
    *   **API Reference:** [ProceduralMapGenerator API Documentation](html/ProceduralMapGenerator.html)

*   **`T2GTerrainLayer` (from `addons/tile_to_gridmap/t2g_terrain_layer.gd`)
    *   **Purpose:** Part of the Tile to Gridmap addon. It takes the `LogicGridMap` and a `TileSet` and generates the 3D `GridMap` by mapping terrain tags to visual tiles.
    *   **Key API Role (inferred):** `MapGenerator` uses this layer to `build_gridmap()` based on the `LogicGridMap` and `terrain_atlas`.

*   **`TileToGridMapBridge` (from `addons/tile_to_gridmap/tile_to_gridmap_bridge.gd`)
    *   **Purpose:** This module maintains the connection and synchronization between the logical `LogicGridMap` and the visual `GridMap` and `GridRealtimeRenderer`. It allows for dynamic updates to the visual grid when the logical grid changes.
    *   **Key API Role (inferred):** `MapGenerator` instantiates this bridge and sets its `logic` (to the `LogicGridMap`) and `terrain_layer_path` properties. The `bridge.build_from_tilemap()` method can be called to rebuild the visual grid if the underlying `LogicGridMap` or `TileMap` (if used) changes.

*   **`GridRealtimeRenderer` (from `scripts/modules/GridRealtimeRenderer.gd`)
    *   **Purpose:** A high-performance visual overlay renderer. `MapGenerator` provides an instance of this for immediate debug visualization of the generated `LogicGridMap`.
    *   **Key API Role:** The returned `renderer` instance can be used to display the `LogicGridMap`'s contents (e.g., terrain types, actor positions) using its `set_cell_color()`, `apply_color_map()`, or ASCII output features.
    *   **API Reference:** [GridRealtimeRenderer API Documentation](html/GridRealtimeRenderer.html)

## Usage Example

```gdscript
var gen := MapGenerator.new()
# Preload your TileSet resource
var tileset := preload("res://tilesets/terrain.tres") # Adjust path to your TileSet

# Define your terrain atlas: mapping terrain tags (from LogicGridMap) to TileSet atlas coordinates
var atlas := {
    "grass": Vector2i(0,0),
    "water": Vector2i(1,0),
    "mountain": Vector2i(2,0)
}

# Build the map
var result := gen.build({
    "width": 32,
    "height": 32,
    "seed": "demo_world", # Use a string seed for deterministic generation
    "terrain": "plains", # A preset terrain profile for ProceduralMapGenerator
    "tileset": tileset,
    "terrain_atlas": atlas,
    "tile_size": 32 # Assuming 32x32 pixel tiles
})

# Extract the generated components from the result dictionary
var map : LogicGridMap = result.map # The logical grid data
var grid_map : GridMap = result.grid_map # The 3D visual grid node
var renderer : GridRealtimeRenderer = result.renderer # The debug renderer
var bridge : TileToGridMapBridge = result.bridge # The synchronization bridge

# Add the visual components to your scene tree
add_child(grid_map)
add_child(renderer)

# Example: If you make changes to the underlying LogicGridMap or TileMap,
# you can call bridge.build_from_tilemap() to rebuild the visual GridMap.
# bridge.build_from_tilemap() # Rebuilds the visual GridMap if TileMap edits occur
```

The returned objects (`map`, `grid_map`, `renderer`, `bridge`) can be added to a scene for display or used headlessly for tests and data processing.

## Testing

To ensure the `MapGenerator` and its integrated components function correctly, run all module tests with the shared runner:

```bash
godot4 --headless --path . --script scripts/test_runner.gd
```

This command executes the tests headlessly, verifying that the map generation process, including the bridging to the visual `GridMap` and `GridRealtimeRenderer`, works as expected.