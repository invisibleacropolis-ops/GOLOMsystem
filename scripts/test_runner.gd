extends SceneTree

## Simple headless test runner that invokes each module's
## `run_tests()` function and reports failures to stdout.


func _init() -> void:
    var hub = get_root().get_node_or_null("/root/ErrorHub")
    if hub:
        hub.call_deferred("info", "test_runner", "Starting module tests", {})
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
    for name in module_paths.keys():
        var path: String = module_paths[name]
        var script := ResourceLoader.load(path, "", ResourceLoader.CacheMode.CACHE_MODE_IGNORE)
        if script == null or not script is Script or not script.can_instantiate():
            print("%s: failed to load" % name)
            if hub:
                hub.call_deferred("error", "test_runner", "%s: failed to load" % name, {})
            continue
        var mod = script.new()
        if mod.has_method("run_tests"):
            var result = mod.run_tests()
            var f = int(result.get("failed", 0))
            var t = int(result.get("total", 0))
            total += t
            failed += f
            var status = "PASS" if f == 0 else "FAIL"
            print("%s: %s (%d/%d)" % [name, status, f, t])
            if result.has("log"):
                print(result.log)
            if hub:
                var level = ("info" if f == 0 else "error")
                hub.call_deferred(level, "test_runner", "%s: %s (%d/%d)" % [name, status, f, t], result)
        else:
            print("%s: no tests" % name)
            if hub:
                hub.call_deferred("warn", "test_runner", "%s: no tests" % name, {})
        # Ensure we clean up the module instance and release the script resource
        if mod is Node:
            mod.free()
        mod = null
        script = null
    var summary = "TOTAL: %d/%d failed" % [failed, total]
    print(summary)
    if hub:
        var level2 = ("info" if failed == 0 else "error")
        hub.call_deferred(level2, "test_runner", summary, {"failed": failed, "total": total})
    quit(failed)
