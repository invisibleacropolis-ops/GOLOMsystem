extends Panel
class_name VariableDisplay

## Displays runtime statistics such as current round and active actor.
## External modules may register additional stats with custom
## formatting via `register_stat()`.

@onready var _grid: GridContainer = $Stats

var _runtime
var _round: int = 0
var _active_actor: String = ""
var _ap: int = 0

var _stats := {}


func _ready() -> void:
    _runtime = get_tree().root.get_node_or_null("Runtime")
    if _runtime and _runtime.timespace:
        _runtime.timespace.round_started.connect(_on_round_started)
        _runtime.timespace.turn_started.connect(_on_turn_started)
        _runtime.timespace.ap_changed.connect(_on_ap_changed)
    register_stat("Round", func(): return _round)
    register_stat("Active Actor", func(): return _active_actor)
    register_stat("AP", func(): return _ap)


func _on_round_started() -> void:
    _round += 1
    _update_stat("Round")


func _on_turn_started(actor) -> void:
    _active_actor = actor.name if actor is Node else str(actor)
    if _runtime and _runtime.timespace:
        _ap = _runtime.timespace.get_action_points(actor)
    _update_stat("Active Actor")
    _update_stat("AP")

func _on_ap_changed(actor, old, new) -> void:
    if _runtime and _runtime.timespace and actor == _runtime.timespace.get_current_actor():
        _ap = int(new)
        _update_stat("AP")


func register_stat(label: String, getter: Callable, formatter: Callable = Callable()) -> void:
    ## Register a stat for display.
    var name_label := Label.new()
    name_label.text = label + ":"
    var value_label := Label.new()
    _grid.add_child(name_label)
    _grid.add_child(value_label)
    _stats[label] = {
        "getter": getter,
        "formatter": formatter,
        "label": value_label,
    }
    _update_stat(label)


func _update_stat(label: String) -> void:
    var entry = _stats.get(label)
    if entry:
        var value = entry.get("getter").call()
        var formatter: Callable = entry.get("formatter")
        entry.label.text = formatter.call(value) if formatter.is_valid() else str(value)


func update_all() -> void:
    for name in _stats.keys():
        _update_stat(name)


static func format_number(n: float, decimals: int = 2) -> String:
    ## Format a floating-point number with fixed decimals.
    return "%0.*f" % [decimals, n]


static func format_percent(n: float, decimals: int = 0) -> String:
    ## Format a value as a percentage.
    return "%0.*f%%" % [decimals, n * 100]
