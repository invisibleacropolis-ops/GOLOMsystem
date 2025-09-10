# T2GTerrainLayer.gd
#
# Lightweight layer that mirrors a 2D TileMapLayer into a 3D GridMap.
# The TileSet must define custom data layers named "Name", "Height",
# and optional "Exclude" per tile. Meshes inside the GridMap's MeshLibrary
# follow the 16-bitmask naming scheme (e.g. grass0 .. grass15).
#
# Usage:
#   - Assign a TileSet with the required custom data layers.
#   - Paint tiles in the editor or via code.
#   - Set `grid_map_path` to a GridMap node that has a matching MeshLibrary.
#   - Call `build_gridmap()` to populate the GridMap with meshes.
#
# Grid height values are expressed in half-units (2ft). A height of 2 equals
# one full tile (4ft) above the base level.

extends TileMapLayer
class_name T2GTerrainLayer

## Path to the target GridMap. The GridMap must have a MeshLibrary with
## mesh names that match the tile base name + bitmask value.
@export var grid_map_path: NodePath

## Precomputed neighbor directions for bitmasking.
const NEIGHBORS := {
    Vector2i(0, -1): 1,   # Up
    Vector2i(1, 0): 2,    # Right
    Vector2i(0, 1): 4,    # Down
    Vector2i(-1, 0): 8,   # Left
}

var _grid_map: GridMap = null

func _ready() -> void:
    # Defer lookup so sibling nodes exist when resolving the GridMap path
    if grid_map_path != NodePath():
        call_deferred("_init_grid_map")

func _init_grid_map() -> void:
    _grid_map = get_node_or_null(grid_map_path)
    if _grid_map == null:
        push_warning("T2GTerrainLayer: GridMap not found. Set 'grid_map_path'.")

## Builds the assigned GridMap from the painted TileMap cells.
func build_gridmap() -> void:
    if _grid_map == null:
        return
    if _grid_map.mesh_library == null:
        push_warning("T2GTerrainLayer: GridMap lacks a MeshLibrary.")
        return
    _grid_map.clear()
    for cell in get_used_cells():
        var data := get_cell_tile_data(cell)
        if data == null:
            continue
        var base_name := String(data.get_custom_data("Name"))
        if base_name == "":
            continue
        var height := int(data.get_custom_data("Height"))
        var bitmask := _compute_bitmask(cell, base_name, height)
        var mesh_name := "%s%d" % [base_name, bitmask]
        var item_id := _find_mesh_item(_grid_map.mesh_library, mesh_name)
        if item_id == -1:
            continue
        var pos := Vector3i(cell.x, height, cell.y)
        _grid_map.set_cell_item(pos, item_id)

## Computes the 4-direction bitmask for a given cell.
func _compute_bitmask(cell: Vector2i, name: String, height: int) -> int:
    var mask := 0
    for dir in NEIGHBORS.keys():
        var neighbor := get_cell_tile_data(cell + dir)
        if neighbor == null:
            continue
        var n_name := String(neighbor.get_custom_data("Name"))
        var n_height := int(neighbor.get_custom_data("Height"))
        var n_exclude := String(neighbor.get_custom_data("Exclude"))
        var excluded := n_exclude.split(",", false)
        if n_name == name and n_height == height and !excluded.has(name):
            mask |= NEIGHBORS[dir]
    return mask

## Returns the mesh item id whose name matches the given string.
func _find_mesh_item(lib: MeshLibrary, mesh_name: String) -> int:
    for id in lib.get_item_list():
        var n := lib.get_item_name(id)
        if n == mesh_name or n.begins_with(mesh_name):
            return id
    push_warning("T2GTerrainLayer: Missing mesh '%s'" % mesh_name)
    return -1
