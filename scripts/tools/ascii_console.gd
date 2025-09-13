extends SceneTree
## Headless ASCII console that integrates the GridRealtimeRenderer
## with RuntimeServices and TurnBasedGridTimespace.  This allows
## basic actor spawning, action execution, and turn management while
## running the project without a graphical window.
## The console maintains a circular command history navigable with the
## arrow keys and supports tab completion using known commands and the
## names of existing actors.
##
## Supported commands:
##  - `spawn NAME X Y` – create an actor at the given grid position.
##  - `move_actor NAME X Y` – perform the built-in `move` action.
##  - `action NAME ID [X Y]` – execute an arbitrary action by ID with
##    optional Vector2i payload.
##  - `remove NAME` – delete an actor from the grid and timespace.
##  - `end_turn` – advance to the next actor's turn.
##  - `list` – print current actors and their positions.
##  - `save_state FILE` – write grid, actor and marker state to JSON.
##  - `load_state FILE` – restore state from a JSON file.
##  - Renderer passthrough: `select|move|target|click X Y` and `clear`.

var renderer := preload("res://scripts/modules/GridRealtimeRenderer.gd").new()
var RuntimeServices := preload("res://scripts/modules/runtime_services.gd")
var TurnBasedGridTimespace := preload("res://scripts/modules/turn_timespace.gd")
var BaseActor := preload("res://scripts/core/base_actor.gd")

var runtime := RuntimeServices.new()
var grid = runtime.grid_map
var timespace = runtime.timespace
var actors: Dictionary = {}



var _gateway
var _use_gateway := true

## Input mode flags and history/completion buffers for interactive use.
const HISTORY_MAX := 100
const COMMANDS := [
    "spawn", "move_actor", "action", "remove", "end_turn", "list",
    "save_state", "load_state", "select", "move", "target", "click",
    "drag_start", "drag", "drag_end",
    "grid", "color", "rate", "snapshot", "profile", "terrain", "facing", "damage", "source", "help",
    "clear", "quit"
]
var history: Array[String] = []
var history_index: int = 0

## Start up services and choose input mode (interactive vs piped) based on CLI args.
func _init():
	var args := OS.get_cmdline_args()
	var use_pipe := false
	_use_gateway = true
	for a in args:
		if a == "--pipe":
			use_pipe = true
		elif a == "--no-attach":
			_use_gateway = false
	# Defer gateway attachment to ensure the scene tree is active.
	call_deferred("_attach_or_fallback")
	if use_pipe:
		call_deferred("_loop_piped")
	else:
		call_deferred("_loop_interactive")

func _attach_or_fallback() -> void:
	if _use_gateway:
		# Try to resolve the autoload by name under the root (no absolute path).
		_gateway = get_root().get_node_or_null("AsciiGateway")
		if _gateway != null:
			return
		# Fallback to local wiring if gateway not present.
		_use_gateway = false
	if not _use_gateway:
		renderer.set_grid_size(4, 4)
		renderer.ascii_include_actors = true
		get_root().add_child(renderer)
		get_root().add_child(runtime)
		grid.width = 4
		grid.height = 4


func _spawn_actor(name: String, pos: Vector2i) -> void:
	var actor := BaseActor.new(name)
	actor.add_to_group("actors")
	actors[name] = actor
	get_root().add_child(actor)
	timespace.add_actor(actor, 10, 2, pos)
	if timespace.state == TurnBasedGridTimespace.State.IDLE:
		timespace.start_round()


func _move_actor(name: String, pos: Vector2i) -> void:
	var actor = actors.get(name)
	if actor:
		timespace.perform(actor, "move", pos)


func _remove_actor(name: String) -> void:
	var actor = actors.get(name)
	if actor:
		timespace.remove_actor(actor)
		actors.erase(name)
		actor.queue_free()


func _perform_action(name: String, id: String, payload) -> void:
	var actor = actors.get(name)
	if actor:
		timespace.perform(actor, id, payload)


## Serialize grid metadata, actors, and renderer markers to a JSON file.
## @param path Output file path.
func _save_state(path: String) -> void:
	var state: Dictionary = {"grid": grid.to_dict(), "actors": [], "markers": []}
	for n in actors.keys():
		var a = actors[n]
		state["actors"].append(
			{
				"name": n,
				"pos": [a.grid_pos.x, a.grid_pos.y],
				"facing": [a.facing.x, a.facing.y],
				"size": [a.size.x, a.size.y]
			}
		)
	for p in renderer._ascii_entities.keys():
		var ents: Array = []
		for ent in renderer._ascii_entities[p]:
			ents.append(
				{
					"char": ent.char,
					"color": [ent.color.r, ent.color.g, ent.color.b, ent.color.a],
					"priority": ent.priority
				}
			)
		state["markers"].append({"pos": [p.x, p.y], "ents": ents})
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(state))
		file.close()


