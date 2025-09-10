extends Node
class_name Reactions

const Logging = preload("res://scripts/core/logging.gd")

## Interrupt engine that queues reaction abilities with priority
## rather than simple FIFO ordering. Provides inspection hooks for AI.

signal reaction_queued(reaction)

var queued: Array = []
var event_log: Array = []

func log_event(t: String, actor: Object = null, pos = null, data = null) -> void:
    Logging.log(event_log, t, actor, pos, data)

func trigger(actor: Object, data, priority: int = 0) -> void:
    queued.append({"actor": actor, "data": data, "priority": priority})
    queued.sort_custom(func(a, b): return a["priority"] > b["priority"])
    emit_signal("reaction_queued", queued[0])
    log_event("reaction_triggered", actor, null, {"data": data, "p": priority})

func resolve_next():
    if queued.is_empty():
        return null
    return queued.pop_front()

func get_pending() -> Array:
    return queued.duplicate()

func run_tests() -> Dictionary:
    var a := Object.new()
    var b := Object.new()
    trigger(a, "low", 1)
    trigger(b, "high", 5)
    var item = resolve_next()
    var passed: bool = item["actor"] == b
    a.free()
    b.free()
    return {
        "failed": (0 if passed else 1),
        "total": 1,
        "log": "priority queue",
    }
