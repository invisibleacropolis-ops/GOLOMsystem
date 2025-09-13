# Provides pathfinding utilities for grid maps.
#
# Outside engineers can use this service to perform path queries without
# needing intimate knowledge of the underlying `LogicGridMap` data
# structure.  The service simply delegates to the map instance supplied at
# construction time.
extends Resource
class_name GridPathfinding

const LogicGridMap = preload("res://scripts/grid/grid_map.gd")

var _map: LogicGridMap

func _init(map: LogicGridMap) -> void:
    _map = map

## Find a path between two points on the grid.
##
## @param start        Starting tile coordinate.
## @param goal         Target tile coordinate.
## @param size         Footprint of the actor; defaults to a single tile.
## @param start_facing Initial facing direction (used for turn costs).
## @return Array of tile coordinates representing the path. Empty if unreachable.
func find_path(
    start: Vector2i,
    goal: Vector2i,
    size: Vector2i = Vector2i.ONE,
    start_facing: Vector2i = Vector2i.RIGHT
) -> Array[Vector2i]:
    return _map.find_path(start, start_facing, goal, size)

## Convenience wrapper for actors that already exist on the map.
##
## @param actor Actor to move.
## @param start Starting tile coordinate.
## @param goal  Target tile coordinate.
func find_path_for_actor(actor: Object, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
    return _map.find_path_for_actor(actor, start, goal)