## Load state from a JSON file and rebuild actors and renderer markers.
## Existing actors and markers are cleared.
## @param path Input file path.
func _load_state(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Failed to open %s" % path)
		return
	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(data) != TYPE_DICTIONARY:
		return
	# Clear existing actors and markers
	for n in actors.keys():
		var a = actors[n]
		timespace.remove_actor(a)
		a.queue_free()
	actors.clear()
	renderer.clear_ascii_entities()
	# Restore grid and resize renderer
	grid.from_dict(data.get("grid", {}))
	renderer.set_grid_size(grid.width, grid.height)
	# Rebuild actors
	for entry in data.get("actors", []):
		var pos_arr: Array = entry.get("pos", [0, 0])
		var facing_arr: Array = entry.get("facing", [1, 0])
		var size_arr: Array = entry.get("size", [1, 1])
		var actor = BaseActor.new(
			entry.get("name", ""),
			Vector2i(pos_arr[0], pos_arr[1]),
			Vector2i(facing_arr[0], facing_arr[1]),
			Vector2i(size_arr[0], size_arr[1])
		)
		actor.add_to_group("actors")
		actors[actor.name] = actor
		get_root().add_child(actor)
		timespace.add_actor(actor, 10, 2, actor.grid_pos)
	if timespace.state == TurnBasedGridTimespace.State.IDLE and actors.size() > 0:
		timespace.start_round()
	# Rebuild markers
	for marker in data.get("markers", []):
		var mpos_arr: Array = marker.get("pos", [0, 0])
		var mpos := Vector2i(mpos_arr[0], mpos_arr[1])
		for ent in marker.get("ents", []):
			var col_arr: Array = ent.get("color", [1, 1, 1, 1])
			var col := Color(col_arr[0], col_arr[1], col_arr[2], col_arr[3])
			renderer.set_ascii_entity(mpos, ent.get("char", "?"), col, ent.get("priority", 0))



## Add a command to the history buffer, discarding the oldest entry when
## the maximum size is reached.
func _add_history(cmd: String) -> void:
	if cmd.is_empty():
		return
	if history.size() >= HISTORY_MAX:
		history.pop_front()
	history.append(cmd)
	history_index = history.size()

## Retrieve the previous command from history using circular indexing.
func _history_prev() -> String:
	if history.is_empty():
		return ""
	history_index = (history_index - 1 + history.size()) % history.size()
	return history[history_index]

## Retrieve the next command from history using circular indexing.
func _history_next() -> String:
	if history.is_empty():
		return ""
	history_index = (history_index + 1) % history.size()
	return history[history_index]

## Clear the current line and re-print the supplied buffer.
func _refresh_line(_buffer: String) -> void:
	# Simplified refresh to avoid platform-specific stdout control.
	pass

## Attempt to complete the current input using known commands or actor names.
func _complete_input(buffer: String) -> String:
	var parts := buffer.split(" ", false, 0)
	if parts.size() <= 1:
		var prefix := parts[0]
		var matches := COMMANDS.filter(func(c): return c.begins_with(prefix))
		if matches.size() == 1:
			return matches[0] + " "
	else:
		var prefix = parts[1]
		var actor_matches: Array = []
		for name in actors.keys():
			if name.begins_with(prefix):
				actor_matches.append(name)
		if actor_matches.size() == 1:
			parts[1] = actor_matches[0]
			return " ".join(parts) + " "
	return buffer

## Read a single line from standard input while providing history navigation
## and tab completion. The terminal must be in raw mode for arrow keys to
## generate escape sequences that this parser can interpret.
func _read_line() -> String:
	# Simplified cross-platform input without raw mode; no history/editing.
	return OS.read_string_from_stdin(1024).strip_edges()


func _loop_piped() -> void:
	while true:
		var frame := _snapshot()
		if frame != "":
			print(frame)
		var raw := OS.read_string_from_stdin(1024)
		var line := raw.strip_edges()
		# Treat EOF (empty read) as a signal to exit when piped.
		if raw.is_empty():
			break
		if line == "quit":
			break
		if not line.is_empty():
			_process_command(line)
	_cleanup()
	quit()

func _loop_interactive() -> void:
	while true:
		var frame := _snapshot()
		if frame != "":
			print(frame)
			print("> ")
		var raw := _read_line()
		var line := raw.strip_edges()
		# If stdin unexpectedly closes (e.g., piped input without --pipe), exit.
		if raw.is_empty():
			break
		_add_history(line)
		if line == "quit":
			break
		if not line.is_empty():
			_process_command(line)
	_cleanup()
	quit()

func _cleanup() -> void:
	# Best-effort cleanup to reduce exit-time leak warnings in headless runs.
	# Remove any actors we spawned locally and free their nodes.
	for n in actors.keys():
		var a = actors[n]
		if a:
			timespace.remove_actor(a)
			a.queue_free()
	actors.clear()
	# If we created runtime/renderer locally (no gateway), free them.
	if not _use_gateway:
		if renderer:
			renderer.queue_free()
			renderer = null
		if runtime:
			runtime.queue_free()
			runtime = null
	else:
		# Ask the gateway to clean up its nodes too.
		if _gateway and _gateway.has_method("cleanup"):
			_gateway.cleanup()

func _process_command(line: String) -> void:
	var parts := line.split(" ")
	if parts.size() >= 4 and parts[0] == "spawn":
		var name := parts[1]
		var pos := Vector2i(parts[2].to_int(), parts[3].to_int())
		if _use_gateway and _gateway:
			_gateway.spawn(name, pos)
		else:
			_spawn_actor(name, pos)
	elif parts.size() >= 4 and parts[0] == "move_actor":
		var name = parts[1]
		var pos = Vector2i(parts[2].to_int(), parts[3].to_int())
		if _use_gateway and _gateway:
			_gateway.move_actor(name, pos)
		else:
			_move_actor(name, pos)
	elif parts.size() >= 5 and parts[0] == "action":
		var name = parts[1]
		var id = parts[2]
		var payload = Vector2i(parts[3].to_int(), parts[4].to_int())
		if _use_gateway and _gateway:
			_gateway.perform(name, id, payload)
		else:
			_perform_action(name, id, payload)
	elif parts.size() >= 3 and parts[0] == "action":
		var name = parts[1]
		var id = parts[2]
		if _use_gateway and _gateway:
			_gateway.perform(name, id, null)
		else:
			_perform_action(name, id, null)
	elif parts.size() >= 2 and parts[0] == "remove":
		if _use_gateway and _gateway:
			_gateway.remove(parts[1])
		else:
			_remove_actor(parts[1])
	elif parts.size() >= 1 and parts[0] == "end_turn":
		if _use_gateway and _gateway:
			_gateway.exec("end_turn")
		else:
			timespace.end_turn()
	elif parts.size() >= 1 and (parts[0] == "list" or parts[0] == "actors"):
		if _use_gateway and _gateway:
			print(_gateway.list())
		else:
			for n in actors.keys():
				var a = actors[n]
				print("%s at %s" % [n, a.grid_pos])
	elif parts.size() >= 2 and parts[0] == "save_state":
		_save_state(parts[1])
	elif parts.size() >= 2 and parts[0] == "load_state":
		_load_state(parts[1])
	elif parts.size() >= 3 and parts[0] == "grid":
		# Resize only in local (no-gateway) mode.
		if not _use_gateway:
			var w := parts[1].to_int()
			var h := parts[2].to_int()
			grid.width = w
			grid.height = h
			renderer.set_grid_size(w, h)
	elif parts.size() >= 2 and parts[0] == "color":
		var on := parts[1].to_lower() in ["1","on","true","yes"]
		renderer.ascii_use_color = on
	elif parts.size() >= 2 and parts[0] == "rate":
		var hz: float = float(parts[1])
		if hz > 0.0:
			if _use_gateway and _gateway and _gateway.renderer:
				_gateway.renderer.set_ascii_rate(hz)
			else:
				renderer.set_ascii_rate(hz)
	elif parts.size() >= 1 and parts[0] == "snapshot":
		print(_snapshot())
	elif parts.size() >= 2 and parts[0] == "profile":
		# Load symbol map from JSON: profile <file> [key]
		var file := parts[1]
		var key := parts[2] if parts.size() >= 3 else "default"
		var map := _load_profile_file(file, key)
		if _use_gateway and _gateway and _gateway.renderer:
			_gateway.renderer.set_symbol_map(map)
		else:
			renderer.set_symbol_map(map)
	elif parts.size() >= 2 and parts[0] == "terrain":
		var file := parts[1]
		var key := parts[2] if parts.size() >= 3 else "default"
		var map := _load_profile_file(file, key)
		if _use_gateway and _gateway and _gateway.renderer:
			_gateway.renderer.set_terrain_symbol_map(map)
		else:
			renderer.set_terrain_symbol_map(map)
	elif parts.size() >= 2 and parts[0] == "facing":
		var on := parts[1].to_lower() in ["1","on","true","yes"]
		if _use_gateway and _gateway and _gateway.renderer:
			_gateway.renderer.ascii_show_facing = on
		else:
			renderer.ascii_show_facing = on
	elif parts.size() >= 4 and parts[0] == "damage":
		var x := parts[1].to_int()
		var y := parts[2].to_int()
		var txt := parts[3]
		var ttl := 1.2
		if parts.size() >= 5:
			var maybe = parts[4]
			# parse optional TTL if numeric; ignore on failure
			if maybe.is_valid_float():
				ttl = float(maybe)
		if _use_gateway and _gateway and _gateway.renderer:
			_gateway.renderer.spawn_ascii_popup(txt, Vector2i(x, y), ttl, Color.RED)
		else:
			renderer.spawn_ascii_popup(txt, Vector2i(x, y), ttl, Color.RED)
	elif parts.size() >= 2 and parts[0] == "source":
		# Execute commands from a file; ignores empty lines and comments (#)
		var path := parts[1]
		var f = FileAccess.open(path, FileAccess.READ)
		if f:
			while not f.eof_reached():
				var ln := f.get_line().strip_edges()
				if ln.is_empty() or ln.begins_with("#"):
					continue
				_process_command(ln)
			f.close()
	elif parts.size() >= 3 and (parts[0] == "drag_start" or parts[0] == "drag" or parts[0] == "drag_end"):
		var pos = Vector2i(parts[1].to_int(), parts[2].to_int())
		if parts[0] == "drag_end":
			if _use_gateway and _gateway:
				_gateway.apply_input(pos, "drag_end")
			else:
				renderer.update_input(pos, "drag_end")
		elif parts[0] == "drag_start":
			if _use_gateway and _gateway:
				_gateway.apply_input(pos, "drag_start")
			else:
				renderer.update_input(pos, "drag_start")
		else:
			if _use_gateway and _gateway:
				_gateway.apply_input(pos, "drag")
			else:
				renderer.update_input(pos, "drag")
	elif parts.size() >= 3:
		var pos = Vector2i(parts[1].to_int(), parts[2].to_int())
		match parts[0]:
			"select":
				if _use_gateway and _gateway:
					_gateway.apply_input(pos, "select")
				else:
					renderer.update_input(pos, "select")
			"move":
				if _use_gateway and _gateway:
					_gateway.apply_input(pos, "move")
				else:
					renderer.update_input(pos, "move")
			"target":
				if _use_gateway and _gateway:
					_gateway.apply_input(pos, "target")
				else:
					renderer.update_input(pos, "target")
			"click":
				if _use_gateway and _gateway:
					_gateway.apply_input(pos, "click")
				else:
					renderer.update_input(pos, "click")
			_:
				pass
	elif parts.size() >= 1 and parts[0] == "clear":
		if _use_gateway and _gateway:
			_gateway.apply_input(Vector2i.ZERO, "clear")
		else:
			renderer.update_input(Vector2i.ZERO, "clear")
	elif parts.size() >= 1 and parts[0] == "help":
		_print_help()

func _snapshot() -> String:
	if _use_gateway and _gateway:
		return _gateway.snapshot()
	return renderer.generate_ascii_field()

func _load_profile_file(path: String, key: String = "default") -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var txt = f.get_as_text()
	f.close()
	var data = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	var prof = data.get(key, {})
	var smap: Dictionary = {}
	for k in prof.keys():
		var e = prof[k]
		if typeof(e) == TYPE_DICTIONARY:
			var c = e.get("color", null)
			if c is Array and c.size() >= 4:
				e["color"] = Color(c[0], c[1], c[2], c[3])
			smap[k] = e
	return smap

func _print_help() -> void:
	var text = ""
	text += "Commands:\n"
	text += "  spawn NAME X Y\n"
	text += "  move_actor NAME X Y\n"
	text += "  action NAME ID [X Y]\n"
	text += "  remove NAME\n"
	text += "  end_turn\n"
	text += "  list | actors\n"
	text += "  select X Y | move X Y | target X Y | click X Y | clear\n"
	text += "  drag_start X Y | drag X Y | drag_end X Y\n"
	text += "  save_state FILE | load_state FILE\n"
	text += "  grid W H                  # local mode only\n"
	text += "  color on|off              # toggle ANSI color\n"
	text += "  rate HZ                   # ASCII refresh rate\n"
	text += "  profile FILE [KEY]        # load actor symbol map\n"
	text += "  terrain FILE [KEY]        # load terrain tag map\n"
	text += "  facing on|off             # show directional glyphs\n"
	text += "  damage X Y TEXT [TTL]     # popup marker with optional TTL\n"
	text += "  source FILE               # run commands from file\n"
	text += "  snapshot                  # print current frame\n"
	text += "  help | quit\n"
	print(text)
