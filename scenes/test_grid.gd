extends Node

# Use the path directly so this works even if the global class name isn't parsed yet.
# The new `Grid` facade bundles pathfinding, LOS, and terrain helpers.
const GRID_MAP_RES: GDScript = preload("res://scripts/grid/grid.gd")
const TIMESPACE_RES := preload("res://scripts/modules/turn_timespace.gd")
const BaseActor := preload("res://scripts/core/base_actor.gd")

var grid

# Entry point for workspace‑driven tests. Instantiates the grid and
# returns a summary dictionary after all sections run.
func run_tests() -> Dictionary:
	grid = GRID_MAP_RES.new()
	var hub = get_tree().get_root().get_node_or_null("/root/ErrorHub")
	if hub:
		hub.call_deferred("info", "test_grid", "Starting grid tests", {})
	var result: Dictionary = await _run_all_tests()
	if hub:
		var failed = int(result.get("failed", 0))
		var total = int(result.get("total", 0))
		var level = ("info" if failed == 0 else "error")
		hub.call_deferred(level, "test_grid", "Grid tests complete", result)
	return result

func _ready() -> void:
	await run_tests()

# -------- helpers --------
func _add_actor(name: String, pos: Vector2i, facing := Vector2i.RIGHT, size := Vector2i(1,1)) -> BaseActor:
	var a: BaseActor = BaseActor.new(name, pos, facing, size)
	add_child(a)
	var ok: bool = grid.move_actor(a, pos)
	if not ok:
		push_error("Failed to place actor %s at %s" % [name, pos])
		return null
	return a

func _reset() -> void:
	# DEBUG: This is a safer way to reset. It removes all actor nodes from the
	# scene before clearing the grid's data structures. This prevents crashes.
	for child in get_children():
		if child is BaseActor:
			child.queue_free()

	# Now reset the grid state
	if grid:
		grid.width = 16
		grid.height = 16
		grid.occupied.clear()
		grid.actor_positions.clear()
		grid.movement_costs.clear()
		grid.los_blockers.clear()
		grid.height_levels.clear()
		grid.tile_tags.clear()
                grid.covers.clear()
		if grid.has_method("_clear_path_cache"):
			grid._clear_path_cache()

# -------- Test Runner Logic --------
# REFACTOR: The test runner now expects a Dictionary result for more verbose failure logging.

func _run_all_tests() -> Dictionary:
	var failed_tests := 0
	var total_tests := 0
	var test_results := {}

	# Define all test sections here
	var tests = {
		"Bounds & Occupancy": _test_bounds_and_occupancy,
		"Move & Remove": _test_move_and_remove,
		"Distance": _test_distance,
		"LOS blockers & Line of Sight": _test_los,
		"Actors/Positions in Range": _test_range,
		"Pathfinding (Finds Path)": _test_pathfinding_finds_path,
		"Pathfinding (Is Blocked)": _test_pathfinding_is_blocked,
		"Pathfinding (Height)": _test_pathfinding_height,
		"Pathfinding (Facing Cost)": _test_pathfinding_facing_cost,
		"Tile Tags & Cover": _test_tile_tags_and_cover,
		"Area of Effect Templates": _test_aoe_templates,
		"Creature Size & Placement": _test_creature_size, # NEW
		"Zone of Control (Arcs) & Threats": _test_zoc,
		"Attack Arc Classification": _test_attack_arcs,
		"Flanking": _test_flanking,
		"Edge Cases & Untested Params": _test_edge_cases,
		"Turn-based Timespace": _test_turn_timespace,
	}

	for test_name in tests:
		var test_func = tests[test_name]
		var result: Dictionary = await _run_test_section(test_name, test_func)
		test_results[test_name] = result.passed
		total_tests += 1
		if not result.passed:
			failed_tests += 1

	print("\n\n========== TEST SUMMARY ==========")
	for test_name in test_results:
		var result_text = "✅ PASS" if test_results[test_name] else "❌ FAIL"
		print("- %-35s: %s" % [test_name, result_text])
	print("==================================")
	if failed_tests > 0:
		print("🔴 Finished with %d/%d tests failing." % [failed_tests, total_tests])
	else:
		print("🟢 All %d tests passed successfully!" % total_tests)

	# Exit so command line runs terminate. Use the number of failed tests as
	# the process exit code (0 indicates success).
	get_tree().quit(failed_tests)
	return {"failed": failed_tests, "total": total_tests}


