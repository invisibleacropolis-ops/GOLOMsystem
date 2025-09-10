extends Node

signal entry_added(entry: Dictionary)

@export var ring_size := 500
var _entries: Array[Dictionary] = []

func _ready() -> void:
    # Try to subscribe to WorkspaceDebugger if present
    var dbg = get_tree().root.get_node_or_null("/root/WorkspaceDebugger")
    if dbg and dbg.has_signal("log_emitted"):
        dbg.log_emitted.connect(func(msg: String, level: String):
            _append({"when": Time.get_datetime_string_from_system(), "level": level, "ctx": "Workspace", "msg": msg}) )

func _append(e: Dictionary) -> void:
    _entries.append(e)
    while _entries.size() > max(1, ring_size):
        _entries.remove_at(0)
    entry_added.emit(e)

func _report(level: String, ctx: String, msg: String, data := {}) -> void:
    var e = {"when": Time.get_datetime_string_from_system(), "level": level, "ctx": ctx, "msg": msg, "data": data}
    _append(e)

func info(ctx: String, msg: String, data := {}) -> void: _report("info", ctx, msg, data)
func warn(ctx: String, msg: String, data := {}) -> void: _report("warn", ctx, msg, data)
func error(ctx: String, msg: String, data := {}) -> void: _report("error", ctx, msg, data)
func exception(ctx: String, data := {}) -> void: _report("error", ctx, "exception", data)

func get_entries(max_count := 200, level_filter := []) -> Array:
    var out: Array = []
    var n = _entries.size()
    for i in range(n - 1, -1, -1):
        if out.size() >= max(1, max_count):
            break
        var e: Dictionary = _entries[i]
        if level_filter is Array and level_filter.size() > 0 and not level_filter.has(e.get("level")):
            continue
        out.append(e)
    out.reverse()
    return out

func export_to_file(path := "user://error_snapshot.log") -> String:
    var f = FileAccess.open(path, FileAccess.WRITE)
    if f == null:
        return ""
    for e in _entries:
        var line = "[%s] %s %s: %s" % [String(e.get("when","")), String(e.get("level","INFO")).to_upper(), String(e.get("ctx","")), String(e.get("msg",""))]
        var data = e.get("data")
        if data != null:
            line += " " + JSON.stringify(data)
        f.store_line(line)
    f.close()
    return path
