extends SceneTree

func _init() -> void:
	var RS = preload("res://scripts/modules/runtime_services.gd")
	var rs = RS.new()
	var res: Dictionary = rs.run_tests()
	print("rs failed:", res.get("failed"), " total:", res.get("total"), " log:\n", res.get("log"))
	quit()