func _run_test_section(title: String, test_callable: Callable) -> Dictionary:
	print("\n--- Testing: %s ---" % title)
	_reset()
	await get_tree().process_frame

	var result: Dictionary = test_callable.call()
	if result.passed:
		print("	 ✅ PASS")
	else:
		print("	 ❌ FAIL")
		print("	   - Details: %s" % result.message) # Verbose output on failure
	return result

# -------- Individual Test Functions --------
# REFACTOR: All test functions now return a Dictionary: {"passed": bool, "message": String}

func _test_bounds_and_occupancy() -> Dictionary:
	var FAILED = func(msg): return {"passed": false, "message": msg}
	var PASSED = {"passed": true, "message": ""}

	if not grid.is_in_bounds(Vector2i(0, 0)): return FAILED.call("is_in_bounds(0,0) should be true.")
	if not grid.is_in_bounds(Vector2i(15, 15)): return FAILED.call("is_in_bounds(15,15) should be true.")
	if grid.is_in_bounds(Vector2i(-1, 0)): return FAILED.call("is_in_bounds(-1,0) should be false.")
	if grid.is_in_bounds(Vector2i(16, 0)): return FAILED.call("is_in_bounds(16,0) should be false.")

	var hero := _add_actor("Hero", Vector2i(2, 3), Vector2i.RIGHT)
	_add_actor("Enemy", Vector2i(7, 6), Vector2i.LEFT)
	_add_actor("Blocker", Vector2i(4, 4), Vector2i.DOWN)

	if not grid.is_occupied(Vector2i(2, 3)): return FAILED.call("is_occupied should be true for (2,3).")
	if not grid.get_actor_at(Vector2i(2, 3)) == hero: return FAILED.call("get_actor_at(2,3) did not return the correct actor.")
	var all_actors = grid.get_all_actors()
	if not all_actors.size() == 3: return FAILED.call("Expected 3 actors, but found %s." % all_actors.size())

	return PASSED

func _test_move_and_remove() -> Dictionary:
	var FAILED = func(msg): return {"passed": false, "message": msg}
	var PASSED = {"passed": true, "message": ""}
	
	var hero := _add_actor("Hero", Vector2i(2, 3))
	var blocker := _add_actor("Blocker", Vector2i(4, 4))
	
	if not grid.move_actor(hero, Vector2i(3, 3)): return FAILED.call("move_actor to (3,3) failed.")
	if grid.is_occupied(Vector2i(2, 3)): return FAILED.call("Original position (2,3) should be empty after move.")
	if not grid.is_occupied(Vector2i(3, 3)): return FAILED.call("New position (3,3) should be occupied after move.")
	if not grid.actor_positions[hero] == Vector2i(3, 3): return FAILED.call("Actor position cache is incorrect after move.")
	if grid.move_actor(hero, Vector2i(4, 4)): return FAILED.call("Move should fail when moving to an occupied tile.")
	
	grid.remove_actor(blocker)
	if grid.is_occupied(Vector2i(4, 4)): return FAILED.call("Tile should be empty after actor removal.")
	if grid.actor_positions.has(blocker): return FAILED.call("Actor should not be in position cache after removal.")
	
	return PASSED

