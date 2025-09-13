extends Node2D

@onready var vis: GridRealtimeRenderer = $GridRealtimeRenderer

func _ready():
    vis.set_grid_size(32, 18)
    for y in 18:
        for x in 32:
            var p := Vector2i(x, y)
            var c := (Vector2(x, y) - Vector2(16, 9)).length()
            vis.set_visibility(p, stepify(clamp(1.0 - c / 10.0, 0.0, 1.0), 0.01))
    for y in 18:
        for x in 32:
            var p := Vector2i(x, y)
            vis.set_channel_value("demo", p, float(x + y))
    vis.apply_heatmap_auto("demo")
