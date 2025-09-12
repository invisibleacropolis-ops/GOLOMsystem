extends Node

var Logging = ResourceLoader.load(
    "res://scripts/core/logging.gd",
    "",
    ResourceLoader.CacheMode.CACHE_MODE_IGNORE,
)

## Computes the current available ability set for an actor based
## on class, equipment, and active statuses.

var base_abilities: Dictionary = {}
var equipment_abilities: Dictionary = {}
var status_abilities: Dictionary = {}
var class_abilities: Dictionary = {}
var event_log: Array = []

## Removes any entries that reference freed actors.
func _prune_invalid(dict: Dictionary) -> void:
    for actor in dict.keys():
        if not is_instance_valid(actor):
            dict.erase(actor)
            log_event("actor_released", actor)

## Completely clear all stored ability references. Helpful for tests
## and for catching lingering references during shutdown.
func clear() -> void:
    base_abilities.clear()
    equipment_abilities.clear()
    status_abilities.clear()
    class_abilities.clear()
    event_log.clear()

func log_event(t: String, actor: Object = null, pos = null, data = null) -> void:
    Logging.log(event_log, t, actor, pos, data)

func grant(actor: Object, ability_id: String) -> void:
    if not is_instance_valid(actor):
        push_warning("Loadouts.grant called with invalid actor")
        return
    if not base_abilities.has(actor):
        base_abilities[actor] = []
    base_abilities[actor].append(ability_id)
    log_event("ability_granted", actor, null, ability_id)

func grant_from_equipment(actor: Object, ability_id: String) -> void:
    if not is_instance_valid(actor):
        push_warning("Loadouts.grant_from_equipment called with invalid actor")
        return
    if not equipment_abilities.has(actor):
        equipment_abilities[actor] = []
    equipment_abilities[actor].append(ability_id)

func grant_from_status(actor: Object, ability_id: String) -> void:
    if not is_instance_valid(actor):
        push_warning("Loadouts.grant_from_status called with invalid actor")
        return
    if not status_abilities.has(actor):
        status_abilities[actor] = []
    status_abilities[actor].append(ability_id)

func grant_from_class(actor: Object, ability_id: String) -> void:
    if not is_instance_valid(actor):
        push_warning("Loadouts.grant_from_class called with invalid actor")
        return
    if not class_abilities.has(actor):
        class_abilities[actor] = []
    class_abilities[actor].append(ability_id)

func get_available(actor: Object) -> Array[String]:
    _prune_invalid(base_abilities)
    _prune_invalid(equipment_abilities)
    _prune_invalid(status_abilities)
    _prune_invalid(class_abilities)
    var result: Array[String] = []
    result.append_array(base_abilities.get(actor, []))
    result.append_array(equipment_abilities.get(actor, []))
    result.append_array(status_abilities.get(actor, []))
    result.append_array(class_abilities.get(actor, []))
    return result

## Remove ability references for a specific actor.
func cleanup_actor(actor: Object) -> void:
    base_abilities.erase(actor)
    equipment_abilities.erase(actor)
    status_abilities.erase(actor)
    class_abilities.erase(actor)
    log_event("actor_cleanup", actor)
func run_tests() -> Dictionary:
    var dummy := Object.new()
    grant(dummy, "ping")
    grant_from_equipment(dummy, "slash")
    grant_from_status(dummy, "fire")
    var avail := get_available(dummy)
    var passed := avail.has("ping") and avail.has("slash") and avail.has("fire")
    cleanup_actor(dummy)
    dummy.free()
    clear()
    return {
        "failed": (0 if passed else 1),
        "total": 1,
        "log": "multi-source abilities",
    }

func _exit_tree() -> void:
    Logging = null