func _test_distance() -> Dictionary:
	var FAILED = func(msg): return {"passed": false, "message": msg}
	var PASSED = {"passed": true, "message": ""}
	
	var dist = grid.get_distance(Vector2i(0, 0), Vector2i(3, 4))
	if not dist == 7: return FAILED.call("Manhattan distance incorrect. Expected 7, got %d." % dist)

	return PASSED

func _test_los() -> Dictionary:
	var FAILED = func(msg): return {"passed": false, "message": msg}
	var PASSED = {"passed": true, "message": ""}
	
	var start_pos = Vector2i(3, 3)
	var end_pos = Vector2i(7, 6)
	var blocker_on_path = Vector2i(5, 5)

	if not grid.has_line_of_sight(start_pos, end_pos): return FAILED.call("Line of sight was unexpectedly blocked at the start.")
	
	grid.set_los_blocker(blocker_on_path, true)
	if not grid.is_los_blocker(blocker_on_path): return FAILED.call("set_los_blocker() did not register the blocker tile.")
	if grid.has_line_of_sight(start_pos, end_pos): return FAILED.call("Line of sight was NOT blocked after adding an obstacle.")

	grid.set_los_blocker(blocker_on_path, false)
	if grid.is_los_blocker(blocker_on_path): return FAILED.call("The blocker was not correctly removed.")
	if not grid.has_line_of_sight(start_pos, end_pos): return FAILED.call("Line of sight was not restored after removing blocker.")

	return PASSED

func _test_range() -> Dictionary:
	var FAILED = func(msg): return {"passed": false, "message": msg}
	var PASSED = {"passed": true, "message": ""}
	
	var hero := _add_actor("Hero", Vector2i(3, 3))
	_add_actor("Enemy", Vector2i(8, 8))
	
	var objects_in_radius: Array[Object] = grid.get_actors_in_radius(Vector2i(3, 3), 3, false)
	if not hero in objects_in_radius: return FAILED.call("Center actor not found in its own radius.")
	if not objects_in_radius.size() == 1: return FAILED.call("Incorrect number of actors in radius. Expected 1, got %d." % objects_in_radius.size())

	var near_tiles: Array[Vector2i] = grid.get_positions_in_range(Vector2i(3, 3), 1, false)
	if not near_tiles.size() == 9: return FAILED.call("Incorrect number of tiles in range. Expected 9, got %d." % near_tiles.size())

	return PASSED

func _test_pathfinding_finds_path() -> Dictionary:
	var FAILED = func(msg): return {"passed": false, "message": msg}
	var PASSED = {"passed": true, "message": ""}
	
	var start_actor = _add_actor("Start", Vector2i(3, 3))
	_add_actor("Goal", Vector2i(7, 6))

	for x in range(4, 8):
		grid.set_movement_cost(Vector2i(x, 5), INF)
	
	var path: Array[Vector2i] = grid.find_path_for_actor(start_actor, start_actor.grid_pos, Vector2i(7, 6))
	if path.is_empty(): return FAILED.call("Path with obstacles not found when one should exist.")
	if not (path.front() == start_actor.grid_pos and path.back() == Vector2i(7, 6)):
		return FAILED.call("Path start/end points are incorrect. Path: %s" % str(path))

	return PASSED

func _test_pathfinding_is_blocked() -> Dictionary:
	var FAILED = func(msg): return {"passed": false, "message": msg}
	var PASSED = {"passed": true, "message": ""}
	
	var start_actor = _add_actor("Start", Vector2i(3, 3))
	_add_actor("Goal", Vector2i(7, 6))

	for y in range(0, 16):
		grid.set_movement_cost(Vector2i(5, y), INF)

	var no_path: Array[Vector2i] = grid.find_path_for_actor(start_actor, start_actor.grid_pos, Vector2i(7, 6))
	if not no_path.is_empty():
		return FAILED.call("A path was found through an impassable wall. Path: %s" % str(no_path))
	
	return PASSED

