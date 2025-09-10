# T2GBridge.gd
#
# Simple bridge that mirrors a logical grid into a T2GTerrainLayer and
# triggers its GridMap build step. The bridge decouples game logic from
# the 3D terrain representation provided by the Tilemap-to-GridMap plugin.

extends Node
class_name T2GBridge

const LogicGridMap = preload("res://scripts/grid/grid_map.gd") # Ensure class is available when exporting

## Logical grid backing the world.  `LogicGridMap` stores tile tags and
## dimensions that drive which terrain tiles are painted.  Exporting the
## concrete type makes the bridge self-documenting for outside engineers.
@export var logic: LogicGridMap
## Path to the T2GTerrainLayer node that should reflect the logic grid.
@export var terrain_layer_path: NodePath
## TileSet source id used when writing into the terrain layer.
@export var tile_source_id: int = 0
## Fallback atlas coordinates if a terrain key is missing.
@export var default_atlas: Vector2i = Vector2i.ZERO

## Mapping from custom terrain identifiers to TileSet atlas coordinates.
var TERRAIN_TO_ATLAS: Dictionary = {
    "grass": Vector2i(0, 0),
    "dirt": Vector2i(1, 0),
    "water": Vector2i(2, 0),
    "road": Vector2i(1, 0),
    "hill": Vector2i(0, 0),
    "mountain": Vector2i(0, 0),
}

func _ready() -> void:
    assert(logic != null)
    assert(terrain_layer_path != NodePath())
    push_logic_to_tilemap()
    build_gridmap()

## Call when the underlying logic grid changes.
func refresh_from_logic() -> void:
    push_logic_to_tilemap()
    build_gridmap()

func push_logic_to_tilemap() -> void:
    var layer := get_node(terrain_layer_path)
    layer.clear()
    var W := logic.width
    var H := logic.height
    for y in H:
        for x in W:
            var pos := Vector2i(x, y)
            var terrain_id = _pick_terrain_for(pos)
            if terrain_id == "":
                continue
            var atlas: Vector2i = TERRAIN_TO_ATLAS.get(terrain_id, default_atlas)
            layer.set_cell(pos, tile_source_id, atlas)

## Reads the first tag for the requested position from the `LogicGridMap`.
## Returns `null` if no tags are present so callers can skip painting.
func _pick_terrain_for(pos: Vector2i) -> String:
    if logic == null:
        return ""
    var tags = logic.tile_tags.get(pos, [])
    return tags[0] if tags.size() > 0 else ""

func build_gridmap() -> void:
    var layer := get_node(terrain_layer_path)
    if layer.has_method("build_gridmap"):
        layer.call("build_gridmap")
    else:
        push_warning("T2GTerrainLayer lacks 'build_gridmap()'.")
