extends Control
class_name CharBattleHUD

## Displays vital statistics for the active actor during battle.
##
## This floating panel queries the `RuntimeServices` singleton to fetch
## health (HP), chi/magic (MP), available abilities, and any active status
## effects for the actor whose turn is currently active.  It refreshes on a
## short interval so external systems do not need to manually push updates.

@export var services_path: NodePath

@onready var services: Node = get_node_or_null(services_path)
@onready var name_label: Label = $HBox/Name
@onready var hp_label: Label = $HBox/HP
@onready var mp_label: Label = $HBox/MP
@onready var status_label: Label = $HBox/Status
@onready var ability_label: Label = $HBox/Abilities

var _actor: Object = null
var _accum := 0.0

func _ready() -> void:
	"""Resolve the runtime services lazily if not wired in the scene."""
	if services == null:
		services = get_tree().get_root().get_node_or_null("/root/VerticalSlice/Runtime")
	set_process(true)

func _process(delta: float) -> void:
	_accum += delta
	if _accum < 0.25:
		return
	_accum = 0.0
	if services == null or services.get("timespace") == null:
		return
	var actor = services.timespace.get_current_actor()
	if actor != _actor:
		_actor = actor
	_refresh()

func _refresh() -> void:
	"""Pull data from runtime services and populate the panel."""
	if _actor == null:
		name_label.text = ""
		hp_label.text = ""
		mp_label.text = ""
		status_label.text = ""
		ability_label.text = ""
		return
	var name := String(_actor.get("name"))
	var hp := int(_actor.get("HLTH"))
	var mp := int(_actor.get("CHI"))
	name_label.text = name
	hp_label.text = "HP:%d" % hp
	mp_label.text = "MP:%d" % mp
	var statuses: Array = []
	if services and services.get("statuses") != null:
		var dict: Dictionary = services.statuses.actor_statuses.get(_actor, {})
		for id in dict.keys():
			statuses.append(String(id))
	status_label.text = "Status: " + (", ".join(statuses) if statuses.size() > 0 else "None")
	var abilities: Array[String] = []
	if services and services.get("loadouts") != null:
		abilities = services.loadouts.get_available(_actor)
	ability_label.text = "Abilities: " + (", ".join(abilities) if abilities.size() > 0 else "None")
