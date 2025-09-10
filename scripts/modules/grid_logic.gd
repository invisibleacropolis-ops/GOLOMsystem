extends Node
class_name GridLogic

# GridLogic now relies on the `Grid` facade which bundles specialised
# services like pathfinding, line-of-sight, and terrain metadata.  The
# facade exposes the same public API as the old `LogicGridMap` so existing
# callers require minimal changes.

const Grid = preload("res://scripts/grid/grid.gd")
const BaseActor = preload("res://scripts/core/base_actor.gd")
const ProceduralWorld = preload("res://scripts/modules/procedural_world.gd")
const Logging = preload("res://scripts/core/logging.gd")

@export var map: Grid = Grid.new()
var event_log: Array = []

## Record structured events for debugging and tests.
func log_event(t: String, actor: Object = null, pos = null, data = null) -> void:
    Logging.log(event_log, t, actor, pos, data)

func has_actor_at(pos: Vector2i) -> bool:
    return map.is_occupied(pos)

func get_actor_at(pos: Vector2i):
    return map.get_actor_at(pos)

## Generate a procedural world map using noise-based biomes and replace the
## current `map` with the result. Colors are returned for visualization.
func generate_world(width: int, height: int, seed: int = 0) -> Array[Color]:
    var gen := ProceduralWorld.new()
    var result := gen.generate(width, height, seed)
    map = result.map
    log_event("world_generated", null, null, {"width": width, "height": height})
    return result.colors

func can_move(actor: Object, to: Vector2i) -> bool:
    var start: Vector2i = map.actor_positions.get(actor, actor.get("grid_pos"))
    var path: Array[Vector2i] = map.find_path_for_actor(actor, start, to)
    return path.size() > 0

func threatened_tiles(actor: Object) -> Array[Vector2i]:
    var origin: Vector2i = map.actor_positions.get(actor, actor.get("grid_pos"))
    var radius: int = actor.get("ZOC") if "ZOC" in actor else 1
    return map.get_positions_in_range(origin, radius)

func run_tests() -> Dictionary:
    var failed := 0
    var total := 0
    var logs: Array[String] = []

    map.width = 4
    map.height = 4
    var actor := BaseActor.new("ogre", Vector2i.ZERO, Vector2i.RIGHT, Vector2i(2,2))
    map.move_actor(actor, Vector2i.ZERO)

    total += 1
    if not can_move(actor, Vector2i(1,1)):
        failed += 1
        logs.append("multi-tile actor could not move to free space")

    map.set_movement_cost(Vector2i(2,0), INF)
    total += 1
    if can_move(actor, Vector2i(3,0)):
        failed += 1
        logs.append("movement allowed onto impassable tile")

    # Pathfinding regression
    var path := map.find_path_for_actor(actor, Vector2i.ZERO, Vector2i(2,2))
    total += 1
    if path.is_empty() or path[-1] != Vector2i(2,2):
        failed += 1
        logs.append("pathfinding failed to reach goal")

    # Line of sight regression
    map.move_actor(actor, Vector2i(0,2))
    map.set_los_blocker(Vector2i(1,0), true)
    total += 1
    if map.has_line_of_sight(Vector2i(0,0), Vector2i(3,0)):
        failed += 1
        logs.append("LOS not blocked by obstacle")
    map.set_los_blocker(Vector2i(1,0), false)
    total += 1
    if not map.has_line_of_sight(Vector2i(0,0), Vector2i(3,0)):
        failed += 1
        logs.append("LOS incorrectly blocked")

    # Zone of control regression
    actor.set("ZOC", 2)
    map.move_actor(actor, Vector2i(1,1))
    var zoc := threatened_tiles(actor)
    total += 1
    if not zoc.has(Vector2i(3,1)):
        failed += 1
        logs.append("ZOC missing expected tile")

    # Cleanup test actor to avoid leaking nodes in headless runs
    map.remove_actor(actor)
    actor.free()

    return {
        "failed": failed,
        "total": total,
        "log": "\n".join(logs),
    }
