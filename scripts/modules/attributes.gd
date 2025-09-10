extends Node
class_name Attributes

const Logging = preload("res://scripts/core/logging.gd")

## Numbers and modifiers service.
## Provides a single read point for actor stats so every formula
## queries `get_value(actor, key)` instead of raw fields.
## Supports base values and additive/multiplicative modifiers
## with optional sources and durations.

var base_values: Dictionary = {}
var modifiers: Dictionary = {}
var ranges: Dictionary = {}
var event_log: Array = []

## Push an event into the shared log using the structured schema.
func log_event(t: String, actor: Object = null, pos = null, data = null) -> void:
    Logging.log(event_log, t, actor, pos, data)

## Set the base value for an actor/key pair.
func set_base(actor: Object, key: String, value: float) -> void:
    if not base_values.has(actor):
        base_values[actor] = {}
    base_values[actor][key] = value
    log_event("base_set", actor, null, {"key": key, "value": value})

## Add a modifier entry. `add` applies before multiplication.
func add_modifier(actor: Object, key: String, add: float = 0.0, mul: float = 1.0, source: String = "", duration: int = 0, perc: float = 0.0) -> void:
    if not modifiers.has(actor):
        modifiers[actor] = {}
    if not modifiers[actor].has(key):
        modifiers[actor][key] = []
    modifiers[actor][key].append({"add": add, "mul": mul, "source": source, "duration": duration, "perc": perc})
    log_event("modifier_added", actor, null, {"key": key})

## Remove modifiers originating from `source`.
func clear_modifiers(actor: Object, source: String) -> void:
    if not modifiers.has(actor):
        return
    for key in modifiers[actor].keys():
        var filtered := []
        for m in modifiers[actor][key]:
            if m.get("source", "") != source:
                filtered.append(m)
        modifiers[actor][key] = filtered
    log_event("modifiers_cleared", actor, null, {"source": source})

## Compute the final value from base and all modifiers.
func get_value(actor: Object, key: String) -> float:
    var base := 0.0
    if base_values.has(actor) and base_values[actor].has(key):
        base = base_values[actor][key]
    var add := 0.0
    var mul := 1.0
    var perc := 0.0
    if modifiers.has(actor) and modifiers[actor].has(key):
        for mod in modifiers[actor][key]:
            add += mod.get("add", 0.0)
            mul *= mod.get("mul", 1.0)
            perc += mod.get("perc", 0.0)
    var val := (base + add) * mul * (1.0 + perc)
    if ranges.has(key):
        var r = ranges[key]
        val = clamp(val, r.get("min", -INF), r.get("max", INF))
    return val

## Define clamped range for a stat key.
func set_range(key: String, min_value: float, max_value: float) -> void:
    ranges[key] = {"min": min_value, "max": max_value}

func run_tests() -> Dictionary:
    var dummy := Object.new()
    set_base(dummy, "HLTH", 50)
    set_range("HLTH", 0, 100)
    add_modifier(dummy, "HLTH", 25, 1.0, "buff")
    add_modifier(dummy, "HLTH", 0.0, 1.0, "buff2", 0, 0.5)
    var val = get_value(dummy, "HLTH")
    var passed: bool = val == 100.0
    dummy.free()
    return {
        "failed": (0 if passed else 1),
        "total": 1,
        "log": "HLTH clamp %s" % val,
    }
