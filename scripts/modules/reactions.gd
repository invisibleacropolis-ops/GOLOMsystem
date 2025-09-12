extends Node
class_name Reactions

const Logging = preload("res://scripts/core/logging.gd")

## Interrupt engine that queues reaction abilities with priority
## rather than simple FIFO ordering. Provides inspection hooks for AI.

signal reaction_queued(reaction)

var queued: Array = []
var event_log: Array = []

## Remove entries referencing freed actors.
func _prune_invalid() -> void:
    for i in range(queued.size() - 1, -1, -1):
        var actor = queued[i]["actor"]
        if not is_instance_valid(actor):
            queued.remove_at(i)
            log_event("actor_released", actor)

## Clear all queued reactions and event logs.
func clear() -> void:
    queued.clear()
    event_log.clear()

func log_event(t: String, actor: Object = null, pos = null, data = null) -> void:
    Logging.log(event_log, t, actor, pos, data)

func trigger(actor: Object, data, priority: int = 0) -> void:
    if not is_instance_valid(actor):
        push_warning("Reactions.trigger called with invalid actor")
        return
    queued.append({"actor": actor, "data": data, "priority": priority})
    queued.sort_custom(func(a, b): return a["priority"] > b["priority"])
    emit_signal("reaction_queued", queued[0])
    log_event("reaction_triggered", actor, null, {"data": data, "p": priority})

func resolve_next():
    _prune_invalid()
    if queued.is_empty():
        return null
    return queued.pop_front()

func get_pending() -> Array:
    _prune_invalid()
    return queued.duplicate()

## Remove any reactions for the specified actor.
func cleanup_actor(actor: Object) -> void:
    for i in range(queued.size() - 1, -1, -1):
        if queued[i]["actor"] == actor:
            queued.remove_at(i)
    log_event("actor_cleanup", actor)

func run_tests() -> Dictionary:
    var a := Object.new()
    var b := Object.new()
    trigger(a, "low", 1)
    trigger(b, "high", 5)
    var item = resolve_next()
    var passed: bool = item["actor"] == b
    cleanup_actor(a)
    cleanup_actor(b)
    a.free()
    b.free()
    clear()
    return {
        "failed": (0 if passed else 1),
        "total": 1,
        "log": "priority queue",
    }
