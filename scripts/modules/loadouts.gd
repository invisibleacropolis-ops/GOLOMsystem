extends Node
class_name Loadouts

const Logging = preload("res://scripts/core/logging.gd")

## Computes the current available ability set for an actor based
## on class, equipment, and active statuses.

var base_abilities: Dictionary = {}
var equipment_abilities: Dictionary = {}
var status_abilities: Dictionary = {}
var class_abilities: Dictionary = {}
var event_log: Array = []

func log_event(t: String, actor: Object = null, pos = null, data = null) -> void:
    Logging.log(event_log, t, actor, pos, data)

func grant(actor: Object, ability_id: String) -> void:
    if not base_abilities.has(actor):
        base_abilities[actor] = []
    base_abilities[actor].append(ability_id)
    log_event("ability_granted", actor, null, ability_id)

func grant_from_equipment(actor: Object, ability_id: String) -> void:
    if not equipment_abilities.has(actor):
        equipment_abilities[actor] = []
    equipment_abilities[actor].append(ability_id)

func grant_from_status(actor: Object, ability_id: String) -> void:
    if not status_abilities.has(actor):
        status_abilities[actor] = []
    status_abilities[actor].append(ability_id)

func grant_from_class(actor: Object, ability_id: String) -> void:
    if not class_abilities.has(actor):
        class_abilities[actor] = []
    class_abilities[actor].append(ability_id)

func get_available(actor: Object) -> Array[String]:
    var result: Array[String] = []
    result.append_array(base_abilities.get(actor, []))
    result.append_array(equipment_abilities.get(actor, []))
    result.append_array(status_abilities.get(actor, []))
    result.append_array(class_abilities.get(actor, []))
    return result
func run_tests() -> Dictionary:
    var dummy := Object.new()
    grant(dummy, "ping")
    grant_from_equipment(dummy, "slash")
    grant_from_status(dummy, "fire")
    var avail := get_available(dummy)
    var passed := avail.has("ping") and avail.has("slash") and avail.has("fire")
    dummy.free()
    return {
        "failed": (0 if passed else 1),
        "total": 1,
        "log": "multi-source abilities",
    }
