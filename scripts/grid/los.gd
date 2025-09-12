# Line-of-sight helpers operating on a `LogicGridMap`.
#
# External tools can use this module to query visibility without touching
# the map's internal state directly.
extends Resource
# Avoid global class registration and cached preloads so this helper
# can be released without leaving lingering script resources.

var _map

func _init(map: Object) -> void:
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
