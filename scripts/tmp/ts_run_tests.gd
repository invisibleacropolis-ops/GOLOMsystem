extends SceneTree

func _init() -> void:
	var T = preload("res://scripts/modules/turn_timespace.gd")
	var ts = T.new()
	var res: Dictionary = ts.run_tests()
	print("ts failed:", res.get("failed"), " total:", res.get("total"), " log:\n", res.get("log"))
	quit()

