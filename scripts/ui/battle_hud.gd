extends CanvasLayer
class_name BattleHUD

## Lightweight HUD for turn-based battles.
## Provides ability buttons that directly call into
## Abilities or the TurnBasedGridTimespace module.

@export var services_path: NodePath
@onready var services = get_node_or_null(services_path)
@onready var attack_button: Button = $Root/AttackButton
@onready var overwatch_button: Button = $Root/OverwatchButton

## Currently acting unit and optional attack target.
var current_actor: Object = null
var current_target: Object = null

## Emitted when the user wishes to select an attack target.
signal attack_requested

func _ready() -> void:
    attack_button.pressed.connect(_on_attack_pressed)
    overwatch_button.pressed.connect(_on_overwatch_pressed)

func set_actor(actor: Object) -> void:
    current_actor = actor
    _refresh_buttons()

func set_target(target: Object) -> void:
    current_target = target
    _refresh_buttons()

func _refresh_buttons() -> void:
    if services == null or current_actor == null:
        attack_button.disabled = true
        overwatch_button.disabled = true
        return
    var ts = services.timespace
    attack_button.disabled = not ts.can_perform(current_actor, "attack", current_target)
    overwatch_button.disabled = not services.abilities.can_use(current_actor, "overwatch", null)

func _on_attack_pressed() -> void:
    if services == null or current_actor == null:
        return
    var ts = services.timespace
    if current_target != null and ts.can_perform(current_actor, "attack", current_target):
        ts.perform(current_actor, "attack", current_target)
        current_target = null
        _refresh_buttons()
    else:
        emit_signal("attack_requested")

func _on_overwatch_pressed() -> void:
    if services == null or current_actor == null:
        return
    if services.abilities.can_use(current_actor, "overwatch", null):
        services.abilities.execute(current_actor, "overwatch", null, null)
        _refresh_buttons()
