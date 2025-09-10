# Line-of-sight helpers operating on a `LogicGridMap`.
#
# External tools can use this module to query visibility without touching
# the map's internal state directly.
extends Resource
class_name GridLOS

const LogicGridMap = preload("res://scripts/grid/grid_map.gd")

var _map: LogicGridMap

func _init(map: LogicGridMap) -> void:
    _map = map

## Mark or clear a tile as blocking line of sight.
func set_blocker(pos: Vector2i, blocks: bool = true) -> void:
    _map.set_los_blocker(pos, blocks)

## Returns true if the tile is a line-of-sight blocker.
func is_blocker(pos: Vector2i) -> bool:
    return _map.is_los_blocker(pos)

## Determine whether two tiles can see each other.
func has_line_of_sight(a: Vector2i, b: Vector2i) -> bool:
    return _map.has_line_of_sight(a, b)