func _test_pathfinding_height() -> Dictionary:
	var FAILED = func(msg): return {"passed": false, "message": msg}
	var PASSED = {"passed": true, "message": ""}
	
	var start_actor = _add_actor("Start", Vector2i(2, 5))
	var end_pos := Vector2i(8, 5)
	
	for y in range(grid.height):
		grid.set_height(Vector2i(5, y), 2)
	
	var path_wall = grid.find_path_for_actor(start_actor, start_actor.grid_pos, end_pos)
	if not path_wall.is_empty():
		return FAILED.call("Path found over a wall too high to climb. Path: %s" % str(path_wall))
	
	grid.set_height(Vector2i(5, 5), 1)
	
	var path_step = grid.find_path_for_actor(start_actor, start_actor.grid_pos, end_pos)
	if path_step.is_empty(): return FAILED.call("No path found over a step that should be climbable.")
	if not (path_step.front() == start_actor.grid_pos and path_step.back() == end_pos):
		return FAILED.call("Path over step has incorrect start/end points. Path: %s" % str(path_step))
		
	return PASSED

func _test_pathfinding_facing_cost() -> Dictionary:
	var FAILED = func(msg): return {"passed": false, "message": msg}
	var PASSED = {"passed": true, "message": ""}
	
	var start_actor = _add_actor("Start", Vector2i(1, 1))
	var end_pos = Vector2i(4, 1)
	var costly_tile = Vector2i(3, 1)
	
	grid.set_movement_cost(costly_tile, 3.0)
	
	var path_chosen = grid.find_path_for_actor(start_actor, start_actor.grid_pos, end_pos)
	if not costly_tile in path_chosen:
		var msg = "Path avoided the costly tile when it should have been the cheapest option (5.1 vs 5.2). Chosen path: %s" % str(path_chosen)
		return FAILED.call(msg)
		
	grid.set_movement_cost(Vector2i(3, 2), 0.5)
	var original_turn_cost = grid.TURN_COST
	grid.TURN_COST = 0.0
	
	var path_no_turn_cost = grid.find_path_for_actor(start_actor, start_actor.grid_pos, end_pos)
	if costly_tile in path_no_turn_cost:
		var msg = "With zero turn cost, path went through costly tile instead of cheaper detour (4.5 vs 5.0). Chosen path: %s" % str(path_no_turn_cost)
		return FAILED.call(msg)
	
	grid.TURN_COST = original_turn_cost
	return PASSED

func _test_tile_tags_and_cover() -> Dictionary:
	var FAILED = func(msg): return {"passed": false, "message": msg}
	var PASSED = {"passed": true, "message": ""}
	
	var tile = Vector2i(5, 5)
	
	# Test Tags
	grid.add_tile_tag(tile, "grass")
	grid.add_tile_tag(tile, "magic")
	if not grid.has_tile_tag(tile, "grass"): return FAILED.call("Tag 'grass' was not added.")
	if not grid.has_tile_tag(tile, "magic"): return FAILED.call("Tag 'magic' was not added.")
	
	grid.remove_tile_tag(tile, "grass")
	if grid.has_tile_tag(tile, "grass"): return FAILED.call("Tag 'grass' was not removed.")
	if not grid.has_tile_tag(tile, "magic"): return FAILED.call("Tag 'magic' should still exist after removing 'grass'.")
	
        # Test Cover
        grid.set_cover(tile, "half", "west")
        var c = grid.get_cover(tile)
        if c.get("type") != "half" or c.get("direction") != "west":
                return FAILED.call("Cover was not set to 'half' facing 'west'.")

        var los_start = Vector2i(2, 5)
        var los_end = Vector2i(8, 5)

        grid.set_cover(tile, "full", "west")
        c = grid.get_cover(tile)
        if c.get("type") != "full":
                return FAILED.call("Cover was not set to 'full'.")
        if grid.has_line_of_sight(los_start, los_end):
                return FAILED.call("'full' cover facing 'west' should block Line of Sight from the west.")

        grid.set_cover(tile, "half", "west")
        if not grid.has_line_of_sight(los_start, los_end):
                return FAILED.call("'half' cover should not block Line of Sight.")
	
	return PASSED

