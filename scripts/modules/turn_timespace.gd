extends Node
class_name TurnBasedGridTimespace

## Orchestrates initiative order, action points, and status effects for
## actors placed on a `LogicGridMap`.  A simple state machine coordinates
## the tactical round flow so UI or AI systems can subscribe via signals
## without tightly coupling to the internals.

const GRID_MAP_RES: GDScript = preload("res://scripts/grid/grid_map.gd")
const CombatRules = preload("res://scripts/game/combat_rules.gd")
const Logging = preload("res://scripts/core/logging.gd")

## --- Signals --------------------------------------------------------------

## Emitted when a new round begins.
signal round_started
## Emitted when a round ends.
signal round_ended
## All actors on a faction are defeated.
signal battle_over(faction)
## Fired at the start of an actor's turn.
## @param actor The acting object
signal turn_started(actor)
## Fired after an actor finishes its turn.
## @param actor The acting object
signal turn_ended(actor)
## Action points for an actor changed.
## @param actor The affected actor
## @param old Previous AP value
## @param new Current AP value
signal ap_changed(actor, old, new)
## An action successfully executed.
signal action_performed(actor, action_id, payload)
## Status effects applied/removed for both actors and tiles.
signal status_applied(target, status)
signal status_removed(target, status)
## Damage dealt between actors.
## @param attacker Source of the damage
## @param defender Recipient of the damage
## @param amount HP removed
signal damage_applied(attacker, defender, amount)
## Placeholder signals for future extensions.
signal reaction_triggered(actor, data)
signal timespace_snapshot_created(snapshot)

## --- State machine -------------------------------------------------------

enum State {
	IDLE, ROUND_START, ACTOR_START, ACTING, REACTION_WINDOWS, ACTOR_END, NEXT_ACTOR, ROUND_END
}
var state: State = State.IDLE

## --- Internal data -------------------------------------------------------

var grid_map: Resource
var _actors: Array = []
var _objects: Array = []
var _actor_status: Dictionary = {}
var _tile_status: Dictionary = {}
var _current_index: int = 0
var event_log: Array = []

var _actions: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _next_id: int = 0
var _overwatchers: Dictionary = {}
var _turn_id: int = 0
var reaction_watchers: Array[Callable] = []


func _init() -> void:
	_rng.seed = 1  # Deterministic across runs
	# Standard action: move one tile. Validator checks bounds and occupancy.
	register_action(
		"move",
		1,
		["movement"],
		func(actor, to: Vector2i):
			return grid_map != null and grid_map.is_in_bounds(to) and not grid_map.is_occupied(to),
		func(actor, to: Vector2i): return grid_map.move_actor(actor, to)
	)

	# Basic attack: requires clear line of sight and delegates damage
	# processing to `apply_damage`. External systems can observe the
	# resulting `damage_applied` signal for UI/AI reactions.
	register_action(
		"attack",
		1,
		["combat"],
		func(attacker, defender: Object):
			if grid_map == null:
				return false
			var a_pos = grid_map.actor_positions.get(attacker, null)
			var d_pos = grid_map.actor_positions.get(defender, null)
			return a_pos != null and d_pos != null and grid_map.has_line_of_sight(a_pos, d_pos),
		func(attacker, defender: Object):
			var dmg := 1
			if CombatRules:
				dmg = CombatRules.compute_damage(attacker, defender, grid_map)
			apply_damage(attacker, defender, dmg)
			return true
	)

	# Overwatch: consume AP to register as a watcher that may react during movement.
	register_action(
		"overwatch",
		1,
		["reaction"],
		func(actor, _payload): return true,
		func(actor, _payload):
			add_overwatcher(actor, true)
			return true
	)

## Record an event in a structured format for later replay or debugging.
func log_event(t: String, actor: Object = null, pos = null, data = null) -> void:
	Logging.log(event_log, t, actor, pos, data)


## Provide the grid map used for actor placement and movement.
func set_grid_map(map: Resource) -> void:
	grid_map = map


## --- Actor management ----------------------------------------------------


