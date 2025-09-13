extends Node
class_name MapGenerator

const ProceduralMapGenerator = preload("res://scripts/modules/procedural_map_generator.gd")
const GridRealtimeRenderer = preload("res://scripts/modules/GridRealtimeRenderer.gd")
const T2GTerrainLayer = preload("res://addons/tile_to_gridmap/t2g_terrain_layer.gd")
const TileToGridMapBridge = preload("res://scripts/integration/tile_to_gridmap_bridge.gd")

##
## High level map generator tying procedural map data to the Tile to Gridmap addon.
##
## The builder produces four pieces:
## 1. `LogicGridMap` describing terrain tags.
## 2. A `GridMap` populated via `T2GTerrainLayer.build_gridmap()`.
## 3. A `GridRealtimeRenderer` ready for debug visualization.
## 4. A `TileToGridMapBridge` holding the terrain layer for rebuilds.
##
## Params accepts the same fields as `ProceduralMapGenerator.generate()` plus:
## - `tileset` (TileSet): tiles used by the T2GTerrainLayer.
## - `terrain_atlas` (Dictionary): maps terrain tags to atlas coordinates.
## - `mesh_library` (MeshLibrary): optional mesh library for the GridMap.
## - `tile_size` (int): size in pixels for T2GTerrainLayer tiles.
func build(params: Dictionary) -> Dictionary:
    assert(params.has("tileset"), "MapGenerator requires a TileSet")
    assert(params.has("terrain_atlas"), "MapGenerator requires a terrain_atlas mapping")

    var pgen := ProceduralMapGenerator.new()
    var logic_map = pgen.generate(params)
    pgen.free()

    var renderer := GridRealtimeRenderer.new()
    renderer.set_grid_size(logic_map.width, logic_map.height)

    var bridge := TileToGridMapBridge.new()
    bridge.logic_map = logic_map
    bridge.renderer = renderer

    var grid_map := GridMap.new()
    grid_map.mesh_library = params.get("mesh_library", MeshLibrary.new())
    bridge.grid_map = grid_map

    var layer := T2GTerrainLayer.new()
    layer.name = "Terrain"
    layer.chunk_size = logic_map.width
    layer.tile_size = int(params.get("tile_size", 32))
    layer.tile_set = params.get("tileset")
    layer.grid_map = grid_map  # Needed for mesh library lookup during build.
    layer.grid_height = params.get("grid_height", 0)
    bridge.add_child(layer)
    bridge.terrain_layer = NodePath("Terrain")

    var atlas: Dictionary = params.get("terrain_atlas", {})
    for pos in logic_map.tile_tags.keys():
        var tag: String = logic_map.tile_tags[pos][0]
        if atlas.has(tag):
            # Godot 4: set_cell(layer, coords, source_id, atlas_coords)
            layer.set_cell(0, pos, 0, atlas[tag])

    bridge.build_from_tilemap()

    return {
        "map": logic_map,
        "grid_map": grid_map,
        "renderer": renderer,
        "bridge": bridge,
    }

## Lightweight self-test for CI usage.
func run_tests() -> Dictionary:
    var failed := 0
    var total := 0

    var gen = get_script().new()
    var tileset := TileSet.new()
    var params = {
        "width": 2,
        "height": 2,
        "terrain_atlas": {},
        "tileset": tileset,
    }
    var result = gen.build(params)

    total += 1
    if result.map.width != 2 or result.map.height != 2:
        failed += 1

    total += 1
    if result.renderer.grid_size != Vector2i(2, 2):
        failed += 1

    result.bridge.free()
    result.renderer.free()
    result.grid_map.free()
    gen.free()

    return {"failed": failed, "total": total}