func _test_aoe_templates() -> Dictionary:
	var FAILED = func(msg): return {"passed": false, "message": msg}
	var PASSED = {"passed": true, "message": ""}
	
	var origin = Vector2i(5, 5)
	
	# Test Burst
	var burst_tiles = grid.get_aoe_tiles("burst", origin, Vector2i.ZERO, 1)
	if burst_tiles.size() != 9: return FAILED.call("Burst AOE with radius 1 should have 9 tiles, got %d." % burst_tiles.size())
	if not origin in burst_tiles: return FAILED.call("Burst AOE did not include the origin tile.")
	
	# Test Line
	var line_tiles = grid.get_aoe_tiles("line", origin, Vector2i.RIGHT, 3)
	var expected_line = [Vector2i(5,5), Vector2i(6,5), Vector2i(7,5)]
	if line_tiles.size() != 3: return FAILED.call("Line AOE should have 3 tiles, got %d." % line_tiles.size())
	for tile in expected_line:
		if not tile in line_tiles: return FAILED.call("Line AOE missing expected tile: %s" % str(tile))
	
	# Test Cone
	var cone_tiles = grid.get_aoe_tiles("cone", origin, Vector2i.UP, 2)
	# Manually calculated expected tiles for a 2-tile cone facing UP
	var expected_cone = [Vector2i(5,4), Vector2i(5,3), Vector2i(4,4), Vector2i(6,4)]
	if cone_tiles.size() != expected_cone.size():
		return FAILED.call("Cone AOE should have %d tiles, got %d. Tiles: %s" % [expected_cone.size(), cone_tiles.size(), str(cone_tiles)])
	for tile in expected_cone:
		if not tile in cone_tiles: return FAILED.call("Cone AOE missing expected tile: %s" % str(tile))

	# Test Wall
	var wall_tiles = grid.get_aoe_tiles("wall", origin, Vector2i.UP, 5)
	# Wall should be perpendicular to UP (i.e., horizontal)
	var expected_wall = [Vector2i(3,5), Vector2i(4,5), Vector2i(5,5), Vector2i(6,5), Vector2i(7,5)]
	if wall_tiles.size() != 5: return FAILED.call("Wall AOE should have 5 tiles, got %d." % wall_tiles.size())
	for tile in expected_wall:
		if not tile in wall_tiles: return FAILED.call("Wall AOE missing expected tile: %s" % str(tile))

	return PASSED

