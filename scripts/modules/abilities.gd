extends Node
class_name Abilities


class DummyActor:
	var HLTH: int = 0


const Logging = preload("res://scripts/core/logging.gd")
const CombatRules = preload("res://scripts/game/combat_rules.gd")

## Validates requirements and executes ordered effect lists.
## This stub only tracks ability registration and logs execution
## without performing any real game logic.

var catalog: Dictionary = {}
var cooldowns: Dictionary = {}
var event_log: Array = []
## Optional reference to the shared EventBus for cross-module logs
var event_bus: Node = null

## Emitted whenever an ability reduces a target's HP.
## @param attacker Ability user
## @param defender Target affected
## @param amount HP removed
signal damage_applied(attacker, defender, amount)


func log_event(t: String, actor: Object = null, pos = null, data = null) -> void:
        Logging.log(event_log, t, actor, pos, data)
        if event_bus != null:
                var payload: Dictionary = {}
                if actor != null:
                        payload["actor"] = actor
                if pos != null:
                        payload["pos"] = pos
                if data != null:
                        if typeof(data) == TYPE_DICTIONARY:
                                for k in data.keys():
                                        payload[k] = data[k]
                        else:
                                payload["value"] = data
                event_bus.push({"t": t, "data": payload})


func register_ability(id: String, data: Dictionary) -> void:
	catalog[id] = data


## Load ability definitions from a JSON file at `path`.
func load_from_file(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var parsed = JSON.parse_string(file.get_as_text())
		if typeof(parsed) == TYPE_DICTIONARY:
			for id in parsed.keys():
				register_ability(id, parsed[id])


## Decrement all cooldown counters by one. Should be called each round.
func tick_cooldowns() -> void:
	for actor in cooldowns.keys():
		for id in cooldowns[actor].keys():
			cooldowns[actor][id] = max(0, cooldowns[actor][id] - 1)


func can_use(actor: Object, id: String, attrs = null) -> bool:
	if not catalog.has(id):
		return false
	var cd = cooldowns.get(actor, {}).get(id, 0)
	if cd > 0:
		return false
	if attrs:
		var def = catalog[id]
		if def.get("act_cost", 0) > attrs.get_value(actor, "ACT"):
			return false
		if def.get("chi_cost", 0) > attrs.get_value(actor, "CHI"):
			return false
	return true


## Execute ability `id` from `actor` against `target`.
## Optionally accepts attribute data and the current grid map for
## advanced damage computation.
func execute(actor: Object, id: String, target, attrs = null, grid_map = null) -> Array:
	if not can_use(actor, id, attrs):
		return []
	var def = catalog[id]
	if attrs:
		attrs.add_modifier(actor, "ACT", -def.get("act_cost", 0), 1.0, "ability_%s" % id)
		attrs.add_modifier(actor, "CHI", -def.get("chi_cost", 0), 1.0, "ability_%s" % id)
	if not cooldowns.has(actor):
		cooldowns[actor] = {}
	cooldowns[actor][id] = def.get("cooldown", 0)
	log_event("ability", actor, null, {"id": id, "target": target})
	for effect in def.get("effects", []):
		if effect == "damage" and target != null:
			# Legacy branch for simple flat damage abilities.
			if target.has_method("apply_damage"):
				target.apply_damage(1)
			elif target.get("HLTH") != null:
				target.HLTH = max(0, target.HLTH - 1)
			emit_signal("damage_applied", actor, target, 1)
		elif effect == "deal_damage" and target != null:
			var dmg: int = int(def.get("damage_amount", 0))
			if CombatRules and grid_map != null:
				var base := CombatRules.compute_damage(actor, target, grid_map)
				dmg = base * def.get("damage_amount", 1)
			if target.has_method("apply_damage"):
				target.apply_damage(dmg)
			elif target.get("HLTH") != null:
				target.HLTH = max(0, target.HLTH - dmg)
			emit_signal("damage_applied", actor, target, dmg)
	return def.get("follow_up", [])


func run_tests() -> Dictionary:
        load_from_file("res://data/actions.json")
        var attacker := DummyActor.new()
        var target := DummyActor.new()
        target.HLTH = 2
        var attrs_script := ResourceLoader.load(
                "res://scripts/modules/attributes.gd", "", ResourceLoader.CacheMode.CACHE_MODE_IGNORE
        )
        var attrs = attrs_script.new()
        attrs.set_base(attacker, "ACT", 2)
        attrs.set_base(attacker, "CHI", 2)
        var bus_script := ResourceLoader.load(
                "res://scripts/modules/event_bus.gd", "", ResourceLoader.CacheMode.CACHE_MODE_IGNORE
        )
        var bus = bus_script.new()
        event_bus = bus
        var dmg_calls := []
        damage_applied.connect(func(a, d, amt): dmg_calls.append(amt))
        var follow = execute(attacker, "strike", target, attrs)
        var hp_down: bool = target.get("HLTH") == 1 and dmg_calls.size() == 1
        var on_cd = can_use(attacker, "strike", attrs) == false
        tick_cooldowns()
        var cd_ready = can_use(attacker, "strike", attrs)
        var evt = event_log[0]
        var structured = (
                evt.get("t", "") == "ability"
                and evt.get("actor") == attacker
                and evt.get("data", {}).get("id") == "strike"
        )
        var bus_evt = bus.entries[0]
        var bus_structured = (
                bus_evt.get("t", "") == "ability"
                and bus_evt.get("data", {}).get("actor") == attacker
                and bus_evt.get("data", {}).get("id") == "strike"
        )
        # Clean up test instances to avoid resource leaks in headless runs
        attrs.free()
        attrs = null
        attrs_script = null
        bus.free()
        event_bus = null
        return {
                "failed":
                0 if (follow.has("combo_finish") and on_cd and cd_ready and structured and bus_structured and hp_down) else 1,
                "total": 1,
                "log": "json load & cooldown",
        }
