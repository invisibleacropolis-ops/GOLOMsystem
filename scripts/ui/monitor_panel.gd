## Panel displaying high-level battle information for debugging and QA.
## Shows battle state, current round/turn, and actor counts by faction.
extends Control
class_name MonitorPanel

## Optional path to RuntimeServices if a custom location is used.
@export var services_path: NodePath

@onready var services: Node = get_node_or_null(services_path)
@onready var status_label: Label = $VBox/BattleStatus
@onready var round_label: Label = $VBox/RoundInfo
@onready var actor_label: Label = $VBox/ActorCounts

## Internal counters updated from EventBus events.
var _round: int = 0
var _turn: int = 0

func _ready() -> void:
    if services == null:
        services = get_tree().get_root().get_node_or_null("/root/VerticalSlice/Runtime")
    if services and services.get("event_bus") != null:
        var bus = services.get("event_bus")
        if bus and bus.has_signal("event_pushed"):
            bus.event_pushed.connect(_on_event)
    _refresh_actor_counts()

func _on_event(evt: Dictionary) -> void:
    var t := String(evt.get("t", ""))
    match t:
        "battle_begins":
            status_label.text = "Battle: in progress"
            _round = 0
            _turn = 0
        "round_start":
            _round += 1
            _turn = 0
        "turn_start":
            _turn += 1
        "battle_over":
            var fac = evt.get("data", {}).get("faction", "")
            status_label.text = "Battle over – %s won" % fac
    # Update counts for turn/round changes or when actors enter/leave.
    if t in ["battle_begins", "round_start", "turn_start", "battle_over", "actor_added", "actor_removed", "damage"]:
        _refresh_actor_counts()
    round_label.text = "Round: %d, Turn: %d" % [_round, _turn]

func _refresh_actor_counts() -> void:
    if services and services.get("grid_map") != null:
        var counts := {}
        for a in services.grid_map.get_all_actors():
            var fac := String(a.get("faction"))
            counts[fac] = int(counts.get(fac, 0)) + 1
        var parts: Array[String] = []
        for k in counts.keys():
            parts.append("%s: %d" % [k, counts[k]])
        actor_label.text = "Actors: " + ", ".join(parts)
    else:
        actor_label.text = "Actors: n/a"
