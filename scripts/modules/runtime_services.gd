extends Node
class_name RuntimeServices

## Aggregates core logic modules and exposes them to scenes.
## This node wires together the grid map, turn manager, and
## supplemental services (attributes, statuses, abilities,
## loadouts, reactions, and event bus) so gameplay scenes can
## access a single entry point for logic state.

const LogicGridMap = preload("res://scripts/grid/grid_map.gd")
const TurnBasedGridTimespace = preload("res://scripts/modules/turn_timespace.gd")
const Attributes = preload("res://scripts/modules/attributes.gd")
const Statuses = preload("res://scripts/modules/statuses.gd")
const Abilities = preload("res://scripts/modules/abilities.gd")
const Loadouts = preload("res://scripts/modules/loadouts.gd")
const Reactions = preload("res://scripts/modules/reactions.gd")
const EventBus = preload("res://scripts/modules/event_bus.gd")

var grid_map := LogicGridMap.new()
var timespace := TurnBasedGridTimespace.new()
var attributes := Attributes.new()
var statuses := Statuses.new()
var abilities := Abilities.new()
var loadouts := Loadouts.new()
var reactions := Reactions.new()
var event_bus := EventBus.new()

func _init() -> void:
    ## Timespace requires a grid map for movement.
    timespace.set_grid_map(grid_map)

func _ready() -> void:
    add_child(timespace)
    add_child(attributes)
    add_child(statuses)
    add_child(abilities)
    add_child(loadouts)
    add_child(reactions)
    add_child(event_bus)
    statuses.set_attributes_service(attributes)
    abilities.load_from_file("res://data/actions.json")
    timespace.register_reaction_watcher(func(actor, action_id, payload):
        reactions.trigger(actor, {"action": action_id, "payload": payload}) )

## Execute an integration test that verifies the services can
## operate together. Individual module tests are also run to
## produce an aggregate result for CI.
func run_tests() -> Dictionary:
    var failures := 0
    var total := 1
    var log: Array[String] = []

    # Basic integration: move a single actor on the grid through the timespace
    grid_map.width = 2
    grid_map.height = 2
    var actor := Node.new()
    timespace.add_actor(actor, 5, 1, Vector2i.ZERO)
    timespace.start_round()
    var moved := timespace.move_current_actor(Vector2i(1, 0))
    if not moved:
        failures += 1
        log.append("integration move failed")
    actor.free()

    # Run each module's self-test and accumulate results
    var modules = [attributes, statuses, abilities, loadouts, reactions, event_bus]
    for m in modules:
        if m.has_method("run_tests"):
            var result: Dictionary = m.run_tests()
            failures += int(result.get("failed", 0))
            total += int(result.get("total", 0))
            if int(result.get("failed", 0)) > 0 and result.has("log"):
                log.append(str(result.log))
    if timespace.has_method("run_tests"):
        var tr: Dictionary = timespace.run_tests()
        failures += int(tr.get("failed", 0))
        total += int(tr.get("total", 0))
        if int(tr.get("failed", 0)) > 0 and tr.has("log"):
            log.append(str(tr.log))

    # Free instantiated services to prevent leaks during headless tests
    for m in modules:
        m.free()
    timespace.free()
    grid_map = null

    return {
        "failed": failures,
        "total": total,
        "log": "\n".join(log),
    }
