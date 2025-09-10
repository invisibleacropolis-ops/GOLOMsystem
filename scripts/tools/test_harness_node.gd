extends Node
class_name TestHarnessNode

## In-game test runner that mirrors scripts/test_runner.gd without quitting.
## Aggregates module self-tests and publishes results via WorkspaceDebugger.

func run_all() -> Dictionary:
    var module_paths = {
        "grid_logic": "res://scripts/modules/grid_logic.gd",
        "grid_visual_logic": "res://scripts/modules/grid_visual_logic.gd",
        "grid_map": "res://scripts/grid/grid_map.gd",
        "attributes": "res://scripts/modules/attributes.gd",
        "statuses": "res://scripts/modules/statuses.gd",
        "abilities": "res://scripts/modules/abilities.gd",
        "loadouts": "res://scripts/modules/loadouts.gd",
        "reactions": "res://scripts/modules/reactions.gd",
        "event_bus": "res://scripts/modules/event_bus.gd",
        "procedural_map_generator": "res://scripts/modules/procedural_map_generator.gd",
        "grid_realtime_renderer": "res://scripts/modules/GridRealtimeRenderer.gd",
        "procedural_world": "res://scripts/modules/procedural_world.gd",
        "map_generator": "res://scripts/modules/map_generator.gd",
        "terrain": "res://scripts/modules/terrain.gd",
        "runtime_services": "res://scripts/modules/runtime_services.gd",
        "console_commands": "res://scripts/tools/console_commands.gd",
    }
    var total := 0
    var failed := 0
    var lines: Array[String] = []
    for name in module_paths.keys():
        var path: String = module_paths[name]
        var script := ResourceLoader.load(path, "", ResourceLoader.CacheMode.CACHE_MODE_IGNORE)
        if script == null or not script is Script or not script.can_instantiate():
            lines.append("%s: failed to load" % name)
            continue
        var mod = script.new()
        if mod.has_method("run_tests"):
            var result = mod.run_tests()
            var f = int(result.get("failed", 0))
            var t = int(result.get("total", 0))
            total += t
            failed += f
            var status = "PASS" if f == 0 else "FAIL"
            lines.append("%s: %s (%d/%d)" % [name, status, f, t])
            if result.has("log"):
                lines.append(String(result.log))
        else:
            lines.append("%s: no tests" % name)
        if mod is Node:
            mod.queue_free()
        mod = null
        script = null
    var dbg = get_tree().get_root().get_node_or_null("/root/WorkspaceDebugger")
    var summary = "TOTAL: %d/%d failed" % [failed, total]
    if dbg:
        for ln in lines:
            dbg.log_info(ln)
        if failed > 0:
            dbg.log_error(summary)
        else:
            dbg.log_info(summary)
    return {"failed": failed, "total": total, "lines": lines}
func _ready() -> void:
    # Defer to ensure the tree is stable before running tests.
    call_deferred("run_all")

