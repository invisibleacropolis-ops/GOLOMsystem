extends SceneTree

func _init() -> void:
	var T = preload("res://scripts/modules/turn_timespace.gd")
	var GRID_MAP_RES = preload("res://scripts/grid/grid_map.gd")
	var BaseActor = preload("res://scripts/core/base_actor.gd")
	var ts = T.new()
	ts.set_grid_map(GRID_MAP_RES.new())
	var atk = BaseActor.new()
	var dfd = BaseActor.new()
	atk.set_meta("ACC", 200)
	ts.add_actor(atk, 10, 1, Vector2i.ZERO)
	ts.add_actor(dfd, 5, 1, Vector2i(1, 0))
	ts.start_round()
	var hp_before: int = dfd.HLTH
	var hit_ok: bool = ts.perform(atk, "attack", dfd)
	var hp_after: int = dfd.HLTH
	print("hit_ok:", hit_ok, " before:", hp_before, " after:", hp_after)
	quit()
