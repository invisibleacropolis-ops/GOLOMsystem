extends SceneTree

func _init() -> void:
	var T = preload("res://scripts/modules/turn_timespace.gd")
	var BaseActor = preload("res://scripts/core/base_actor.gd")
	var GRID_MAP_RES = preload("res://scripts/grid/grid_map.gd")
	var ts = T.new()
	ts.set_grid_map(GRID_MAP_RES.new())
	var atk = BaseActor.new()
	var dfd = BaseActor.new()
	print("before:", dfd.HLTH)
	ts.add_actor(atk, 10, 2, Vector2i.ZERO)
	ts.add_actor(dfd, 5, 1, Vector2i(1, 0))
	ts.start_round()
	var ok = ts.perform(atk, "attack", dfd)
	print("ok:", ok, " after:", dfd.HLTH)
	quit()

