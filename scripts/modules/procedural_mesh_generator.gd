# ProceduralMeshGenerator.gd
#
# Skeleton service responsible for spawning GridMap meshes based on the
# project's LogicGridMap. This file establishes constants for early tile types
# and notes future expansion tasks.
extends Node
class_name ProceduralMeshGenerator

const LogicGridMap = preload("res://scripts/grid/grid_map.gd")

## Known tile identifiers. Actual meshes and materials will be supplied later.
const TILE_ROOF_WOOD := "roof_wood"
const TILE_ROOF_STONE := "roof_stone"
const TILE_WALL_BRICK := "wall_brick"

## Entry point used by tests or runtime tools.
func generate_for(map: LogicGridMap, grid_map: GridMap) -> void:
    # TODO: Use TileToGridMapBridge to populate the GridMap, then instantiate
    # additional props or variations as needed.
    for tag_pos in map.tile_tags.keys():
        var tags: Array = map.tile_tags[tag_pos]
        if TILE_ROOF_WOOD in tags:
            _place_placeholder_mesh(grid_map, tag_pos, TILE_ROOF_WOOD)
        elif TILE_ROOF_STONE in tags:
            _place_placeholder_mesh(grid_map, tag_pos, TILE_ROOF_STONE)
        elif TILE_WALL_BRICK in tags:
            _place_placeholder_mesh(grid_map, tag_pos, TILE_WALL_BRICK)
    _build_perimeter_walls(map, grid_map)
    _place_portal_markers(map, grid_map)

func _place_placeholder_mesh(grid_map: GridMap, pos: Vector2i, kind: String) -> void:
    # Placeholder implementation that simply logs intent. Real implementation
    # will instance meshes or scenes and handle height offsets.
    push_warning("Mesh generation stub: %s at %s" % [kind, pos])

## Groups connected roof cells so individual buildings can be revealed.
func reveal_building(region_tiles: Array[Vector2i]) -> void:
    # TODO: Hide or show only the meshes covering this region.
    push_warning("Reveal stub for region with %d tiles" % region_tiles.size())

## Pushes player position and radius to roof materials for fade-out reveals.
func update_roof_shader(world_pos: Vector3, radius: float) -> void:
    # TODO: Iterate roof materials and set shader parameters.
    push_warning("Shader reveal stub at %s (r=%f)" % [world_pos, radius])

## Checks neighbours to place wall segments only on exterior edges.
func _build_perimeter_walls(map: LogicGridMap, grid_map: GridMap) -> void:
    # TODO: Inspect 4-neighbours and replace *_mid meshes on interior faces.
    # Placeholder just logs the call for now.
    push_warning("Perimeter wall stub for %d tiles" % map.tile_tags.size())

## Reads TileSet custom data for stairs/portal markers and spawns props.
func _place_portal_markers(map: LogicGridMap, grid_map: GridMap) -> void:
    # TODO: Instantiate portal scenes and connect navigation layers.
    push_warning("Portal placement stub for %d tiles" % map.tile_tags.size())

# -----------------------------------------------------------------------------
# Future Work
# - Per-building reveal: group roof cells by region and hide only the relevant
#   grid chunks when needed.
# - Shader reveal: supply u_reveal_pos/radius uniforms to roof materials so they
#   fade above the player without rebuilding meshes.
# - True perimeter walls: examine four-neighbors to decide where *_mid segments
#   belong, leaving interiors hollow.
# - Stairs/portals: parse TileSet custom data to place connectors and build
#   navigation links between levels.
# -----------------------------------------------------------------------------
