extends Node

## Headless smoke test that ensures the VerticalSlice scene instantiates
## correctly and contains the expected core nodes.
##
## The test loads the main demo scene, verifies a `BattleController`
## exists, and frees the scene before returning results so it works in
## batch test environments.
func run_tests() -> Dictionary:
    var slice_res := load("res://scenes/VerticalSlice.tscn")
    var passed := slice_res is PackedScene
    var log := ""
    if passed:
        var slice: Node = slice_res.instantiate()
        passed = slice.get_node_or_null("BattleController") != null
        log = "BattleController present" if passed else "BattleController missing"
        slice.free()
    else:
        log = "Failed to load VerticalSlice.tscn"
    return {
        "failed": (0 if passed else 1),
        "total": 1,
        "log": log,
    }