## Add an actor with initiative, action points, and optional starting position.
## @param initiative Higher values act first.
## @param tie_break Optional deterministic tie breaker.
func add_actor(
	actor: Object,
	initiative: int,
	action_points: int,
	pos: Vector2i = Vector2i.ZERO,
	tie_break: int = -1
) -> void:
	if tie_break == -1:
		tie_break = _rng.randi()
	var entry := {
		"actor": actor,
		"initiative": initiative,
		"max_ap": action_points,
		"ap": action_points,
		"tie_break": tie_break,
		"id": _next_id,
	}
	_next_id += 1
	_actors.append(entry)
	_sort_initiative()
	if grid_map:
		grid_map.move_actor(actor, pos)
		# Listen for defeated signal to automatically clean up actors.
		if actor.has_signal("defeated"):
			actor.defeated.connect(Callable(self, "remove_actor"))
	log_event("actor_added", actor, pos, {"init": initiative})


func _sort_initiative() -> void:
	_actors.sort_custom(
		func(a, b):
			if a["initiative"] != b["initiative"]:
				return a["initiative"] > b["initiative"]
			if a["tie_break"] != b["tie_break"]:
				return a["tie_break"] < b["tie_break"]
			return a["id"] < b["id"]
	)


## Register a static object that participates in the timeline.
func add_object(obj: Object, pos: Vector2i = Vector2i.ZERO) -> void:
	_objects.append(obj)
	if grid_map:
		grid_map.move_actor(obj, pos)
	log_event("object_added", obj, pos)


## Remove an actor from the timeline and grid.
func remove_actor(actor: Object) -> void:

	for i in range(_actors.size()):
		if _actors[i]["actor"] == actor:
			_actors.remove_at(i)
			if grid_map:
				grid_map.remove_actor(actor)
			if _current_index >= _actors.size():
				_current_index = 0
			break
		log_event("actor_removed", actor)
		check_battle_end()



## Expose tracked objects for inspection in tests.
func get_objects() -> Array:
	return _objects


## Determine if any faction has been eliminated and end the battle early.
func check_battle_end() -> void:
	var factions_seen: Dictionary = {}
	var factions_alive: Dictionary = {}
	for entry in _actors:
		var actor: Object = entry["actor"]
		var faction = String(actor.get("faction"))
		if faction == "":
			continue
		factions_seen[faction] = true
		if int(actor.get("HLTH")) > 0:
			factions_alive[faction] = true
	for faction in factions_seen.keys():
		if not factions_alive.has(faction):
			_set_state(State.ROUND_END)
			emit_signal("round_ended")
			log_event("round_end")
			_current_index = 0
			_set_state(State.IDLE)
			emit_signal("battle_over", faction)
			log_event("battle_over", null, null, {"faction": faction})
			return

## --- Round and turn flow -------------------------------------------------


func _set_state(s: State) -> void:
	state = s


## Reset action points and begin a new round.
func start_round() -> void:
	for entry in _actors:
		entry["ap"] = entry["max_ap"]
	_current_index = 0
	_set_state(State.ROUND_START)
	emit_signal("round_started")
	log_event("round_start")
	_tick_statuses("round_start")
	_begin_actor_turn()


func _begin_actor_turn() -> void:
	if _actors.is_empty():
		_set_state(State.ROUND_END)
		emit_signal("round_ended")
		log_event("round_end")
		return
	_turn_id += 1
	_set_state(State.ACTOR_START)
	emit_signal("turn_started", get_current_actor())
	log_event("turn_start", get_current_actor())
	_tick_statuses("turn_start", get_current_actor())
	_set_state(State.ACTING)


## Returns the actor whose turn is currently active.
func get_current_actor() -> Object:
	if _actors.is_empty():
		return null
	return _actors[_current_index]["actor"]


## Advance to the next actor in the initiative order.
func end_turn() -> void:
	if _actors.is_empty():
		return
	emit_signal("turn_ended", get_current_actor())
	log_event("turn_end", get_current_actor())
	_tick_statuses("turn_end", get_current_actor())
	_set_state(State.ACTOR_END)
	_current_index += 1
	if _current_index >= _actors.size():
		_set_state(State.ROUND_END)
		emit_signal("round_ended")
		log_event("round_end")
		_current_index = 0
		_set_state(State.IDLE)
	else:
		_set_state(State.NEXT_ACTOR)
		_begin_actor_turn()


## --- Action points & actions ---------------------------------------------


## Register an action definition.
func register_action(
	id: String,
	cost: int,
	tags: Array = [],
	validator: Callable = Callable(),
	executor: Callable = Callable()
) -> void:
	_actions[id] = {
		"cost": cost,
		"tags": tags,
		"validator": validator,
		"executor": executor,
	}