func _test_creature_size() -> Dictionary:
	var FAILED = func(msg): return {"passed": false, "message": msg}
	var PASSED = {"passed": true, "message": ""}
	
	# 1. Test placement and occupancy
	var large_actor = _add_actor("Ogre", Vector2i(2, 2), Vector2i.RIGHT, Vector2i(2, 2))
	if large_actor == null: return FAILED.call("Failed to place large actor.")
	
	var expected_tiles = [Vector2i(2,2), Vector2i(3,2), Vector2i(2,3), Vector2i(3,3)]
	for tile in expected_tiles:
		if not grid.is_occupied(tile): return FAILED.call("Expected tile %s to be occupied by large actor." % str(tile))
		if grid.get_actor_at(tile) != large_actor: return FAILED.call("Tile %s is not occupied by the correct large actor." % str(tile))
	
	# 2. Test failed placement due to obstacle
	var blocker = _add_actor("Pebble", Vector2i(5, 5))
	var move_failed = grid.move_actor(large_actor, Vector2i(4, 4))
	if move_failed: return FAILED.call("Large actor move should have failed due to obstruction, but it succeeded.")
	
	# 3. Test successful move
	var move_succeeded = grid.move_actor(large_actor, Vector2i(7, 7))
	if not move_succeeded: return FAILED.call("Large actor move failed when it should have succeeded.")
	var new_expected_tiles = [Vector2i(7,7), Vector2i(8,7), Vector2i(7,8), Vector2i(8,8)]
	for tile in new_expected_tiles:
		if not grid.is_occupied(tile): return FAILED.call("Large actor did not occupy expected tile %s after moving." % str(tile))
	for tile in expected_tiles:
		if grid.is_occupied(tile): return FAILED.call("Large actor did not vacate old tile %s after moving." % str(tile))

	# 4. Test pathfinding with size
	var path_start_pos = Vector2i(0,5)
	large_actor.set("grid_pos", path_start_pos) # Reset position for pathfinding test
	grid.move_actor(large_actor, path_start_pos)

	for i in range(16):
		if i != 5: # Leave a 1-tile wide gap at (4, 5)
			grid.set_movement_cost(Vector2i(4, i), INF)
			
	var path = grid.find_path_for_actor(large_actor, path_start_pos, Vector2i(6,5))
	if not path.is_empty(): return FAILED.call("Large actor found a path through a 1-tile gap it shouldn't fit through.")

	# 5. Test removal
	grid.remove_actor(large_actor)
	for tile in new_expected_tiles:
		if grid.is_occupied(tile): return FAILED.call("Removing large actor did not clear tile %s." % str(tile))
	
	return PASSED

func _test_zoc() -> Dictionary:
	var FAILED = func(msg): return {"passed": false, "message": msg}
	var PASSED = {"passed": true, "message": ""}
	
	var hero := _add_actor("Hero", Vector2i(3, 3), Vector2i.RIGHT)
	var lefty := _add_actor("Lefty", Vector2i(3, 4))

	if grid.get_zone_of_control(hero, 1, "all").is_empty(): return FAILED.call("ZOC (all) was empty.")
	if grid.get_zone_of_control(hero, 1, "front").is_empty(): return FAILED.call("ZOC (front) was empty.")

	var tiles_under: Array[Vector2i] = grid.get_tiles_under_zoc(1, "all")
	if not Vector2i(3, 4) in tiles_under: return FAILED.call("Lefty's tile (3,4) was not under ZOC.")

	if not grid.actor_in_zoc(lefty, hero): return FAILED.call("actor_in_zoc check failed.")
	
	return PASSED
# #### `_test_attack_arcs()`
# 
# This function rigorously tests the `grid.get_attack_arc` method to ensure it correctly
# classifies an attacker's position relative to a defender's facing direction.
# 
# *   **Logic:**
#     1.  **Setup:** A central "defender" actor, `hero`, is created at coordinate
# `(3, 3)` and is set to be facing right (`Vector2i.RIGHT`). This establishes a clear
# frame of reference.
#     2.  **Test Cases:** Four "attacker" actors are then created, one in each cardinal
# direction relative to the hero:
#	  *   `front_attacker` is placed at `(4, 3)`, which is directly in front of
# the right-facing hero. The test asserts the result of `grid.get_attack_arc(hero,
# front_attacker)` is `"front"`.
#	  *   `left_attacker` is placed at `(3, 4)`. From the hero's perspective,
# this is to its left. The test asserts the result is `"left"`.
#	  *   `right_attacker` is at `(3, 2)`, which is to the hero's right. The test
# asserts the result is `"right"`.
#	  *   `rear_attacker` is at `(2, 3)`, which is directly behind the hero. The
# test asserts the result is `"rear"`.
#     3.  **Outcome:** If any of these assertions fail, the function immediately returns
# a `FAILED` dictionary with a message explaining which specific case was incorrect
# (e.g., `"Attack from (3,4) was not 'left'."`). If all four cases pass, it returns
# a `PASSED` dictionary.

