extends SceneTree
const GridRealtimeRenderer = preload("res://scripts/modules/GridRealtimeRenderer.gd")

func _init() -> void:
    var r := GridRealtimeRenderer.new()
    r.grid_size = Vector2i(64,64)
    get_root().add_child(r)
    var rng := RandomNumberGenerator.new()
    rng.seed = 12345
    var start := Time.get_ticks_msec()
    for i in 10000:
        var p := Vector2i(rng.randi_range(0,63), rng.randi_range(0,63))
        r.set_cell_color(p, Color.RED)
    var elapsed := Time.get_ticks_msec() - start
    print("GridRealtimeRenderer benchmark: %d ms" % elapsed)
    r.free()
    quit()
