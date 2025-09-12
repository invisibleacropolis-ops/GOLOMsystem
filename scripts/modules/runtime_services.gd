extends Node
class_name RuntimeServices

## Aggregates core logic modules and exposes them to scenes.
## This node wires together the grid map, turn manager, and
## supplemental services (attributes, statuses, abilities,
## loadouts, reactions, and event bus) so gameplay scenes can
## access a single entry point for logic state.

var _LogicGridMapScript
var _TurnTimespaceScript
var _AttributesScript
var _StatusesScript
var _AbilitiesScript
var _LoadoutsScript
var _ReactionsScript
var _EventBusScript

var grid_map
var timespace
var attributes
var statuses
var abilities
var loadouts
var reactions
var event_bus

func _init() -> void:
    # Load scripts at runtime to avoid static preload failures.
    _LogicGridMapScript = ResourceLoader.load(
        "res://scripts/grid/grid_map.gd",
        "",
        ResourceLoader.CacheMode.CACHE_MODE_IGNORE,
    )
    _TurnTimespaceScript = ResourceLoader.load(
        "res://scripts/modules/turn_timespace.gd",
        "",
        ResourceLoader.CacheMode.CACHE_MODE_IGNORE,
    )
    _AttributesScript = ResourceLoader.load(
        "res://scripts/modules/attributes.gd",
        "",
        ResourceLoader.CacheMode.CACHE_MODE_IGNORE,
    )
    _StatusesScript = ResourceLoader.load(
        "res://scripts/modules/statuses.gd",
        "",
        ResourceLoader.CacheMode.CACHE_MODE_IGNORE,
    )
    _AbilitiesScript = ResourceLoader.load(
        "res://scripts/modules/abilities.gd",
        "",
        ResourceLoader.CacheMode.CACHE_MODE_IGNORE,
    )
    _LoadoutsScript = ResourceLoader.load(
        "res://scripts/modules/loadouts.gd",
        "",
        ResourceLoader.CacheMode.CACHE_MODE_IGNORE,
    )
    _ReactionsScript = ResourceLoader.load(
        "res://scripts/modules/reactions.gd",
        "",
        ResourceLoader.CacheMode.CACHE_MODE_IGNORE,
    )
    _EventBusScript = ResourceLoader.load(
        "res://scripts/modules/event_bus.gd",
        "",
        ResourceLoader.CacheMode.CACHE_MODE_IGNORE,
    )

    grid_map = _LogicGridMapScript.new()
    timespace = _TurnTimespaceScript.new(); timespace.name = "TurnTimespace"
    attributes = _AttributesScript.new(); attributes.name = "Attributes"
    statuses = _StatusesScript.new(); statuses.name = "Statuses"
    abilities = _AbilitiesScript.new(); abilities.name = "Abilities"
    loadouts = _LoadoutsScript.new(); loadouts.name = "Loadouts"
    reactions = _ReactionsScript.new(); reactions.name = "Reactions"
    event_bus = _EventBusScript.new(); event_bus.name = "EventBus"
    abilities.event_bus = event_bus
    # Timespace requires a grid map for movement.
    timespace.set_grid_map(grid_map)

func _ready() -> void:
    # Ensure stable names for child services
    if timespace: timespace.name = "TurnTimespace"
    if attributes: attributes.name = "Attributes"
    if statuses: statuses.name = "Statuses"
    if abilities: abilities.name = "Abilities"
    if loadouts: loadouts.name = "Loadouts"
    if reactions: reactions.name = "Reactions"
    if event_bus: event_bus.name = "EventBus"
    add_child(grid_map)
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
    # Bridge key timespace signals into the event_bus for UI consumption.
    if event_bus:
        timespace.round_started.connect(func(): event_bus.push({"t": "round_start"}))
        timespace.round_ended.connect(func(): event_bus.push({"t": "round_end"}))
        timespace.turn_started.connect(func(actor): event_bus.push({"t": "turn_start", "actor": actor}))
        timespace.turn_ended.connect(func(actor): event_bus.push({"t": "turn_end", "actor": actor}))
        timespace.ap_changed.connect(func(actor, old, new): event_bus.push({"t": "ap", "actor": actor, "data": {"old": old, "new": new}}))
        timespace.status_applied.connect(func(target, status): event_bus.push({"t": "status_on", "actor": target, "data": {"status": status}}))
        timespace.status_removed.connect(func(target, status): event_bus.push({"t": "status_off", "actor": target, "data": {"status": status}}))
        timespace.action_performed.connect(func(actor, id, payload): event_bus.push({"t": "action", "actor": actor, "data": {"id": id, "payload": payload}}))
        timespace.damage_applied.connect(func(attacker, defender, amount): event_bus.push({"t": "damage", "actor": attacker, "data": {"defender": defender, "amount": amount}}))
        timespace.battle_over.connect(func(faction): event_bus.push({"t": "battle_over", "data": {"faction": faction}}))
        timespace.reaction_triggered.connect(func(actor, data): event_bus.push({"t": "reaction", "actor": actor, "data": data}))

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
    var actor = Node.new()
    # Name the temporary actor to avoid empty-name warnings when events are logged.
    actor.name = "TestActor"
    timespace.add_actor(actor, 5, 1, Vector2i.ZERO)
    timespace.start_round()
    var moved = timespace.move_current_actor(Vector2i(1, 0))
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

    # Vertical slice smoke: 1-shot KO and victory
    var ts_vs = _TurnTimespaceScript.new()
    var gm_vs = _LogicGridMapScript.new()
    ts_vs.set_grid_map(gm_vs)
    var Actor = preload("res://scripts/core/base_actor.gd")
    var p = Actor.new("P", Vector2i(0,0), Vector2i.RIGHT, Vector2i.ONE, "player")
    var e = Actor.new("E", Vector2i(2,0), Vector2i.LEFT, Vector2i.ONE, "enemy")
    e.HLTH = 1
    ts_vs.add_actor(p, 10, 2, p.grid_pos)
    ts_vs.add_actor(e, 5, 1, e.grid_pos)
    var battle_over_called = []
    ts_vs.battle_over.connect(func(faction): battle_over_called.append(faction))
    ts_vs.start_round()
    var okatk = ts_vs.perform(p, "attack", e)
    if not okatk:
        failures += 1
        log.append("vs: attack not allowed")
    # Allow signals to propagate and removal to occur
    ts_vs.check_battle_end()
    if battle_over_called.size() == 0:
        failures += 1
        log.append("vs: battle_over not emitted")

    # Free instantiated services to prevent leaks during headless tests
    for m in modules:
        m.free()
    timespace.free()
    if grid_map:
        grid_map.free()
    grid_map = null
    p.free()
    e.free()
    gm_vs.free()
    ts_vs.free()
    attributes = null
    statuses = null
    abilities = null
    loadouts = null
    reactions = null
    event_bus = null
    _LogicGridMapScript = null
    _TurnTimespaceScript = null
    _AttributesScript = null
    _StatusesScript = null
    _AbilitiesScript = null
    _LoadoutsScript = null
    _ReactionsScript = null
    _EventBusScript = null

    return {
        "failed": failures,
        "total": total,
        "log": "\n".join(log),
    }

func _exit_tree() -> void:
    grid_map = null
    timespace = null
    attributes = null
    statuses = null
    abilities = null
    loadouts = null
    reactions = null
    event_bus = null
    _LogicGridMapScript = null
    _TurnTimespaceScript = null
    _AttributesScript = null
    _StatusesScript = null
    _AbilitiesScript = null
    _LoadoutsScript = null
    _ReactionsScript = null
    _EventBusScript = null