func _test_attack_arcs() -> Dictionary:
	var FAILED = func(msg): return {"passed": false, "message": msg}
	var PASSED = {"passed": true, "message": ""}
	
	var hero := _add_actor("Hero", Vector2i(3, 3), Vector2i.RIGHT)
	
	var front_attacker := _add_actor("Front", Vector2i(4, 3))
	if not grid.get_attack_arc(hero, front_attacker) == "front": return FAILED.call("Attack from (4,3) was not 'front'.")
	
	var left_attacker := _add_actor("Left", Vector2i(3, 4))
	if not grid.get_attack_arc(hero, left_attacker) == "left": return FAILED.call("Attack from (3,4) was not 'left'.")
	
	var right_attacker := _add_actor("Right", Vector2i(3, 2))
	if not grid.get_attack_arc(hero, right_attacker) == "right": return FAILED.call("Attack from (3,2) was not 'right'.")
	
	var rear_attacker := _add_actor("Rear", Vector2i(2, 3))
	if not grid.get_attack_arc(hero, rear_attacker) == "rear": return FAILED.call("Attack from (2,3) was not 'rear'.")
	
	return PASSED
# #### `_test_flanking()`
# 
# This function tests the logic of the `grid.is_flanked` method, verifying that it
# correctly identifies when an actor is threatened from opposite sides and, just as
# importantly, when it is not.
# 
# *   **Logic:**
#     1.  **Setup:** A `hero` actor is placed at `(3, 3)`. Two attackers are then
# placed on directly opposite sides of the hero at `(3, 4)` and `(3, 2)`.
#     2.  **Positive Test Case:** The function first calls `grid.is_flanked(hero)`.
# In this configuration, the hero should be considered flanked, so the test checks
# if this call returns `true`. If not, it fails with the message `"Hero should be flanked."`.
#     3.  **Negative Test Case:** To ensure the logic is not overly aggressive, one
# attacker (`righty`) is removed from the grid using `grid.remove_actor(righty)`.
#     4.  **Verification:** The function calls `grid.is_flanked(hero)` again. With
# only one attacker remaining, the hero should no longer be flanked. The test asserts
# this call returns `false`. If it returns `true`, it fails with the message `"Hero
# should not be flanked after one attacker is removed."`.
#     5.  **Outcome:** The test only passes if both the positive and negative test
# cases succeed.

func _test_flanking() -> Dictionary:
	var FAILED = func(msg): return {"passed": false, "message": msg}
	var PASSED = {"passed": true, "message": ""}
	
	var hero := _add_actor("Hero", Vector2i(3, 3))
	_add_actor("Attacker1", Vector2i(3, 4))
	var righty := _add_actor("Attacker2", Vector2i(3, 2))

	if not grid.is_flanked(hero): return FAILED.call("Hero should be flanked.")
	grid.remove_actor(righty)
	if grid.is_flanked(hero): return FAILED.call("Hero should not be flanked after one attacker is removed.")
	
	return PASSED
# #### `_test_edge_cases()`
# 
# This function serves as a collection of tests for various specific scenarios and
# utility functions that might otherwise be missed. It validates several distinct pieces
# of the grid's logic.
# 
# *   **Logic:**
#     1.  **Distance Calculation:** It first performs a simple sanity check on the
# `grid.get_chebyshev_distance` helper function, ensuring that the distance between
# `(0, 0)` and `(3, 4)` is correctly calculated as `4`.
#     2.  **Line of Sight (LOS):** It tests the `require_los` parameter of the `grid.get_actors_in_radius`
# method.
#	  *   **Setup:** It places a central actor at `(10, 10)`, a `visible_actor`
# at `(11, 11)`, and a `hidden_actor` at `(9, 9)`. Crucially, it then places a line-of-sight
# blocker at `(10, 9)`, which is directly between the central actor and the hidden
# one.
#	  *   **Verification:** It queries for actors within a radius of 2, requiring
# a clear line of sight. It then asserts two conditions: the `visible_actor` must be
# present in the results, and the `hidden_actor` must *not* be. This confirms the LOS
# blocking is working as intended.
#     3.  **Diagonal Attack Arc:** It tests a nuance of the `get_attack_arc` function.
#	  *   **Setup:** It places a `hero` at `(3, 3)` facing right and a `diag_attacker`
# at `(4, 4)`. This position is on the diagonal but still within the 45-degree cone
# that should be considered "front."
#	  *   **Verification:** It asserts that `grid.get_attack_arc` correctly classifies
# this diagonal attack as `"front"`.

