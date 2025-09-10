extends Node
class_name Statuses

signal status_applied(actor, id)
signal status_removed(actor, id)

const Logging = preload("res://scripts/core/logging.gd")

## Buffs, debuffs, and stances applied to actors or tiles.
## Tracks stacks, durations, and associated attribute modifiers.

var actor_statuses: Dictionary = {}
var event_log: Array = []
var attributes

func log_event(t: String, actor: Object = null, pos = null, data = null) -> void:
    Logging.log(event_log, t, actor, pos, data)

func set_attributes_service(svc) -> void:
    attributes = svc

func apply_status(actor: Object, id: String, stacks: int = 1, duration: int = 1, modifiers: Array = []) -> void:
    if not actor_statuses.has(actor):
        actor_statuses[actor] = {}
    var entry = actor_statuses[actor].get(id, {"stacks": 0, "duration": 0, "mods": []})
    entry["stacks"] = entry["stacks"] + stacks
    entry["duration"] = max(entry["duration"], duration)
    for mod in modifiers:
        if attributes:
            var src = "%s_%s" % [id, mod.get("key")]
            attributes.add_modifier(actor, mod.get("key"), mod.get("add",0.0), 1.0, src, 0, mod.get("perc",0.0))
            entry["mods"].append(src)
    actor_statuses[actor][id] = entry
    emit_signal("status_applied", actor, id)
    log_event("status_applied", actor, null, id)

## Reduce all durations by one turn and purge expired statuses.
func tick() -> void:
    for actor in actor_statuses.keys():
        var expired: Array[String] = []
        for id in actor_statuses[actor].keys():
            actor_statuses[actor][id]["duration"] = actor_statuses[actor][id]["duration"] - 1
            if actor_statuses[actor][id]["duration"] <= 0:
                expired.append(id)
        for id in expired:
            var entry = actor_statuses[actor].get(id, {})
            for src in entry.get("mods", []):
                if attributes:
                    attributes.clear_modifiers(actor, src)
            actor_statuses[actor].erase(id)
            emit_signal("status_removed", actor, id)
            log_event("status_expired", actor, null, id)

func run_tests() -> Dictionary:
    var dummy := Object.new()
    var attrs_script := ResourceLoader.load("res://scripts/modules/attributes.gd", "", ResourceLoader.CacheMode.CACHE_MODE_IGNORE)
    var attrs = attrs_script.new()
    set_attributes_service(attrs)
    attrs.set_base(dummy, "STR", 10)
    apply_status(dummy, "buff", 1, 1, [{"key": "STR", "add": 5}])
    tick()
    var cleared: bool = attrs.get_value(dummy, "STR") == 10
    dummy.free()
    # Free temporary objects created for the test to keep runs clean
    attrs.free()
    attrs = null
    attrs_script = null
    return {
        "failed": (0 if cleared else 1),
        "total": 1,
        "log": "status expiry removes modifiers",
    }