func can_perform(actor: Object, action_id: String, payload = null) -> bool:
	if not _actions.has(action_id):
		return false
	var action = _actions[action_id]
	if get_action_points(actor) < action.cost:
		return false
	if action.validator is Callable:
		return action.validator.call(actor, payload)
	return true


func perform(actor: Object, action_id: String, payload = null) -> bool:
	if not can_perform(actor, action_id, payload):
		return false
	var action = _actions[action_id]
	var ok := true
	if action.executor is Callable:
		ok = action.executor.call(actor, payload)
	if ok:
		_spend_ap(actor, action.cost, action_id)
		emit_signal("action_performed", actor, action_id, payload)
		log_event("action", actor, null, {"id": action_id, "payload": payload})
		_open_reaction_window(actor, action_id, payload)
	return ok


func _spend_ap(actor: Object, amount: int, reason: String) -> void:
	var idx := _get_actor_index(actor)
	if idx == -1:
		return
	var old = _actors[idx]["ap"]
	_actors[idx]["ap"] = max(0, old - amount)
	emit_signal("ap_changed", actor, old, _actors[idx]["ap"])
	log_event("ap_spend", actor, null, {"amt": amount, "reason": reason})


func _get_actor_index(actor: Object) -> int:
	for i in range(_actors.size()):
		if _actors[i]["actor"] == actor:
			return i
	return -1


## Remaining action points for a given actor.
func get_action_points(actor: Object) -> int:
	for entry in _actors:
		if entry["actor"] == actor:
			return entry["ap"]
	return 0


## Convenience to move the current actor using the registered move action.
func move_current_actor(to: Vector2i) -> bool:
	var actor := get_current_actor()
	var ok := perform(actor, "move", to)
	if ok:
		_check_overwatch(actor)
	return ok


## Allow external systems to observe reaction windows.
func register_reaction_watcher(cb: Callable) -> void:
	reaction_watchers.append(cb)


func _open_reaction_window(actor: Object, action_id: String, payload) -> void:
	for cb in reaction_watchers:
		if cb is Callable:
			cb.call(actor, action_id, payload)


## Apply raw damage to a defender and broadcast the result.

##
## If the defender implements an `apply_damage(amount)` method (for
## example via `BaseActor`), that method is invoked so custom defeat
## logic can run. Otherwise the helper directly manipulates an `HLTH`
## property if present. Observers can subscribe to the
## `damage_applied(attacker, defender, amount)` signal for UI or AI
## reactions.  A structured event is logged for deterministic replays.

func apply_damage(attacker: Object, defender: Object, amount: int) -> void:
	if defender == null:
		return
	if defender.has_method("apply_damage"):
		defender.apply_damage(amount)
	elif defender.get("HLTH") != null:
		defender.HLTH = max(0, defender.HLTH - amount)
	emit_signal("damage_applied", attacker, defender, amount)
	var pos = null
	if grid_map != null:
		pos = grid_map.actor_positions.get(defender, null)
	log_event("damage", attacker, pos, {"target": defender, "amount": amount})

## --- Reactions ----------------------------------------------------------


## Register an actor to react when others move into line of sight.
func add_overwatcher(actor: Object, once_per_turn: bool = true) -> void:
	_overwatchers[actor] = {"once_per_turn": once_per_turn, "reacted_turn": -1}


func _check_overwatch(moved_actor: Object) -> void:
	for watcher in _overwatchers.keys():
		if watcher == moved_actor:
			continue
		var data = _overwatchers[watcher]
		if data.get("once_per_turn", true) and data.get("reacted_turn", -1) == _turn_id:
			continue
		if grid_map:
			var w_pos = grid_map.actor_positions.get(watcher, null)
			var m_pos = grid_map.actor_positions.get(moved_actor, null)
			if w_pos != null and m_pos != null and grid_map.has_line_of_sight(w_pos, m_pos):
				data["reacted_turn"] = _turn_id
				emit_signal("reaction_triggered", watcher, {"target": moved_actor})
				log_event("reaction", watcher, null, {"target": moved_actor})
				_open_reaction_window(watcher, "overwatch", moved_actor)


## --- Status effects ------------------------------------------------------


