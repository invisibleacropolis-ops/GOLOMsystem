extends Node
class_name TestLoop

## Continuous module test loop that mirrors `test_grid.gd`'s style
## but executes `run_tests()` for every logic module. Results are
## forwarded to the Workspace debugger for engineers to review.
##
## The script instantiates each module, calls `run_tests()`, awaits
## asynchronous sections, and emits a summary after each pass. It
## then repeats on a timer so stability issues surface over time.

signal tests_completed(result: Dictionary)

const MODULE_SCRIPTS := {
    "grid_logic": preload("res://scripts/modules/grid_logic.gd"),
    "grid_visual_logic": preload("res://scripts/modules/grid_visual_logic.gd"),
    "turn_timespace": preload("res://scripts/modules/turn_timespace.gd"),
    "attributes": preload("res://scripts/modules/attributes.gd"),
    "statuses": preload("res://scripts/modules/statuses.gd"),
    "abilities": preload("res://scripts/modules/abilities.gd"),
    "loadouts": preload("res://scripts/modules/loadouts.gd"),
    "reactions": preload("res://scripts/modules/reactions.gd"),
    "event_bus": preload("res://scripts/modules/event_bus.gd"),
    "grid_realtime_renderer": preload("res://scripts/modules/GridRealtimeRenderer.gd"),
    "runtime_services": preload("res://scripts/modules/runtime_services.gd"),
}

@export var interval: float = 2.0
var _timer := Timer.new()
@onready var _debugger = get_node("/root/WorkspaceDebugger")

func _ready() -> void:
    add_child(_timer)
    _timer.wait_time = interval
    _timer.one_shot = true
    _timer.timeout.connect(_on_timeout)
    await _run_all_tests()
    _timer.start()

func _on_timeout() -> void:
    await _run_all_tests()
    _timer.start()

func _run_all_tests() -> Dictionary:
    var total := 0
    var failed := 0
    var logs: Array[String] = []

    for name in MODULE_SCRIPTS.keys():
        var mod = MODULE_SCRIPTS[name].new()
        var result = mod.run_tests() if mod.has_method("run_tests") else null
        if result is Object and result.get_class() == "GDScriptFunctionState":
            result = await result
        if result is Dictionary:
            var f := int(result.get("failed", 0))
            var t := int(result.get("total", 0))
            var status := "PASS" if f == 0 else "FAIL"
            _debugger.log_info("%s: %s (%d/%d)" % [name, status, f, t])
            if result.has("log"):
                _debugger.log_info(str(result.log))
                logs.append("%s:\n%s" % [name, str(result.log)])
            failed += f
            total += t
        else:
            _debugger.log_info("%s: no tests" % name)
        mod.free()

    _debugger.log_info("TOTAL: %d/%d failed" % [failed, total])
    var summary := {"failed": failed, "total": total, "log": "\n\n".join(logs)}
    emit_signal("tests_completed", summary)
    return summary
