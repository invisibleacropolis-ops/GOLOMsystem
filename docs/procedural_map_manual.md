# Procedural Map Generator Manual

`procedural_map_generator.gd` defines the `ProceduralMapGenerator` module, which is responsible for building `LogicGridMap` instances from simple noise algorithms and string-based presets. This module allows engineers to quickly produce deterministic grid layouts for prototyping, testing, or even full game levels without the need for manual tile authoring.

## Responsibilities

-   Create headless `LogicGridMap` instances suitable for tests or tools.
-   Support repeatable map layouts through the use of a string `seed`.
-   Offer coarse terrain profiles (e.g., `plains`, `islands`, `mountains`) to generate varied geographical features.
-   Generate `LogicGridMap`s with terrain tags (e.g., "grass", "water") based on layered noise.
-   Optionally carve basic road networks to ensure connectivity.

## Core Concepts and API Details

The `ProceduralMapGenerator` is a powerful tool for quickly generating game worlds. It focuses solely on creating the logical grid data, leaving the visual representation to other modules like `MapGenerator` or `GridRealtimeRenderer`.

### Class: `ProceduralMapGenerator` (inherits from `Node`)

As a `Node`, `ProceduralMapGenerator` can be instantiated and used within your game scenes or headless scripts.

#### Methods

*   **`generate(params: Dictionary) -> LogicGridMap`**
    This is the core method for generating a new `LogicGridMap`. It uses layered noise to create height, terrain, and connected road features.
    *   `params`: A `Dictionary` containing the generation parameters. Key fields include:
        *   `width` (`int`): The desired width of the map in tiles.
        *   `height` (`int`): The desired height of the map in tiles.
        *   `seed` (`String` or `int`): A seed used for deterministic output. Using the same seed will always produce the same map.
        *   `terrain` (`String`): Selects a preset terrain profile (e.g., "plains", "islands"). This influences the noise patterns used.
    *   **Returns:** A fully generated `LogicGridMap` instance. The first tag on each tile typically controls rendering, while subsequent tags describe underlying terrain (e.g., `"grass"`, `"dirt"`).
*   **`_carve_roads(map: LogicGridMap) -> void`**
    An internal helper method that carves a simple cross-shaped road network into the provided `LogicGridMap` to ensure paths remain connected. This is typically called by `generate()`.
*   **`run_tests() -> Dictionary`**
    Executes a lightweight self-test for CI usage, ensuring the map generation process is functional.

## Usage

To generate a map, you instantiate `ProceduralMapGenerator`, define your parameters in a dictionary, and call the `generate()` method.

```gdscript
var gen := ProceduralMapGenerator.new()

var params = {
    "width": 32,
    "height": 32,
    "seed": "my_awesome_world_seed", # Use a unique string for a unique map
    "terrain": "islands" # Choose a terrain profile
}

var map := gen.generate(params) # 'map' is now a LogicGridMap instance
print("Generated a map with dimensions: " + str(map.width) + "x" + str(map.height))

# The returned LogicGridMap contains width, height, and per-tile tags
# based on the chosen profile. You can access tile data like this:
# var tile_data = map.get_tile_data(Vector2i(0,0))
# print("Tile at (0,0) has tags: " + str(tile_data.tags))

# You can then pass this LogicGridMap to other modules for visualization or gameplay logic.
# For example, to visualize it:
# var visual_renderer = GridRealtimeRenderer.new()
# visual_renderer.set_grid_size(map.width, map.height)
# visual_renderer.apply_color_map(map.get_terrain_colors()) # Assuming LogicGridMap has a method to get colors
# add_child(visual_renderer)
```

The returned `LogicGridMap` contains width, height, and per-tile tags based on the chosen profile. Additional map post-processing can run on the resulting resource as needed.

## Integration Notes

-   **Headless Generation:** This module is designed to work headlessly, meaning it doesn't require a graphical interface. This makes it perfect for generating maps in automated tests, server-side processes, or build pipelines.
-   **Separation of Concerns:** `ProceduralMapGenerator` focuses solely on the *logical* generation of the grid data (`LogicGridMap`). It does not handle the *visual* representation (3D models, textures). This separation allows for flexible visual layers to be built on top of the generated data.
-   **Deterministic Output:** The `seed` parameter is crucial for deterministic generation. Using the same seed with the same parameters will always produce an identical map. This is invaluable for debugging, testing, and competitive play where fair, repeatable maps are required.
-   **Integration with `MapGenerator`:** While you can use `ProceduralMapGenerator` directly, the `MapGenerator` module provides a higher-level orchestration, combining procedural map generation with the `Tile to Gridmap` addon to produce a fully visual 3D `GridMap`.

## Testing

To ensure the `ProceduralMapGenerator` functions correctly, execute its self-tests via the shared test runner:

```bash
godot4 --headless --path . --script scripts/test_runner.gd -- --module=procedural_map_generator
```

This command runs the tests headlessly, verifying that the module correctly generates maps with the specified parameters and terrain profiles.