## Apply a status effect to an actor.
func apply_status_to_actor(
	actor: Object, status: String, duration: int = 0, timing: String = "turn_start"
) -> void:
	if not _actor_status.has(actor):
		_actor_status[actor] = []
	_actor_status[actor].append({"name": status, "duration": duration, "timing": timing})
	emit_signal("status_applied", actor, status)
	log_event(
		"status_actor_add", actor, null, {"status": status, "dur": duration, "timing": timing}
	)


func get_statuses_for_actor(actor: Object) -> Array:
	var out: Array = []
	for s in _actor_status.get(actor, []):
		out.append(s["name"])
	return out


## Apply a status effect to a tile.
func apply_status_to_tile(tile: Vector2i, status: String) -> void:
	if not _tile_status.has(tile):
		_tile_status[tile] = []
	_tile_status[tile].append(status)
	emit_signal("status_applied", tile, status)
	log_event("status_tile_add", null, tile, {"status": status})


func get_statuses_for_tile(tile: Vector2i) -> Array:
	return _tile_status.get(tile, [])


## Remove a status effect from an actor or tile.
func remove_status_from_actor(actor: Object, status: String) -> void:
	if _actor_status.has(actor):
		for i in range(_actor_status[actor].size() - 1, -1, -1):
			var entry = _actor_status[actor][i]
			if entry["name"] == status:
				_actor_status[actor].remove_at(i)
				emit_signal("status_removed", actor, status)
				log_event("status_actor_remove", actor, null, {"status": status})
	if _actor_status.get(actor, []).is_empty():
		_actor_status.erase(actor)


func remove_status_from_tile(tile: Vector2i, status: String) -> void:
	if _tile_status.has(tile):
		_tile_status[tile].erase(status)
		emit_signal("status_removed", tile, status)
		log_event("status_tile_remove", null, tile, {"status": status})


func _tick_statuses(timing: String, actor: Object = null) -> void:
	## Reduce duration counters for statuses and remove expired ones.
	for target in _actor_status.keys():
		if actor != null and target != actor:
			continue
		var arr: Array = _actor_status[target]
		for i in range(arr.size() - 1, -1, -1):
			var entry = arr[i]
			if entry["timing"] == timing:
				if entry["duration"] > 0:
					entry["duration"] -= 1
				if entry["duration"] <= 0:
					var name = entry["name"]
					arr.remove_at(i)
					emit_signal("status_removed", target, name)
					log_event("status_actor_expire", target, null, {"status": name})
		if arr.is_empty():
			_actor_status.erase(target)


## --- Serialization -------------------------------------------------------


func to_dict() -> Dictionary:
	return {
		"actors": _actors,
		"objects": _objects,
		"actor_status": _actor_status,
		"tile_status": _tile_status,
		"current_index": _current_index,
		"overwatchers": _overwatchers,
		"turn_id": _turn_id,
	}


func from_dict(data: Dictionary) -> void:
	_actors = data.get("actors", [])
	_objects = data.get("objects", [])
	_actor_status = data.get("actor_status", {})
	_tile_status = data.get("tile_status", {})
	_current_index = data.get("current_index", 0)
	_overwatchers = data.get("overwatchers", {})
	_turn_id = data.get("turn_id", 0)
	_sort_initiative()


func create_snapshot() -> Dictionary:
	var snap := to_dict()
	emit_signal("timespace_snapshot_created", snap)
	log_event("snapshot")
	return snap


func serialize_event_log() -> String:
	return JSON.stringify(event_log)


func replay_event_log(json: String, handler: Callable) -> void:
	var arr = JSON.parse_string(json)
	if typeof(arr) != TYPE_ARRAY:
		return
	for evt in arr:
		handler.call(evt)


## --- Testing -------------------------------------------------------------


