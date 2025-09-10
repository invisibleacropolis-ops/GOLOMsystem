extends SceneTree

func _init() -> void:
	var T = preload("res://scripts/modules/turn_timespace.gd")
	var GRID_MAP_RES = preload("res://scripts/grid/grid_map.gd")
	var ts = T.new()
	var grid = GRID_MAP_RES.new()
	ts.set_grid_map(grid)
	var A = Node.new()
	var D = Node.new()
	ts.add_actor(A, 10, 2, Vector2i.ZERO)
	ts.add_actor(D, 5, 1, Vector2i(3, 0))
	grid.set_los_blocker(Vector2i(1, 0), true)
	ts.start_round()
	var blocked = not ts.perform(A, "attack", D)
	grid.set_los_blocker(Vector2i(1, 0), false)
	var success = ts.perform(A, "attack", D)
	print("blocked:", blocked, " success:", success)
	quit()

