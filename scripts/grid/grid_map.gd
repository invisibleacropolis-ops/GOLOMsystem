## A Resource that manages the state and logic for a tactical grid-based map.
##
## This class is responsible for tracking actor positions, calculating paths,
## determining line of sight, and handling various tactical queries like
## zone of control and flanking. It is designed to be a pure data and logic
## container, independent of any visual representation.
extends Resource
class_name LogicGridMap

#region Class Properties
## The width of the grid in number of cells.
var width: int = 16
## The height of the grid in number of cells.
var height: int = 16

## The primary data structure for actor positions. Maps a grid coordinate (Vector2i)
## to the Object (actor) occupying that cell. For multi-tile actors, every
## tile they occupy will point to the same actor instance.
var occupied: Dictionary = {}
## A reverse lookup dictionary for performance. Maps an Object (actor) instance
## to its current grid coordinate (Vector2i). This position represents the
## actor's origin (typically the top-left tile).
var actor_positions: Dictionary = {}
## Stores movement cost overrides for specific tiles. The key is the tile's
## coordinate (Vector2i), and the value is its movement cost (float). Tiles not
## present in this dictionary have a default cost of 1.0. Use INF for impassable terrain.
var movement_costs: Dictionary = {}
## Stores tiles that are designated as blocking line of sight, even if unoccupied.
## The key is the tile's coordinate (Vector2i), and the value is `true`.
var los_blockers: Dictionary = {}
## Stores the height level of each tile. Default is 0.
var height_levels: Dictionary = {}
## Stores an array of string tags for each tile (e.g., "grass", "building").
var tile_tags: Dictionary = {}
## Stores cover type ("half" or "full") for each tile.
var cover_types: Dictionary = {}
# Stores non-error events for later inspection.
const Logging = preload("res://scripts/core/logging.gd")
const BaseActor = preload("res://scripts/core/base_actor.gd")
var event_log: Array = []
## Cache of recent pathfinding queries keyed by start, goal, and size.
var _path_cache: Dictionary = {}
## Stores directional obstacles that block movement. The key is the tile's
## coordinate and the value is an orientation: `0` = North, `1` = East,
## `2` = South, `3` = West.
var obstacles: Dictionary = {}
## When `true`, actors may move diagonally; when `false` movement is limited to
## orthogonal directions.
var diagonal_movement: bool = true
## Neighbor offsets used for pathfinding. This array is rebuilt whenever
## `diagonal_movement` changes.
var neighbor_offsets: Array[Vector2i] = []
#endregion

#region Cost & Height Constants
## The maximum height difference a unit can climb in a single step.
const MAX_CLIMB_HEIGHT := 1
## The additional movement cost incurred for each level of height climbed.
const CLIMB_COST: float = 2.0
## The additional movement cost incurred when an actor makes a turn.
var TURN_COST: float = 0.7
#endregion


## Append a structured event to the module's event log.
func log_event(t: String, actor: Object = null, pos = null, data = null) -> void:
	Logging.log(event_log, t, actor, pos, data)


func _clear_path_cache() -> void:
	_path_cache.clear()


## Rebuilds the neighbor offset list based on the current diagonal movement setting.
func _update_neighbor_offsets() -> void:
	neighbor_offsets = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	if diagonal_movement:
		neighbor_offsets += [Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]


func _init() -> void:
	_update_neighbor_offsets()


## Enable or disable diagonal movement. Rebuilds neighbor offsets and clears
## cached paths so future queries respect the new configuration.
func set_diagonal_movement(enable: bool) -> void:
	diagonal_movement = enable
	_update_neighbor_offsets()
	_clear_path_cache()


#region Obstacle Handling
## Adds or updates a directional obstacle at the given position.
## @param pos The tile coordinate for the obstacle.
## @param orientation The facing of the obstacle: 0=N, 1=E, 2=S, 3=W.
func place_obstacle(pos: Vector2i, orientation: int) -> void:
	obstacles[pos] = orientation
	_clear_path_cache()


## Removes any obstacle data from the given tile.
func remove_obstacle(pos: Vector2i) -> void:
	if obstacles.erase(pos):
		_clear_path_cache()


