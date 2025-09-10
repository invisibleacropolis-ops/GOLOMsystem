extends Node

## Live ASCII gateway that exposes RuntimeServices + GridRealtimeRenderer
## to ASCII tools (console/server/tests) and to the GUI itself.

var runtime
var renderer
var _actors: Dictionary = {}  ## name -> Node

func _ready() -> void:
    runtime = _find_runtime()
    if runtime == null:
        runtime = preload("res://scripts/modules/runtime_services.gd").new()
        runtime.name = "RuntimeServices"
        get_tree().get_root().call_deferred("add_child", runtime)
    renderer = _find_renderer()
    if renderer == null:
        renderer = preload("res://scripts/modules/GridRealtimeRenderer.gd").new()
        renderer.name = "GridRealtimeRenderer"
        # Ensure the 2D overlay is disabled by default; ASCII remains active.
        renderer.visible = false
        get_tree().get_root().call_deferred("add_child", renderer)
        var gm = runtime.grid_map
        if gm and gm.width > 0 and gm.height > 0:
            renderer.set_grid_size(gm.width, gm.height)
    if renderer and runtime and runtime.grid_map:
        renderer.set_grid_map(runtime.grid_map)
    _maybe_load_profile()
    # Avoid scheduling duplicate add_child on renderer

func _find_runtime():
    for n in get_tree().get_root().get_children():
        if n.get_class() == "RuntimeServices" or n.is_class("RuntimeServices"):
            return n
    # Deep search
    return _find_by_type(get_tree().get_root(), "RuntimeServices")

func _find_renderer():
    for n in get_tree().get_root().get_children():
        if n.get_class() == "GridRealtimeRenderer" or n.is_class("GridRealtimeRenderer"):
            return n
    return _find_by_type(get_tree().get_root(), "GridRealtimeRenderer")

func _find_by_type(root: Node, type_name: String) -> Node:
    if root == null:
        return null
    for c in root.get_children():
        if c.get_class() == type_name or c.is_class(type_name):
            return c
        var found = _find_by_type(c, type_name)
        if found:
            return found
    return null

# ---------------------------------------------------------------------------
# Snapshots & input
func snapshot() -> String:
    if renderer:
        return renderer.get_ascii_frame()
    return ""

func apply_input(p: Vector2i, action: String) -> void:
    if renderer:
        renderer.update_input(p, action)

# ---------------------------------------------------------------------------
# Actor ops
func spawn(name: String, pos: Vector2i) -> void:
    var BaseActor = preload("res://scripts/core/base_actor.gd")
    var a = BaseActor.new(name, pos)
    a.add_to_group("actors")
    _actors[name] = a
    get_tree().get_root().add_child(a)
    runtime.timespace.add_actor(a, 10, 2, pos)
    # Avoid preloading the timespace script here to keep autoload robust in headless/CI.
    # Consider the timespace "idle" if no current actor exists.
    if runtime.timespace and runtime.timespace.get_current_actor() == null:
        runtime.timespace.start_round()

func move_actor(name: String, pos: Vector2i) -> void:
    var a = _actors.get(name)
    if a:
        runtime.timespace.perform(a, "move", pos)

func perform(name: String, id: String, payload) -> void:
    var a = _actors.get(name)
    if a:
        runtime.timespace.perform(a, id, payload)

func remove(name: String) -> void:
    var a = _actors.get(name)
    if a:
        runtime.timespace.remove_actor(a)
        _actors.erase(name)
        a.queue_free()

func list() -> String:
    var out := []
    for n in _actors.keys():
        var a = _actors[n]
        out.append("%s at %s" % [n, a.grid_pos])
    return "\n".join(out)

# ---------------------------------------------------------------------------
# Cleanup to reduce exit-time leak warnings in headless runs
func cleanup() -> void:
    # Remove and free any actors we spawned
    for n in _actors.keys():
        var a = _actors[n]
        if a:
            if runtime and runtime.timespace:
                runtime.timespace.remove_actor(a)
            a.queue_free()
    _actors.clear()
    # Free renderer/runtime instances we attached under root
    if renderer:
        renderer.queue_free()
        renderer = null
    if runtime:
        runtime.queue_free()
        runtime = null

# ---------------------------------------------------------------------------
# Configuration helpers usable from console/server
func set_symbol_map(map: Dictionary) -> void:
    if renderer and typeof(map) == TYPE_DICTIONARY:
        renderer.set_symbol_map(map)

func set_terrain_symbol_map(map: Dictionary) -> void:
    if renderer and typeof(map) == TYPE_DICTIONARY:
        renderer.set_terrain_symbol_map(map)

func load_profile(path: String, key: String = "default") -> bool:
    var map := _load_symbol_profile(path, key)
    if map and typeof(map) == TYPE_DICTIONARY and not map.is_empty():
        set_symbol_map(map)
        return true
    return false

# ---------------------------------------------------------------------------
# Command parser for console/server
func exec(line: String) -> String:
    var parts := line.split(" ")
    if parts.is_empty():
        return ""
    match parts[0]:
        "spawn":
            if parts.size() >= 4:
                spawn(parts[1], Vector2i(parts[2].to_int(), parts[3].to_int()))
        "move_actor":
            if parts.size() >= 4:
                move_actor(parts[1], Vector2i(parts[2].to_int(), parts[3].to_int()))
        "action":
            if parts.size() >= 5:
                perform(parts[1], parts[2], Vector2i(parts[3].to_int(), parts[4].to_int()))
            elif parts.size() >= 3:
                perform(parts[1], parts[2], null)
        "remove":
            if parts.size() >= 2:
                remove(parts[1])
        "end_turn":
            runtime.timespace.end_turn()
        "select", "move", "target", "click":
            if parts.size() >= 3:
                apply_input(Vector2i(parts[1].to_int(), parts[2].to_int()), parts[0])
        "clear":
            apply_input(Vector2i.ZERO, "clear")
        _:
            pass
    return snapshot()

func _maybe_load_profile() -> void:
    var path = "res://data/ascii_profiles.json"
    if not FileAccess.file_exists(path):
        return
    var f = FileAccess.open(path, FileAccess.READ)
    if f == null:
        return
    var txt = f.get_as_text()
    f.close()
    var data = JSON.parse_string(txt)
    if typeof(data) != TYPE_DICTIONARY:
        return
    var prof = data.get("default", {})
    if renderer and typeof(prof) == TYPE_DICTIONARY:
        renderer.set_symbol_map(_normalize_profile_map(prof))

func _load_symbol_profile(path: String, key: String = "default") -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var f = FileAccess.open(path, FileAccess.READ)
    if f == null:
        return {}
    var txt = f.get_as_text()
    f.close()
    var data = JSON.parse_string(txt)
    if typeof(data) != TYPE_DICTIONARY:
        return {}
    var prof = data.get(key, {})
    return _normalize_profile_map(prof)

func _normalize_profile_map(prof: Dictionary) -> Dictionary:
    var smap: Dictionary = {}
    for k in prof.keys():
        var e = prof[k]
        if typeof(e) == TYPE_DICTIONARY:
            var c = e.get("color", null)
            if c is Array and c.size() >= 4:
                e["color"] = Color(c[0], c[1], c[2], c[3])
            smap[k] = e
    return smap
