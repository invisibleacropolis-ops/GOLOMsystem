# Terrain metadata helpers for a `LogicGridMap`.
#
# This service exposes common operations like setting movement costs or
# adjusting height levels.  It delegates to the supplied map instance so
# systems can remain decoupled from the core grid representation.
extends Resource
# Loaded on demand without `class_name` or `preload` so the resource can be
# released cleanly after automated tests.

var _map

func _init(map: Object) -> void:
    _map = map

## Override movement cost for a tile.  Use `INF` for impassable terrain.
func set_movement_cost(pos: Vector2i, cost: float) -> void:
    _map.set_movement_cost(pos, cost)

## Retrieve the movement cost for a tile.  Defaults to `1.0`.
func get_movement_cost(pos: Vector2i) -> float:
    return _map.get_movement_cost(pos)

## Set the height level for a tile.
func set_height(pos: Vector2i, level: int) -> void:
    _map.set_height(pos, level)

## Get the height level for a tile.  Defaults to `0`.
func get_height(pos: Vector2i) -> int:
    return _map.get_height(pos)
