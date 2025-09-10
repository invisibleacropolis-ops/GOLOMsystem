extends Node
class_name Terrain

const LogicGridMap = preload("res://scripts/grid/grid_map.gd")
const Logging = preload("res://scripts/core/logging.gd")

## Manages terrain type definitions and runtime modifications.
## Loads default definitions from `data/terrain.json` and can apply
## properties to `LogicGridMap` instances. Designed so terrain tags
## and movement costs can be changed while the game is running.

var definitions: Dictionary = {}
var event_log: Array = []

func _init() -> void:
    load_from_file("res://data/terrain.json")

## Load terrain types from a JSON file.
func load_from_file(path: String) -> void:
    var file := FileAccess.open(path, FileAccess.READ)
    if file:
        var data = JSON.parse_string(file.get_as_text())
        if typeof(data) == TYPE_DICTIONARY:
            definitions = data
            log_event("terrain_loaded", null, null, definitions.size())
        file.close()

func log_event(t: String, actor: Object = null, pos = null, data = null) -> void:
    Logging.log(event_log, t, actor, pos, data)

## Register or override a terrain definition at runtime.
func register_type(id: String, data: Dictionary) -> void:
    definitions[id] = data
    log_event("terrain_registered", null, null, id)

## Fetch a terrain definition.
func get_type(id: String) -> Dictionary:
    return definitions.get(id, {})

## Set a single property on a terrain type.
func set_property(id: String, key: String, value) -> void:
    if definitions.has(id):
        definitions[id][key] = value
        log_event("terrain_property_set", null, null, {"id": id, "key": key})

## Get terrain IDs that contain a tag.
func get_with_tag(tag: String) -> Array:
    var result: Array = []
    for id in definitions.keys():
        var tags: Array = definitions[id].get("tags", [])
        if tag in tags:
            result.append(id)
    return result

## Apply a terrain definition to a tile on a LogicGridMap.
func apply_to_map(map: LogicGridMap, pos: Vector2i, id: String) -> void:
    if not definitions.has(id):
        return
    var data: Dictionary = definitions[id]
    var tags: Array = data.get("tags", []).duplicate()
    tags.append(id)
    map.tile_tags[pos] = tags
    if data.get("move_cost", 1.0) >= 0:
        map.movement_costs[pos] = data.get("move_cost", 1.0)
    else:
        map.movement_costs[pos] = INF
    if data.get("blocks_vision", false):
        map.los_blockers[pos] = true
    else:
        map.los_blockers.erase(pos)

func run_tests() -> Dictionary:
    var map := LogicGridMap.new()
    map.width = 2
    map.height = 2
    apply_to_map(map, Vector2i.ZERO, "grass")
    var first_tags = map.tile_tags.get(Vector2i.ZERO, [])
    var moved_cost = map.movement_costs.get(Vector2i.ZERO, 0)
    set_property("grass", "move_cost", 2.0)
    apply_to_map(map, Vector2i(1,0), "grass")
    var updated_cost = map.movement_costs.get(Vector2i(1,0), 0)
    var flammable = get_with_tag("flammable")
    var passed = first_tags.has("grass") and moved_cost == 1.0 and updated_cost == 2.0 and flammable.has("grass")
    map = null
    return {
        "failed": (0 if passed else 1),
        "total": 1,
    }
