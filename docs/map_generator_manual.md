# Map Generator Manual

`map_generator.gd` orchestrates procedural grid creation and bridges the
[Tile to Gridmap](../addons/tile_to_gridmap/README.md) addon with the
runtime modules in this project.

## Responsibilities

- Invoke `ProceduralMapGenerator` to produce a `LogicGridMap` filled with
  terrain tags.
- Translate tags into `TileSet` atlas coordinates through a `T2GTerrainLayer`
  and emit a populated 3D `GridMap`.
- Create a `TileToGridMapBridge` that holds the terrain layer and synchronises
  the `LogicGridMap`, `GridMap`, and renderer for future rebuilds.
- Provide a `GridRealtimeRenderer` instance for debug visualization or tests.

## Parameters

`build()` accepts the standard procedural generator fields plus:

- `tileset` (`TileSet`): Tiles used by the `T2GTerrainLayer`.
- `terrain_atlas` (`Dictionary`): Maps terrain tags to atlas coordinates.
- `mesh_library` (`MeshLibrary`, optional): Meshes for the `GridMap`.
- `tile_size` (`int`, optional): Pixel size for tiles.

## Usage Example

```gdscript
var gen := MapGenerator.new()
var tileset := preload("res://path/to/tileset.tres")
var atlas := {"grass": Vector2i(0,0)}
var result := gen.build({
    "width": 32,
    "height": 32,
    "seed": "demo",
    "terrain": "plains",
    "tileset": tileset,
    "terrain_atlas": atlas,
})
var map : LogicGridMap = result.map
var grid_map : GridMap = result.grid_map
var renderer : GridRealtimeRenderer = result.renderer
var bridge : TileToGridMapBridge = result.bridge
bridge.build_from_tilemap() # rebuild if TileMap edits occur
```

The returned objects can be added to a scene or used headlessly for tests.

## Testing

Run all module tests with the shared runner:

```bash
godot4 --headless --path . --script scripts/test_runner.gd
```
