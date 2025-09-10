extends SceneTree

const LogicGridMap = preload("res://scripts/grid/grid_map.gd")
const GridVisualLogic = preload("res://scripts/modules/grid_visual_logic.gd")

## Simple harness that instantiates GridVisualLogic and exercises basic drawing paths.
func _init() -> void:
    var map := LogicGridMap.new()
    map.width = 2
    map.height = 2
    var vis := GridVisualLogic.new()
    vis.set_grid_map(map)
    vis.set_cell_state(Vector2i(0,0), Color.BLUE)
    vis.set_cell_state(Vector2i(1,1), func(canvas, rect): canvas.draw_circle(rect.position + rect.size/2, rect.size.x/2, Color.YELLOW))
    print("GridVisualLogic tester executed")
    # Explicitly free instantiated nodes to prevent CanvasItem leaks in tests
    vis.free()
    map = null
    quit()