## Checks if movement between two adjacent tiles is blocked by directional obstacles.
## @param from_pos Starting tile.
## @param to_pos Destination tile. Must be orthogonally adjacent to `from_pos`.
func is_movement_blocked(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	if abs(from_pos.x - to_pos.x) + abs(from_pos.y - to_pos.y) != 1:
		return false
	var orientation = obstacles.get(from_pos, null)
	if orientation != null:
		if to_pos.y < from_pos.y and orientation == 0:
			return true
		if to_pos.x > from_pos.x and orientation == 1:
			return true
		if to_pos.y > from_pos.y and orientation == 2:
			return true
		if to_pos.x < from_pos.x and orientation == 3:
			return true
	orientation = obstacles.get(to_pos, null)
	if orientation != null:
		if from_pos.y < to_pos.y and orientation == 0:
			return true
		if from_pos.x > to_pos.x and orientation == 1:
			return true
		if from_pos.y > to_pos.y and orientation == 2:
			return true
		if from_pos.x < to_pos.x and orientation == 3:
			return true
	return false


## Determines if any path between two tiles is blocked by obstacles.
## Handles diagonal movement by requiring at least one orthogonal path to be clear.
func is_blocked_by_obstacle(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	if abs(from_pos.x - to_pos.x) + abs(from_pos.y - to_pos.y) == 1:
		return is_movement_blocked(from_pos, to_pos)
	if abs(from_pos.x - to_pos.x) == 1 and abs(from_pos.y - to_pos.y) == 1:
		var mid1 = Vector2i(to_pos.x, from_pos.y)
		var mid2 = Vector2i(from_pos.x, to_pos.y)
		var path1_blocked = is_movement_blocked(from_pos, mid1) or is_movement_blocked(mid1, to_pos)
		var path2_blocked = is_movement_blocked(from_pos, mid2) or is_movement_blocked(mid2, to_pos)
		return path1_blocked and path2_blocked
	var current = from_pos
	while current != to_pos:
		var step = Vector2i(sign(to_pos.x - current.x), sign(to_pos.y - current.y))
		var next = current + step
		if is_movement_blocked(current, next):
			return true
		current = next
	return false


#endregion

#region Core Grid Functions


## Checks if a given grid coordinate is within the defined map boundaries.
## @param pos The Vector2i coordinate to check.
## @return `true` if the position is within bounds, otherwise `false`.
func is_in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.y >= 0 and pos.x < width and pos.y < height


## Checks if a given grid coordinate is currently occupied by an actor.
## @param pos The Vector2i coordinate to check.
## @return `true` if the cell is occupied, otherwise `false`.
func is_occupied(pos: Vector2i) -> bool:
	return occupied.has(pos)


## Moves an actor to a new coordinate, updating all internal state.
## This function correctly handles multi-tile actors, ensuring all tiles
## are checked for validity before moving, and that all old tiles are
## vacated and all new tiles are occupied.
## @param actor The actor object to move. Must have `grid_pos` and `size` properties.
## @param to The target Vector2i coordinate for the actor's origin (top-left).
## @return `true` if the move was successful, otherwise `false`.
func move_actor(actor: Object, to: Vector2i) -> bool:
	_clear_path_cache()
	var actor_size = actor.get("size") if "size" in actor else Vector2i(1, 1)

	# Check if the destination is valid for the entire footprint of the actor.
	var new_tiles = get_tiles_for_footprint(to, actor_size)
	for tile in new_tiles:
		if not is_in_bounds(tile):
			return false  # Part of the actor would be out of bounds.
		if is_occupied(tile) and get_actor_at(tile) != actor:
			return false  # Destination is blocked by another actor.

		# Clear the actor's previous position(s), if it had one.

		# Set the new position in both lookup dictionaries and occupy all new tiles.

		# Update the actor's internal state as well.
	if actor_positions.has(actor):
		var old_tiles = get_occupied_tiles(actor)
		for tile in old_tiles:
			occupied.erase(tile)

		# Set the new position in both lookup dictionaries and occupy all new tiles.

		# Update the actor's internal state as well.
	for tile in new_tiles:
		occupied[tile] = actor

		# Update the actor's internal state as well.
	actor_positions[actor] = to

	# Update the actor's internal state as well.
	if actor.has_method("set"):
		actor.set("grid_pos", to)
	return true


## Removes an actor completely from the grid, vacating all tiles it occupies.
## @param actor The actor object to remove.
func remove_actor(actor: Object) -> void:
	if actor_positions.has(actor):
		_clear_path_cache()
		var tiles_to_clear = get_occupied_tiles(actor)
		for tile in tiles_to_clear:
			occupied.erase(tile)
		actor_positions.erase(actor)


## Retrieves the actor at a specific grid coordinate.
## @param pos The Vector2i coordinate to query.
## @return The actor Object at the position, or `null` if the cell is empty.
func get_actor_at(pos: Vector2i) -> Object:
	return occupied.get(pos, null)


## Retrieves a list of all unique actors currently on the grid.
## @return An `Array[Object]` containing all actors.
func get_all_actors() -> Array[Object]:
	var unique_actors = {}
	for actor in occupied.values():
		unique_actors[actor] = true
		# FIX: Explicitly create a typed array to match the function signature.
	var result: Array[Object] = []
	for actor in unique_actors.keys():
		result.append(actor)
	return result


## Calculates all tiles occupied by an actor based on its position and size.
## @param actor The actor object. Must have `grid_pos` and `size` properties.
## @return An `Array[Vector2i]` of all tiles the actor currently occupies.
func get_occupied_tiles(actor: Object) -> Array[Vector2i]:
	if not actor_positions.has(actor):
		return []
	var origin = actor_positions[actor]
	var size = actor.get("size") if "size" in actor else Vector2i(1, 1)
	return get_tiles_for_footprint(origin, size)


## A helper function that calculates an array of tiles for a given footprint.
## @param origin The top-left corner of the footprint.
## @param size The dimensions of the footprint (e.g., Vector2i(2,2) for a 2x2 area).
## @return An `Array[Vector2i]` of tiles within that footprint.
func get_tiles_for_footprint(origin: Vector2i, size: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for x in range(size.x):
		for y in range(size.y):
			tiles.append(origin + Vector2i(x, y))
	return tiles


#endregion

#region Distance Functions


## Calculates the Manhattan distance between two points.
## This is the distance measured along grid lines (no diagonals), like a taxi in Manhattan.
## It is used for standard movement range calculations where diagonal moves cost more.
##
## @param a The first Vector2i coordinate.
## @param b The second Vector2i coordinate.
## @return The distance in an integer number of steps.
func get_distance(a: Vector2i, b: Vector2i) -> int:
	return abs(a.x - b.x) + abs(a.y - b.y)


## Calculates the Chebyshev distance between two points.
## This is the distance for a square radius, where diagonal moves cost the same as cardinal moves.
## It is used for area-of-effect spells, radius checks, and as the heuristic for A* pathfinding.
## @param a The first Vector2i coordinate.
## @param b The second Vector2i coordinate.
## @return The distance in an integer number of steps.
func get_chebyshev_distance(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))


#endregion

#region Line of Sight (LOS)


## Sets or removes a tile as a static line-of-sight blocker.
## @param pos The Vector2i coordinate of the tile.
## @param blocks If `true`, the tile will block LOS. If `false`, it will be cleared.
func set_los_blocker(pos: Vector2i, blocks := true) -> void:
	if !is_in_bounds(pos):
		return
	if blocks:
		los_blockers[pos] = true
		log_event("los_blocker_added", null, pos)
	else:
		los_blockers.erase(pos)
		log_event("los_blocker_removed", null, pos)
	_clear_path_cache()


## Checks if a tile is a static line-of-sight blocker.
## @param pos The Vector2i coordinate to check.
## @return `true` if the tile is a designated LOS blocker.
func is_los_blocker(pos: Vector2i) -> bool:
	return los_blockers.has(pos)


## Determines if there is a clear line of sight between two points.
## Uses Bresenham's line algorithm. A line is blocked if any intermediate tile
## is occupied, a designated LOS blocker, or has "full" cover facing the ray
## with sufficient height to obstruct it.
## @param a The starting Vector2i coordinate.
## @param b The ending Vector2i coordinate.
## @return `true` if there is a clear line of sight, otherwise `false`.
func has_line_of_sight(a: Vector2i, b: Vector2i) -> bool:
	if !is_in_bounds(a) or !is_in_bounds(b):
		return false
	var x0 = a.x
	var y0 = a.y
	var x1 = b.x
	var y1 = b.y
	var dx = abs(x1 - x0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var dy = -abs(y1 - y0)
	var err = dx + dy

	var last_pos = a

	while true:
		var pos = Vector2i(x0, y0)
		if pos != a and pos != b:
			if is_occupied(pos) or is_los_blocker(pos) or get_cover(pos) == "full":
				return false
		if pos.x != last_pos.x and pos.y != last_pos.y:  # Diagonal step
			var corner1 = Vector2i(last_pos.x, pos.y)
			var corner2 = Vector2i(pos.x, last_pos.y)
			if (
				is_occupied(corner1)
				or is_los_blocker(corner1)
				or get_cover(corner1) == "full"
				or is_occupied(corner2)
				or is_los_blocker(corner2)
				or get_cover(corner2) == "full"
			):
				return false
		if pos == b:
			break
		last_pos = pos
		var e2 = 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy
	return true



#endregion

#region Range Queries


## Finds all actors within a given radius of a center point.
## @param center The central Vector2i coordinate for the search.
## @param radius The radius of the search, measured in Chebyshev distance (a square).
## @param require_los If `true`, only actors with a clear line of sight from the center will be returned.
## @return An `Array[Object]` of actors found within the radius.
func get_actors_in_radius(center: Vector2i, radius: int, require_los := false) -> Array[Object]:
	var result: Array[Object] = []
	for actor in get_all_actors():  # Use get_all_actors to avoid duplicates
		var pos = actor_positions[actor]
		if get_chebyshev_distance(center, pos) <= radius:
			if require_los and not has_line_of_sight(center, pos):
				continue
			result.append(actor)
	return result


## Finds all grid positions within a given range of a center point.
## @param center The central Vector2i coordinate for the search.
## @param range_val The range of the search, measured in Chebyshev distance (a square).
## @param require_los If `true`, only tiles with a clear line of sight from the center will be returned.
## @return An `Array[Vector2i]` of grid positions found within the range.
func get_positions_in_range(
	center: Vector2i, range_val: int, require_los := false
) -> Array[Vector2i]:
	var positions: Array[Vector2i] = []
	for x in range(-range_val, range_val + 1):
		for y in range(-range_val, range_val + 1):
			var pos = center + Vector2i(x, y)
			if is_in_bounds(pos) and get_chebyshev_distance(center, pos) <= range_val:
				if require_los and not has_line_of_sight(center, pos):
					continue
				positions.append(pos)
	return positions


#endregion

#region Pathfinding


## Finds the shortest path for an actor of a given size.
## This is a wrapper for the main pathfinding logic that passes the actor's size.
## @param actor The actor to find a path for. Must have `size` and `facing` properties.
## @param start The starting Vector2i coordinate.
## @param goal The target Vector2i coordinate.
## @return An `Array[Vector2i]` representing the path.
func find_path_for_actor(actor: Object, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var size = actor.get("size") if "size" in actor else Vector2i(1, 1)
	var facing = actor.get("facing") if "facing" in actor else Vector2i.RIGHT
	return find_path(start, facing, goal, size)


## Finds the shortest path between two points using the A* search algorithm.
## The path is calculated based on movement costs, facing changes, elevation, and actor size.
## @param start The starting Vector2i coordinate.
## @param start_facing The initial facing direction of the actor (e.g., Vector2i.RIGHT).
## @param goal The target Vector2i coordinate.
## @param actor_size The size of the actor trying to pathfind.
## @return An `Array[Vector2i]` representing the path from start to goal (inclusive).
##         Returns an empty array if no path is found.
func find_path(
	start: Vector2i, start_facing: Vector2i, goal: Vector2i, actor_size := Vector2i(1, 1)
) -> Array[Vector2i]:
	if not is_in_bounds(start) or not is_in_bounds(goal):
		return []

		# Check if the entire actor footprint is valid at the neighbor position.
	var cache_key: String = var_to_str([start, goal, actor_size])
	if _path_cache.has(cache_key):
		return _path_cache[cache_key].duplicate()

		# Check if the entire actor footprint is valid at the neighbor position.
	var open_set := [start]
	var came_from := {}
	var g_score := {start: 0.0}
	var f_score := {start: get_chebyshev_distance(start, goal)}
	var start_actor = get_actor_at(start)

	const DIAGONAL_COST_MULT := 1.4

	while not open_set.is_empty():
		var best_node_idx = 0
		for i in range(1, open_set.size()):
			if f_score.get(open_set[i], INF) < f_score.get(open_set[best_node_idx], INF):
				best_node_idx = i

				# Check if the entire actor footprint is valid at the neighbor position.
		var current = open_set[best_node_idx]

		if current == goal:
			break

			# Check if the entire actor footprint is valid at the neighbor position.
		var last_element = open_set.back()
		open_set[best_node_idx] = last_element
		open_set.pop_back()

		var current_facing: Vector2i
		var prev_node = came_from.get(current, null)
		if prev_node:
			current_facing = Vector2i(Vector2(current - prev_node).normalized().round())

			# Check if the entire actor footprint is valid at the neighbor position.
		else:
			current_facing = start_facing

			# Check if the entire actor footprint is valid at the neighbor position.
		for offset in neighbor_offsets:
			var neighbor = current + offset

			# Check if the entire actor footprint is valid at the neighbor position.
			var footprint_tiles = get_tiles_for_footprint(neighbor, actor_size)
			var is_valid_move = true
			for tile in footprint_tiles:
				if not is_in_bounds(tile):
					is_valid_move = false
					break
				if (
					is_occupied(tile)
					and tile != goal
					and (start_actor == null or get_actor_at(tile) != start_actor)
				):
					is_valid_move = false
					break
			if not is_valid_move or is_blocked_by_obstacle(current, neighbor):
				continue
			var current_height = get_height(current)
			var neighbor_height = get_height(neighbor)
			var height_diff = neighbor_height - current_height
			if height_diff > MAX_CLIMB_HEIGHT:
				continue
			var step_cost = get_movement_cost(neighbor)
			if step_cost >= INF:
				continue
			if offset.x != 0 and offset.y != 0:  # Diagonal movement
				step_cost *= DIAGONAL_COST_MULT
			if height_diff > 0:
				step_cost += height_diff * CLIMB_COST
			var neighbor_facing = Vector2i(Vector2(offset).normalized().round())
			if neighbor_facing != current_facing:
				step_cost += TURN_COST
			var tentative_g = g_score.get(current, 0.0) + step_cost
			if tentative_g < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + get_chebyshev_distance(neighbor, goal)
				if not open_set.has(neighbor):
					open_set.append(neighbor)
	var path: Array[Vector2i] = []
	var node = goal
	while came_from.has(node) or node == start:
		path.insert(0, node)
		if node == start:
			break
		if came_from.has(node):
			node = came_from[node]
		else:
			break
	if path.is_empty() or path.front() != start:
		return []
	_path_cache[cache_key] = path.duplicate()
	return path


#endregion

#region Area of Effect (AOE)


## Calculates the tiles affected by an Area of Effect (AOE) spell or ability.
## This is the main dispatcher function for AOE calculations.
## @param shape The shape of the AOE. Valid options: "burst", "cone", "line", "wall".
## @param origin The starting point of the AOE.
## @param direction The direction vector for shapes like cone, line, and wall.
## @param range The primary dimension of the shape (radius for burst, length for others).
## @return An `Array[Vector2i]` of all tiles within the specified AOE.
func get_aoe_tiles(
	shape: String, origin: Vector2i, direction: Vector2i, range: int
) -> Array[Vector2i]:
	match shape:
		"burst":
			return _get_burst_aoe(origin, range)
		"cone":
			return _get_cone_aoe(origin, direction, range)
		"line":
			return _get_line_aoe(origin, direction, range)
		"wall":
			return _get_wall_aoe(origin, direction, range)
	return []


## Calculates a circular burst/radius AOE.
## @param origin The center point of the burst.
## @param radius The radius of the burst, measured in Chebyshev distance.
## @return An `Array[Vector2i]` of tiles within the burst.
func _get_burst_aoe(origin: Vector2i, radius: int) -> Array[Vector2i]:
	return get_positions_in_range(origin, radius, false)


## Calculates a cone-shaped AOE.
## The cone originates from the origin and expands in the given direction.
## The angle of the cone is approximately 90 degrees.
## @param origin The starting point of the cone.
## @param direction The direction the cone is facing.
## @param length The length of the cone in tiles.
## @return An `Array[Vector2i]` of tiles within the cone.
func _get_cone_aoe(origin: Vector2i, direction: Vector2i, length: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if direction == Vector2i.ZERO:
		return tiles

		# Iterate over a bounding box around the origin to find potential tiles.

		# Check distance and angle.

		# Use a dot product threshold of ~0.707 for a 90-degree cone (cos(45)).
	var facing_vec := Vector2(direction).normalized()

	# Iterate over a bounding box around the origin to find potential tiles.
	for x in range(-length, length + 1):
		for y in range(-length, length + 1):
			var pos = origin + Vector2i(x, y)
			if not is_in_bounds(pos):
				continue

				# Check distance and angle.

				# Use a dot product threshold of ~0.707 for a 90-degree cone (cos(45)).
			var to_pos_vec := Vector2(pos - origin)
			if to_pos_vec == Vector2.ZERO:
				continue

				# Check distance and angle.

				# Use a dot product threshold of ~0.707 for a 90-degree cone (cos(45)).
			if get_distance(origin, pos) <= length:
				var dot_product = facing_vec.dot(to_pos_vec.normalized())
				# Use a dot product threshold of ~0.707 for a 90-degree cone (cos(45)).
				if dot_product > 0.7:
					tiles.append(pos)
	return tiles


## Calculates a line-shaped AOE.
## The line is 1 tile wide and travels from the origin in a specific direction.
## @param origin The starting point of the line.
## @param direction The direction of the line.
## @param length The length of the line in tiles.
## @return An `Array[Vector2i]` of tiles in the line.
func _get_line_aoe(origin: Vector2i, direction: Vector2i, length: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if direction == Vector2i.ZERO:
		return tiles

		# This simple step logic works well for cardinal and perfect diagonal directions.
	var current_pos = origin
	for i in range(length):
		if is_in_bounds(current_pos):
			tiles.append(current_pos)
			# This simple step logic works well for cardinal and perfect diagonal directions.
		current_pos += direction
	return tiles


## Calculates a wall-shaped AOE.
## The wall is a line perpendicular to the given direction, centered on the origin.
## @param origin The center point of the wall.
## @param direction The direction the wall is "facing" (wall is perpendicular to this).
## @param length The total length of the wall in tiles.
## @return An `Array[Vector2i]` of tiles in the wall.
func _get_wall_aoe(origin: Vector2i, direction: Vector2i, length: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	if direction == Vector2i.ZERO:
		return tiles

		# Get the perpendicular direction vector.

		# Trace the wall in both perpendicular directions from the center.
	var wall_dir = Vector2i(direction.y, -direction.x)
	var half_len = length / 2

	# Trace the wall in both perpendicular directions from the center.
	for i in range(-half_len, length - half_len):
		var pos = origin + wall_dir * i
		if is_in_bounds(pos):
			tiles.append(pos)
	return tiles


#endregion

#region Tactical Functions


## Calculates an actor's zone of control (ZOC) based on their facing and size.
## For large actors, the ZOC is projected from their entire border, making them
## more formidable obstacles.
## @param actor The actor object whose ZOC is being calculated.
## @param radius The radius of the ZOC in tiles.
## @param arc A string specifying the arc to calculate. Valid options are:
##         - `"all"`: A 360-degree circle around the actor.
##         - `"front"`: A cone in the direction the actor is facing.
##         - `"rear"`: A cone opposite to the actor's facing.
##         - `"left"`: An arc to the actor's left.
##         - `"right"`: An arc to the actor's right.
##         - `"sides"`: A combination of the left and right arcs.
## @return An `Array[Vector2i]` of tiles within the specified zone of control.
func get_zone_of_control(actor: Object, radius := 1, arc := "all") -> Array[Vector2i]:
	if actor == null or not actor_positions.has(actor):
		return []

		# FIX: Explicitly type the 'center' loop variable. This tells the analyzer to
		# treat 'center' as a Vector2i, which resolves the type inference error for 'pos'.
	var facing_dir = actor.get("facing") if "facing" in actor else Vector2i.RIGHT
	var facing_vec := Vector2(facing_dir).normalized()
	if facing_vec == Vector2.ZERO:
		facing_vec = Vector2.RIGHT

		# FIX: Explicitly type the 'center' loop variable. This tells the analyzer to
		# treat 'center' as a Vector2i, which resolves the type inference error for 'pos'.
	var right_vec := facing_vec.orthogonal()
	const FRONT_T := 0.25
	const SIDE_T := 0.25

	var border_tiles = _get_border_tiles(actor)
	var zoc_dict: Dictionary = {}
	var occupied_tiles = get_occupied_tiles(actor)

	# FIX: Explicitly type the 'center' loop variable. This tells the analyzer to
	# treat 'center' as a Vector2i, which resolves the type inference error for 'pos'.
	for center: Vector2i in border_tiles:
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				var offset := Vector2i(x, y)
				if offset == Vector2i.ZERO:
					continue
				var pos := center + offset
				if not is_in_bounds(pos) or pos in occupied_tiles:
					continue
				var off_v := Vector2(pos - actor_positions[actor]).normalized()
				var front_dot := facing_vec.dot(off_v)
				var right_dot := right_vec.dot(off_v)
				var include := false

				match arc:
					"all":
						include = true
					"front":
						include = front_dot > FRONT_T
					"rear":
						include = front_dot < -FRONT_T
					"left":
						include = right_dot < -SIDE_T
					"right":
						include = right_dot > SIDE_T
					"sides":
						include = abs(front_dot) <= SIDE_T
				if include:
					zoc_dict[pos] = true
	var result: Array[Vector2i] = []
	for tile in zoc_dict.keys():
		result.append(tile)
	return result


## A helper function to find the border tiles of a potentially large actor.
## @param actor The actor object.
## @return An `Array[Vector2i]` containing only the tiles on the actor's perimeter.
func _get_border_tiles(actor: Object) -> Array[Vector2i]:
	var occupied_tiles = get_occupied_tiles(actor)
	if occupied_tiles.size() <= 1:
		return occupied_tiles
	var border: Array[Vector2i] = []
	var occupied_dict := {}
	for tile in occupied_tiles:
		occupied_dict[tile] = true
	var neighbor_offsets = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

	for tile in occupied_tiles:
		var is_border = false
		for offset in neighbor_offsets:
			if not occupied_dict.has(tile + offset):
				is_border = true
				break
		if is_border:
			border.append(tile)
	return border


## Returns a set of unique tiles threatened by any actor on the grid.
## @param radius The radius to check for each actor's ZOC.
## @param arc The specific arc to check for each actor's ZOC.
## @return An `Array[Vector2i]` of all unique threatened tiles.
func get_tiles_under_zoc(radius := 1, arc := "all") -> Array[Vector2i]:
	# FIX: Remove any stray characters (like a backtick) from this function
	# and explicitly type the dictionary to prevent type inference errors.
	var zoc_tiles_dict: Dictionary = {}
	for actor in get_all_actors():
		for tile in get_zone_of_control(actor, radius, arc):
			zoc_tiles_dict[tile] = true
	var result: Array[Vector2i] = []
	for tile in zoc_tiles_dict.keys():
		result.append(tile)
	return result


## Checks if a defending actor is inside the ZOC of a threatening actor.
## @param defender The actor being threatened.
## @param threat_actor The actor projecting the ZOC.
## @param radius The radius of the threat_actor's ZOC.
## @param arc The specific arc of the threat_actor's ZOC to check.
## @return `true` if the defender is in the threat_actor's ZOC.
func actor_in_zoc(defender: Object, threat_actor: Object, radius := 1, arc := "all") -> bool:
	if defender == null or threat_actor == null:
		return false
	var zoc = get_zone_of_control(threat_actor, radius, arc)
	var temp_pos = defender.get("grid_pos")
	var defender_pos: Vector2i = temp_pos if temp_pos != null else Vector2i(-1, -1)
	return defender_pos in zoc


## A convenience function, alias for `get_zone_of_control`.
## @return An `Array[Vector2i]` of threatened tiles.
func get_threatened_tiles_by(actor: Object, radius := 1, arc := "all") -> Array[Vector2i]:
	return get_zone_of_control(actor, radius, arc)


## Classifies an attacker's position relative to a defender's facing.
## Uses vector math to determine the angle between the defender's forward vector
## and the vector pointing towards the attacker.
## @param defender The actor being attacked.
## @param attacker The actor performing the attack.
## @return A string: `"front"`, `"rear"`, `"left"`, `"right"`, or `"none"`.
func get_attack_arc(defender: Object, attacker: Object) -> String:
	if defender == null or attacker == null:
		return "none"
	var temp_attacker_pos = attacker.get("grid_pos")
	var attacker_pos: Vector2i = (
		temp_attacker_pos if temp_attacker_pos != null else Vector2i(-1, -1)
	)
	var temp_defender_pos = defender.get("grid_pos")
	var defender_pos: Vector2i = (
		temp_defender_pos if temp_defender_pos != null else Vector2i(-1, -1)
	)
	if attacker_pos == Vector2i(-1, -1) or defender_pos == Vector2i(-1, -1):
		return "none"
	var to_attacker := Vector2(attacker_pos - defender_pos)
	if to_attacker == Vector2.ZERO:
		return "none"
	var temp_facing = defender.get("facing")
	var facing_dir: Vector2i = temp_facing if temp_facing != null else Vector2i.RIGHT
	var facing_vec := Vector2(facing_dir).normalized()
	if facing_vec == Vector2.ZERO:
		facing_vec = Vector2.RIGHT
	var delta := facing_vec.angle_to(to_attacker)

	const EPSILON = 0.0001
	if abs(delta) <= (PI / 4.0) + EPSILON:
		return "front"
	elif delta > PI / 4.0 and delta <= 3.0 * PI / 4.0:
		return "left"
	elif delta < -PI / 4.0 and delta >= -3.0 * PI / 4.0:
		return "right"
	else:
		return "rear"


## Determines if an actor is flanked.
## An actor is considered flanked if they are threatened by at least two other actors
## positioned on roughly opposite sides of them.
## @param actor The actor to check for flanking status.
## @return `true` if the actor is flanked, otherwise `false`.
func is_flanked(actor: Object) -> bool:
	if actor == null or not actor_positions.has(actor):
		return false
	var pos: Vector2i = actor_positions[actor]
	var attackers: Array[Object] = []

	for threat in get_all_actors():
		if threat == actor:
			continue
		if actor_in_zoc(actor, threat):
			attackers.append(threat)
	if attackers.size() < 2:
		return false
	for i in range(attackers.size()):
		for j in range(i + 1, attackers.size()):
			var a1 := Vector2(actor_positions[attackers[i]] - pos).normalized()
			var a2 := Vector2(actor_positions[attackers[j]] - pos).normalized()
			if a1.dot(a2) < -0.9:
				return true
	return false


#endregion

#region Terrain, Tags, & Cover


## Sets the movement cost for a specific tile.
## @param pos The Vector2i coordinate of the tile.
## @param cost The movement cost as a float. Use `INF` for impassable tiles.
func set_movement_cost(pos: Vector2i, cost: float) -> void:
	if is_in_bounds(pos):
		movement_costs[pos] = cost
		log_event("movement_cost_set", null, pos, {"cost": cost})
		_clear_path_cache()


## Gets the movement cost for a specific tile.
## @param pos The Vector2i coordinate of the tile.
## @return The movement cost as a float. Returns a default of 1.0 if no
##         specific cost is set, or `INF` if the tile is out of bounds.
func get_movement_cost(pos: Vector2i) -> float:
	if not is_in_bounds(pos):
		return INF
	return movement_costs.get(pos, 1.0)


## Sets the height level for a specific tile.
## @param pos The Vector2i coordinate of the tile.
## @param level The height level as an integer.
func set_height(pos: Vector2i, level: int) -> void:
	if is_in_bounds(pos):
		height_levels[pos] = level
		log_event("height_set", null, pos, {"level": level})
		_clear_path_cache()


## Gets the height level for a specific tile.
## @param pos The Vector2i coordinate of the tile.
## @return The height level as an integer. Returns a default of 0 if no
##         specific height is set.
func get_height(pos: Vector2i) -> int:
	return height_levels.get(pos, 0)


## Adds a descriptive tag to a tile. A tile can have multiple tags.
## @param pos The Vector2i coordinate of the tile.
## @param tag A String representing the tag (e.g., "grass", "building").
func add_tile_tag(pos: Vector2i, tag: String) -> void:
	if not is_in_bounds(pos):
		return
	if not tile_tags.has(pos):
		tile_tags[pos] = []
	if not tag in tile_tags[pos]:
		tile_tags[pos].append(tag)


## Removes a descriptive tag from a tile.
## @param pos The Vector2i coordinate of the tile.
## @param tag The String tag to remove.
func remove_tile_tag(pos: Vector2i, tag: String) -> void:
	if is_in_bounds(pos) and tile_tags.has(pos):
		tile_tags[pos].erase(tag)
		# If the tags array is now empty, remove the key from the dictionary.
		if tile_tags[pos].is_empty():
			tile_tags.erase(pos)


## Checks if a tile has a specific descriptive tag.
## @param pos The Vector2i coordinate of the tile to check.
## @param tag The String tag to query.
## @return `true` if the tile has the specified tag, otherwise `false`.
func has_tile_tag(pos: Vector2i, tag: String) -> bool:
	if not is_in_bounds(pos) or not tile_tags.has(pos):
		return false
	return tag in tile_tags[pos]


## Converts a vector to a cardinal direction string.
## @param v The vector to evaluate.
## @return "north", "east", "south", "west", or an empty string for zero vectors.
func _vector_to_direction(v: Vector2i) -> String:
	if abs(v.x) > abs(v.y):
		return "east" if v.x > 0 else "west"
	elif v.y != 0:
		return "south" if v.y > 0 else "north"
	return ""

## Sets the cover information for a tile.
## Valid types are "half" and "full". Direction must be one of
## "north", "east", "south", or "west". Any invalid input clears the cover.
## @param pos The Vector2i coordinate of the tile.
## @param type A String for the cover type ("half" or "full").
func set_cover(pos: Vector2i, type: String) -> void:
	if not is_in_bounds(pos):
		return
	if type in ["half", "full"]:
		cover_types[pos] = type
	else:  # "none" or any invalid string clears the cover.
		cover_types.erase(pos)


## Gets the cover information for a tile.
## @param pos The Vector2i coordinate of the tile.

## @return A String: "half", "full", or "none" (default).
func get_cover(pos: Vector2i) -> String:
	return cover_types.get(pos, "none")


## Computes the defensive cover modifier for an attack.
##
## Cover grants a penalty to the attack roll when the attacker is within
## the cover's protected direction and not elevated above it. The
## modifier does not apply for shots from other angles or when the
## attacker stands higher than the cover's top.
##
## @param attacker_pos Position of the attacker on the grid.
## @param defender_pos Position of the defender on the grid.
## @return An integer penalty applied to hit chance.
func get_cover_modifier(attacker_pos: Vector2i, defender_pos: Vector2i) -> int:
	var cover := get_cover(defender_pos)
	if cover == "none":
		return 0

		# Determine if the attack is roughly head-on (within 45 degrees of a
		# cardinal direction) or coming from an oblique angle.  Direct angles
		# benefit more from cover than diagonal shots.
	var delta := Vector2(attacker_pos - defender_pos)
	if delta == Vector2.ZERO:
		return 0

		# Determine if the attack is roughly head-on (within 45 degrees of a
		# cardinal direction) or coming from an oblique angle.  Direct angles
		# benefit more from cover than diagonal shots.
	var ang: float = abs(Vector2.RIGHT.angle_to(delta.normalized()))
	var frontal: bool = ang <= PI / 4 or ang >= 3.0 * PI / 4.0

	match cover:
		"half":
			return -20 if frontal else -10
		"full":
			return -40 if frontal else -20
		_:
			return 0


#endregion


#region Serialization
## Convert grid metadata to a Dictionary for JSON serialization.
func to_dict() -> Dictionary:
	return {
		"width": width,
		"height": height,
		"movement_costs": movement_costs,
		"los_blockers": los_blockers,
		"height_levels": height_levels,
		"tile_tags": tile_tags,
		"cover_types": cover_types,
		"obstacles": obstacles,
		"diagonal_movement": diagonal_movement,
	}


## Restore grid metadata from a Dictionary produced by `to_dict()`.
## Actor placement dictionaries are left untouched so callers can rebuild actors separately.
func from_dict(data: Dictionary) -> void:
	width = data.get("width", width)
	height = data.get("height", height)
	movement_costs = data.get("movement_costs", {})
	los_blockers = data.get("los_blockers", {})
	height_levels = data.get("height_levels", {})
	tile_tags = data.get("tile_tags", {})
	cover_types = data.get("cover_types", {})
	obstacles = data.get("obstacles", {})
	diagonal_movement = data.get("diagonal_movement", diagonal_movement)
	_update_neighbor_offsets()
	_clear_path_cache()


#endregion


#region Tests
## Basic regression tests for core grid features. These tests cover actor
## placement, pathfinding around obstacles, line of sight checks, and area of
## effect helpers. They are intended for automated execution via the project
## test runner.
func run_tests() -> Dictionary:
	var failed := 0
	var total := 0
	var logs: Array[String] = []

	width = 4
	height = 4

	# Ensure a clean slate for each test run.
	occupied.clear()
	actor_positions.clear()
	movement_costs.clear()
	los_blockers.clear()
	cover_types.clear()
	height_levels.clear()
	tile_tags.clear()
	_clear_path_cache()

	var actor: BaseActor = BaseActor.new("tester", Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE)

	# --- Placement ---
	total += 1
	if not move_actor(actor, Vector2i(1, 1)):
		failed += 1
		logs.append("actor failed to place at (1,1)")

		# Re-place actor for subsequent tests.

		# --- Pathfinding ---

		# --- Line of Sight ---

		# --- AOE Helpers ---

		# Cleanup actor instance
	total += 1
	remove_actor(actor)
	if is_occupied(Vector2i(1, 1)):
		failed += 1
		logs.append("tile (1,1) remained occupied after removal")

		# Re-place actor for subsequent tests.

		# --- Pathfinding ---

		# --- Line of Sight ---

		# --- AOE Helpers ---

		# Cleanup actor instance
	move_actor(actor, Vector2i.ZERO)

	# --- Pathfinding ---
	set_movement_cost(Vector2i(1, 0), INF)
	var path = find_path_for_actor(actor, Vector2i.ZERO, Vector2i(3, 0))
	total += 1
	if path.is_empty() or path[-1] != Vector2i(3, 0):
		failed += 1
		logs.append("pathfinding failed to reach goal around obstacle")

		# --- Line of Sight ---

		# --- AOE Helpers ---

		# Cleanup actor instance
	movement_costs.clear()

	# --- Line of Sight ---
	set_los_blocker(Vector2i(1, 0), true)
	total += 1
	if has_line_of_sight(Vector2i(0, 0), Vector2i(3, 0)):
		failed += 1
		logs.append("LOS not blocked by blocker")

		# --- AOE Helpers ---

		# Cleanup actor instance
	set_los_blocker(Vector2i(1, 0), false)
	total += 1
	if not has_line_of_sight(Vector2i(0, 0), Vector2i(3, 0)):
		failed += 1
		logs.append("LOS incorrectly blocked")

		# --- AOE Helpers ---

		# Cleanup actor instance
	var aoe = get_aoe_tiles("burst", Vector2i(1, 1), Vector2i.ZERO, 1)
	total += 1
	if aoe.size() != 9 or not aoe.has(Vector2i(0, 0)) or not aoe.has(Vector2i(2, 2)):
		failed += 1
		logs.append("burst AOE returned incorrect tiles")

		# Cleanup actor instance
	remove_actor(actor)
	actor.free()

	return {
		"failed": failed,
		"total": total,
		"log": "\n".join(logs),
	}

#endregion