## Simple self-test to integrate with workspace.
func run_tests() -> Dictionary:
	var failures := 0
	var log := []

	## Initiative order & tiebreaks
	var ts1: TurnBasedGridTimespace = get_script().new()
	ts1.set_grid_map(GRID_MAP_RES.new())
	var a1 := Node.new()
	var b1 := Node.new()
	ts1.add_actor(a1, 5, 1)
	ts1.add_actor(b1, 5, 1)
	ts1.start_round()
	var a_first := ts1.get_current_actor() == a1

	var ts2: TurnBasedGridTimespace = get_script().new()
	ts2._rng.seed = 1
	ts2.set_grid_map(GRID_MAP_RES.new())
	var a2 := Node.new()
	var b2 := Node.new()
	ts2.add_actor(a2, 5, 1)
	ts2.add_actor(b2, 5, 1)
	ts2.start_round()
	var a_first2 := ts2.get_current_actor() == a2
	if a_first != a_first2:
		failures += 1
		log.append("Stable ordering failed")

	var ts3: TurnBasedGridTimespace = get_script().new()
	ts3._rng.seed = 3
	ts3.set_grid_map(GRID_MAP_RES.new())
	var a3 := Node.new()
	var b3 := Node.new()
	ts3.add_actor(a3, 5, 1)
	ts3.add_actor(b3, 5, 1)
	ts3.start_round()
	var a_first3 := ts3.get_current_actor() == a3
	var ties1 := [ts1._actors[0]["tie_break"], ts1._actors[1]["tie_break"]]
	var ties3 := [ts3._actors[0]["tie_break"], ts3._actors[1]["tie_break"]]
	if a_first == a_first3 or ties1 == ties3:
		failures += 1
		log.append("Different seed produced same order")

	# Free instances from initiative tests
	ts1.free()
	ts2.free()
	ts3.free()
	a1.free()
	b1.free()
	a2.free()
	b2.free()
	a3.free()
	b3.free()

	## AP spend & rejection
	var ts_ap: TurnBasedGridTimespace = get_script().new()
	ts_ap.set_grid_map(GRID_MAP_RES.new())
	var ap_actor := Node.new()
	ts_ap.add_actor(ap_actor, 5, 1)
	ts_ap.start_round()
	var ap_changes := []
	ts_ap.ap_changed.connect(func(actor, old, new): ap_changes.append(1))
	var ok1 := ts_ap.move_current_actor(Vector2i(1, 0))
	var ok2 := ts_ap.move_current_actor(Vector2i(2, 0))
	if not ok1 or ok2 or ap_changes.size() != 1:
		failures += 1
		log.append("AP spend/rejection failed")

	ts_ap.free()
	ap_actor.free()

	## Attack action & damage (use BaseActor for stable props)
	var ts_atk: TurnBasedGridTimespace = get_script().new()
	var atk_grid: Resource = GRID_MAP_RES.new()
	ts_atk.set_grid_map(atk_grid)
	var actor_class = preload("res://scripts/core/base_actor.gd")
	var attacker = actor_class.new("atk")
	var defender = actor_class.new("dfd")
	defender.HLTH = 2
	ts_atk.add_actor(attacker, 10, 2, Vector2i.ZERO)
	ts_atk.add_actor(defender, 5, 1, Vector2i(3, 0))
	atk_grid.set_los_blocker(Vector2i(1, 0), true)
	ts_atk.start_round()
	var blocked := not ts_atk.perform(attacker, "attack", defender)
	atk_grid.set_los_blocker(Vector2i(1, 0), false)
	var dmg_calls := []
	ts_atk.damage_applied.connect(func(a, d, amt): dmg_calls.append(amt))
	var success := ts_atk.perform(attacker, "attack", defender)
	var hp_down: bool = defender.HLTH == 1
	if not blocked or not success or not hp_down or dmg_calls.size() != 1:
		failures += 1
		log.append("Attack action failed")

	ts_atk.free()
	attacker.free()
	defender.free()

	## Move→overwatch
	var ts_ow: TurnBasedGridTimespace = get_script().new()
	var grid2: Resource = GRID_MAP_RES.new()
	ts_ow.set_grid_map(grid2)
	var mover := Node.new()
	var watcher := Node.new()
	ts_ow.add_actor(watcher, 1, 1, Vector2i.ZERO)
	ts_ow.add_actor(mover, 10, 2, Vector2i(3, 0))
	ts_ow.add_overwatcher(watcher, true)
	var reacts := []
	ts_ow.reaction_triggered.connect(func(actor, data): reacts.append(1))
	ts_ow.start_round()
	ts_ow.move_current_actor(Vector2i(2, 0))
	ts_ow.move_current_actor(Vector2i(1, 0))
	if reacts.size() != 1:
		failures += 1
		log.append("Overwatch reaction failed")

	ts_ow.free()
	mover.free()
	watcher.free()

	## Attack resolution
	var ts_atk2: TurnBasedGridTimespace = get_script().new()
	var grid_atk: Resource = GRID_MAP_RES.new()
	ts_atk2.set_grid_map(grid_atk)
	var actor_res := preload("res://scripts/core/base_actor.gd")
	var atk := actor_res.new()
	var dfd := actor_res.new()
	atk.set_meta("ACC", 200)  # guarantee 100% base accuracy
	ts_atk2.add_actor(atk, 10, 1, Vector2i.ZERO)
	ts_atk2.add_actor(dfd, 5, 1, Vector2i(1, 0))
	ts_atk2.start_round()
	var hp_before := dfd.HLTH
	var hit_ok := ts_atk2.perform(atk, "attack", dfd)
	var hp_after := dfd.HLTH
	if not hit_ok or hp_after != hp_before - 1:
		failures += 1
		log.append("Attack action failed")
	ts_atk2.free()
	atk.free()
	dfd.free()

	## Status durations
	var ts_status: TurnBasedGridTimespace = get_script().new()
	ts_status.set_grid_map(GRID_MAP_RES.new())
	var act := Node.new()
	ts_status.add_actor(act, 5, 1)
	ts_status.apply_status_to_actor(act, "burn", 1, "turn_end")
	ts_status.start_round()
	if "burn" not in ts_status.get_statuses_for_actor(act):
		failures += 1
		log.append("Status not applied")
	ts_status.end_turn()
	if "burn" in ts_status.get_statuses_for_actor(act):
		failures += 1
		log.append("Status did not expire on turn_end")
	ts_status.apply_status_to_actor(act, "regen", 1, "round_start")
	ts_status.start_round()
	if "regen" in ts_status.get_statuses_for_actor(act):
		failures += 1
		log.append("Round_start status did not expire")

	ts_status.free()
	act.free()

	## Reaction watcher
	var ts_react: TurnBasedGridTimespace = get_script().new()
	ts_react.set_grid_map(GRID_MAP_RES.new())
	var rw_actor := Node.new()
	ts_react.add_actor(rw_actor, 5, 1)
	var triggered := [false]
	ts_react.register_reaction_watcher(func(a, id, payload): triggered[0] = true)
	ts_react.start_round()
	ts_react.move_current_actor(Vector2i(1,0))
	if not triggered[0]:
		failures += 1
		log.append("Reaction watcher not triggered")
	ts_react.free()
	rw_actor.free()

	## Serialization
	var ts_ser: TurnBasedGridTimespace = get_script().new()
	ts_ser.set_grid_map(GRID_MAP_RES.new())
	var s_a := Node.new()
	var s_b := Node.new()
	ts_ser.add_actor(s_a, 10, 2)
	ts_ser.add_actor(s_b, 5, 2)
	ts_ser.apply_status_to_actor(s_a, "poison", 1, "turn_start")
	ts_ser.start_round()
	ts_ser.move_current_actor(Vector2i(1, 0))
	var snap := ts_ser.create_snapshot()
	var restored: TurnBasedGridTimespace = get_script().new()
	restored.set_grid_map(GRID_MAP_RES.new())
	restored.from_dict(snap)
	if restored.get_current_actor() != ts_ser.get_current_actor() or restored.get_action_points(s_a) != ts_ser.get_action_points(s_a) or restored.get_statuses_for_actor(s_a) != ts_ser.get_statuses_for_actor(s_a):
		failures += 1
		log.append("Serialization failed")

	ts_ser.free()
	restored.free()
	s_a.free()
	s_b.free()

	## Event log schema
	var ts_log: TurnBasedGridTimespace = get_script().new()
	ts_log.set_grid_map(GRID_MAP_RES.new())
	var log_actor := Node.new()
	ts_log.add_actor(log_actor, 5, 1)
	ts_log.start_round()
	ts_log.move_current_actor(Vector2i(1, 0))
	var first_evt = ts_log.event_log[0]
	if not (first_evt.has("t") and first_evt.has("actor") and first_evt.has("pos")):
		failures += 1
		log.append("Structured event missing fields")
	for e in ts_log.event_log:
		if typeof(e) != TYPE_DICTIONARY or not e.has("t"):
			failures += 1
			log.append("Event missing key")
			break

	var json := ts_log.serialize_event_log()
	var replayed: Array = []
	ts_log.replay_event_log(json, func(evt): replayed.append(evt))
	if replayed.size() != ts_log.event_log.size():
		failures += 1
		log.append("Event log replay mismatch")

	ts_log.free()
	log_actor.free()

	return {
		"failed": failures,
		"total": 9,
		"log": "\n".join(log),
	}
