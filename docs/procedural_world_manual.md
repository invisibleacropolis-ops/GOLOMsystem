# Procedural World Module Manual

`procedural_world.gd` builds `LogicGridMap` instances by sampling the
`FastNoiseLiteDatasource` scripts from the `Inspiration` folder.  It returns
both the generated map and a color array suitable for `GridRealtimeRenderer`.

## Core Concepts and API Details

The `ProceduralWorld` module focuses on creating the raw, logical data for a game world. It leverages noise functions to define terrain types, elevation, and other geographical features, which are then represented within a `LogicGridMap`.

### Class: `ProceduralWorld` (inherits from `Node`)

As a `Node`, `ProceduralWorld` can be instantiated and used within your game scenes or headless scripts.

#### Methods

*   **`generate(width: int, height: int, seed: int = 0) -> Dictionary`**
    This is the core method for generating a new procedural world. It creates a `LogicGridMap` based on the specified dimensions and seed, populating it with terrain data derived from noise.
    *   `width`: The desired width of the generated map in tiles.
    *   `height`: The desired height of the generated map in tiles.
    *   `seed`: An optional integer seed. Using the same seed with the same `width` and `height` will always produce an identical map, ensuring deterministic generation.
    *   **Returns:** A `Dictionary` containing:
        *   `map` (`LogicGridMap`): The generated logical grid map, populated with terrain tags and other data.
        *   `colors` (`Array[Color]`): An array of `Color` objects, where each color corresponds to a tile on the map, representing its biome or terrain type. This array is specifically designed for direct visualization by renderers like `GridRealtimeRenderer`.
*   **`run_tests() -> Dictionary`**
    Executes internal self-tests for the `ProceduralWorld` module, returning a dictionary of test results.

## Usage

To generate a procedural world, you instantiate `ProceduralWorld` and call its `generate()` method with the desired dimensions and an optional seed.

```gdscript
var pw := ProceduralWorld.new()

# Generate a 64x64 map with a seed of 42
var result := pw.generate(64, 64, 42)

# Extract the generated LogicGridMap and color array
var map : LogicGridMap = result.map
var colors : Array = result.colors

print("Generated a procedural world map with dimensions: " + str(map.width) + "x" + str(map.height))

# You can then feed the 'colors' array into GridRealtimeRenderer.apply_color_map()
# to visualize the biome map.
var visual_renderer := GridRealtimeRenderer.new()
add_child(visual_renderer) # Add the renderer to your scene tree
visual_renderer.set_grid_size(map.width, map.height) # Set renderer dimensions
visual_renderer.apply_color_map(colors) # Apply the generated colors
```

## Integration Notes

-   **Logical Data First:** `ProceduralWorld` focuses on generating the *logical* `LogicGridMap` data. It does not handle the 3D visual representation (meshes, textures). This separation allows for flexible visual layers to be built on top of the generated data.
-   **Deterministic Generation:** The `seed` parameter is crucial for creating repeatable worlds. This is invaluable for debugging, testing, and ensuring fair play in competitive scenarios.
-   **Visualization:** The `colors` array returned by `generate()` is specifically designed to be consumed by `GridRealtimeRenderer.apply_color_map()`. This provides an immediate visual representation of the generated terrain without complex setup.
-   **Custom Noise Sources:** The module is designed to sample `FastNoiseLiteDatasource` scripts. This implies that you can customize the noise generation by providing different `FastNoiseLite` configurations, allowing for a wide variety of world types.

## Testing

To ensure the `ProceduralWorld` module functions correctly, invoke its self-test via the shared test runner:

```bash
godot4 --headless --path . --script scripts/test_runner.gd -- --module=procedural_world
```

This command runs the tests headlessly, verifying that the module correctly generates maps and returns the expected data structures.