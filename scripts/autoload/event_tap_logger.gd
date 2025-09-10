@tool
extends Node

## EventTapLogger: lightweight, always-on log tap that mirrors the
## EventBus feed to a persistent text log on disk at low overhead.
##
## Writes: user://event_feed.log (appends in batches every 2 seconds)

@export var flush_interval_sec := 2.0

var _services
var _event_bus
var _humanizer
var _buffer: Array[String] = []
var _timer: Timer
const USER_LOG_PATH := "user://event_feed.log"

func _ready() -> void:
    _touch_user_file()
    _append_line("--- EventTap initialized (awaiting EventBus) ---")
    _timer = Timer.new()
    _timer.one_shot = false
    _timer.wait_time = max(0.25, float(flush_interval_sec))
    add_child(_timer)
    _timer.timeout.connect(_flush)
    _timer.start()
    call_deferred("_connect_bus")

func _connect_bus() -> void:
    _services = _find_services()
    if _services == null:
        _log("EventTap: RuntimeServices not found yet; will retry")
        return
    _event_bus = _services.get("event_bus") if _services else null
    if _event_bus and _event_bus.has_signal("event_pushed"):
        _event_bus.event_pushed.connect(_on_event)
        _humanizer = preload("res://scripts/humanize/humanizer.gd").new(_services, OS.get_environment("HUMANIZER_PROVIDER"))
        _log("EventTap: connected to EventBus")
        _append_line("--- EventTap session started ---")
    else:
        _log("EventTap: EventBus not available; will retry")

func _process(_dt: float) -> void:
    if _event_bus == null:
        _connect_bus()

func _on_event(evt: Dictionary) -> void:
    var line := ""
    if _humanizer:
        line = _humanizer.humanize_event(evt)
    if line == null or line == "":
        line = _fallback_format(evt)
    _append_line(line)

func _append_line(line: String) -> void:
    var stamp := Time.get_time_string_from_system()
    _buffer.append("[%s] %s" % [stamp, line])

func _flush() -> void:
    if _buffer.is_empty():
        return
    var fa2 = FileAccess.open(USER_LOG_PATH, FileAccess.READ_WRITE)
    if fa2:
        fa2.seek_end()
        for l2 in _buffer:
            fa2.store_line(l2)
        fa2.flush()
        fa2.close()
    else:
        var fa3 = FileAccess.open(USER_LOG_PATH, FileAccess.WRITE)
        if fa3:
            for l3 in _buffer:
                fa3.store_line(l3)
            fa3.flush()
            fa3.close()
    _buffer.clear()

func _touch_user_file() -> void:
    var fa = FileAccess.open(USER_LOG_PATH, FileAccess.WRITE)
    if fa:
        fa.close()

func _fallback_format(evt: Dictionary) -> String:
    var t := String(evt.get("t","event"))
    match t:
        "turn_start":
            return "▶ %s begins turn" % _actor_name(evt.get("actor"))
        "turn_end":
            return "⏹ %s ends turn" % _actor_name(evt.get("actor"))
        "ap":
            var d: Dictionary = evt.get("data", {})
            return "AP %s: %s → %s" % [_actor_name(evt.get("actor")), str(d.get("old","?")), str(d.get("new","?"))]
        "action":
            var d2: Dictionary = evt.get("data", {})
            var id := String(d2.get("id","?"))
            var p = d2.get("payload")
            if id == "move":
                return "%s moves to %s" % [_actor_name(evt.get("actor")), str(p)]
            elif id == "attack":
                return "%s attacks %s" % [_actor_name(evt.get("actor")), _actor_name(p)]
            elif id == "overwatch":
                return "%s enters overwatch" % _actor_name(evt.get("actor"))
            else:
                return "%s uses %s %s" % [_actor_name(evt.get("actor")), id, ("with "+str(p) if p != null else "")]
        "damage":
            var d3: Dictionary = evt.get("data", {})
            return "%s hits %s for %s" % [_actor_name(evt.get("actor")), _actor_name(d3.get("defender")), str(int(d3.get("amount",0)))]
        _:
            return t

func _actor_name(a) -> String:
    if a and a.has_method("get"):
        var n = a.get("name")
        if n != null and String(n) != "":
            return String(n)
    return "Actor"

func _find_services():
    var root = get_tree().get_root()
    # Try common path first
    var node = root.get_node_or_null("/root/VerticalSlice/Runtime")
    if node: return node
    # Deep search
    return _find_by_class(root, "RuntimeServices")

func _find_by_class(n: Node, cname: String):
    if n == null:
        return null
    for c in n.get_children():
        if c.get_class() == cname or c.is_class(cname):
            return c
        var found = _find_by_class(c, cname)
        if found:
            return found
    return null

func _log(msg: String) -> void:
    var dbg = get_tree().get_root().get_node_or_null("/root/WorkspaceDebugger")
    if dbg and dbg.has_method("log_info"):
        dbg.log_info("[EventTap] %s" % msg)
