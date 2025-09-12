# Integrates the Tile to GridMap plugin with the project's logic and renderer.
#
# This bridge calls into the T2GTerrainLayer to build the visual GridMap and
# then mirrors that state into a LogicGridMap and optional GridRealtimeRenderer.
# It provides a single entry point so procedural generators or editor tools can
# trigger a rebuild at any time.
extends Node
class_name TileToGridMapBridge

const LogicGridMap = preload("res://scripts/grid/grid_map.gd")
const GridRealtimeRenderer = preload("res://scripts/modules/GridRealtimeRenderer.gd")

## Nodes referenced by the bridge
@export var terrain_layer: NodePath
@export var grid_map: GridMap
@export var logic_map: LogicGridMap
@export var renderer: GridRealtimeRenderer

## Placeholder tile types. Mesh names beginning with these tokens will
## apply matching tags in the LogicGridMap.
const TILE_TYPES := ["roof_wood", "roof_stone", "wall_brick"]

## Builds the GridMap from the TileMap and synchronises logic/visual layers.
func build_from_tilemap() -> void:
    var layer: Node = get_node_or_null(terrain_layer)
    if layer and layer.has_method("build_gridmap"):
        layer.build_gridmap()
    if grid_map and grid_map.mesh_library:
        _ensure_texture_repeat(grid_map.mesh_library)
    if logic_map and grid_map:
        _sync_logic_from_gridmap()
    if renderer and logic_map:
        _sync_renderer()

## Pulls mesh names from the GridMap and tags cells in the LogicGridMap.
func _sync_logic_from_gridmap() -> void:
    var used := grid_map.get_used_cells()
    if used.is_empty():
        return
    var min_x := used[0].x
    var max_x := used[0].x
    var min_z := used[0].z
    var max_z := used[0].z
    for cell in used:
        min_x = min(min_x, cell.x)
        max_x = max(max_x, cell.x)
        min_z = min(min_z, cell.z)
        max_z = max(max_z, cell.z)
        var item := grid_map.get_cell_item(cell)
        if item == -1:
            continue
        var name := grid_map.mesh_library.get_item_name(item)
        for t in TILE_TYPES:
            if name.begins_with(t):
                logic_map.add_tile_tag(Vector2i(cell.x, cell.z), t)
                break
    logic_map.width = max(logic_map.width, max_x - min_x + 1)
    logic_map.height = max(logic_map.height, max_z - min_z + 1)

## Updates the realtime renderer to match the logical grid dimensions.
func _sync_renderer() -> void:
    renderer.grid_size = Vector2i(logic_map.width, logic_map.height)
    # Future: feed renderer channels based on tile tags or heights

## Reveals only the specified roof region instead of toggling the entire grid.
func reveal_roof_region(tiles: Array[Vector2i]) -> void:
    # TODO: hide meshes covering these tiles while keeping others visible.
    push_warning("Roof reveal stub for %d tiles" % tiles.size())

## For shader-based reveals, forward player position to roof materials.
func update_reveal_shader(world_pos: Vector3, radius: float) -> void:
    # TODO: iterate roof materials and update uniforms for reveal effect.
    push_warning("Shader update stub at %s r=%f" % [world_pos, radius])

## Ensure textures cover entire mesh tiles by enabling repeat on materials.
func _ensure_texture_repeat(lib: MeshLibrary) -> void:
    for id in lib.get_item_list():
        var mesh := lib.get_item_mesh(id)
        if mesh == null:
            continue
        for s in mesh.get_surface_count():
            var mat := mesh.surface_get_material(s)
            if mat is StandardMaterial3D:
                mat.texture_repeat = true

# -----------------------------------------------------------------------------
# Planned Features (scaffolding)
# - Per-building reveal: group roof cells by region and only hide that region
#   instead of the whole roof GridMap.
# - Shader reveal: roof material clips/fades above the player. This bridge will
#   pass player position to materials once implemented.
# - True perimeter walls: check four-neighbors and only place *_mid meshes on
#   interior edges, leaving space inside structures.
# - Stairs/portals: read TileSet custom data to place navigation links between
#   interior and exterior levels.
# -----------------------------------------------------------------------------