func _test_edge_cases() -> Dictionary:
	var FAILED = func(msg): return {"passed": false, "message": msg}
	var PASSED = {"passed": true, "message": ""}
	
	if not grid.get_chebyshev_distance(Vector2i(0, 0), Vector2i(3, 4)) == 4: return FAILED.call("Chebyshev distance incorrect.")

	_add_actor("Center", Vector2i(10, 10))
	var visible_actor := _add_actor("Visible", Vector2i(11, 11))
	var hidden_actor := _add_actor("Hidden", Vector2i(9, 9))
	grid.set_los_blocker(Vector2i(10, 9), true)

	var los_actors_result: Array[Object] = grid.get_actors_in_radius(Vector2i(10, 10), 2, true)
	if not visible_actor in los_actors_result: return FAILED.call("Visible actor was not found in LOS radius check.")
	if hidden_actor in los_actors_result: return FAILED.call("Hidden actor was found in LOS radius check.")

	var hero := _add_actor("Hero", Vector2i(3, 3), Vector2i.RIGHT)
	var diag_attacker := _add_actor("Diagonal", Vector2i(4, 4))
	if not grid.get_attack_arc(hero, diag_attacker) == "front": return FAILED.call("Diagonal attack arc was not 'front'.")
	
	return PASSED

func _test_turn_timespace() -> Dictionary:
	var FAILED = func(msg): return {"passed": false, "message": msg}
	var PASSED = {"passed": true, "message": ""}
	var grid_map: Resource = GRID_MAP_RES.new()
	var ts := TIMESPACE_RES.new()
	ts.set_grid_map(grid_map)

	var a: BaseActor = BaseActor.new("A")
	var b: BaseActor = BaseActor.new("B")
	var obj := Node.new()

	var cleanup = func() -> void:
		a.queue_free()
		b.queue_free()
		obj.queue_free()
		ts.queue_free()

	ts.add_actor(a, 10, 2, Vector2i.ZERO)
	ts.add_actor(b, 5, 3, Vector2i(1, 0))
	ts.add_object(obj, Vector2i(2, 0))
	ts.start_round()

	if ts.get_current_actor() != a:
		cleanup.call()
		return FAILED.call("Actor A should act first")

	if not ts.move_current_actor(Vector2i(0, 1)):
		cleanup.call()
		return FAILED.call("Actor A failed to move")
	if grid_map.get_actor_at(Vector2i(0, 1)) != a:
		cleanup.call()
		return FAILED.call("Grid map did not update actor position")
	if ts.get_action_points(a) != 1:
		cleanup.call()
		return FAILED.call("Actor A should have 1 AP remaining")

	ts.end_turn()
	if ts.get_current_actor() != b:
		cleanup.call()
		return FAILED.call("Actor B should act second")

	ts.apply_status_to_actor(a, "stunned")
	if "stunned" not in ts.get_statuses_for_actor(a):
		cleanup.call()
		return FAILED.call("Actor status not recorded")

	ts.apply_status_to_tile(Vector2i(1,1), "fire")
	if "fire" not in ts.get_statuses_for_tile(Vector2i(1,1)):
		cleanup.call()
		return FAILED.call("Tile status not recorded")

	if obj not in ts.get_objects():
		cleanup.call()
		return FAILED.call("Object tracking failed")

	cleanup.call()
	return PASSED
