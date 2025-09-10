extends CanvasLayer
class_name AbilityHotbar

@export var services_path: NodePath
@onready var services = get_node_or_null(services_path)
@onready var bar: HBoxContainer = $Panel/Margin/HBox

var current_actor: Object = null
var on_attack_request: Callable
var _timespace

func _ready() -> void:
    if services == null:
        push_warning("AbilityHotbar: services_path not set")

func set_actor(actor: Object) -> void:
    current_actor = actor
    if services == null and services_path != NodePath(""):
        services = get_node_or_null(services_path)
    if services:
        _timespace = services.timespace
    _rebuild()

func set_attack_handler(cb: Callable) -> void:
    on_attack_request = cb

func _rebuild() -> void:
    for c in bar.get_children():
        c.queue_free()
    if services == null or current_actor == null:
        return
    var ids: Array[String] = services.loadouts.get_available(current_actor)
    for id in ids:
        var b := Button.new()
        b.text = id
        b.disabled = not _can_use(id)
        b.pressed.connect(func(): _on_ability_pressed(id))
        bar.add_child(b)

func _can_use(id: String) -> bool:
    if current_actor == null or services == null:
        return false
    if id == "attack_basic":
        return _timespace != null and _timespace.get_action_points(current_actor) > 0
    if id == "overwatch":
        return _timespace != null and _timespace.can_perform(current_actor, "overwatch", null)
    # Pass null attrs to allow simple abilities; advanced checks can use services.attributes
    return services.abilities.can_use(current_actor, id, null)

func _on_ability_pressed(id: String) -> void:
    if id == "attack_basic":
        if on_attack_request and on_attack_request.is_valid():
            on_attack_request.call()
        return
    # Otherwise try to execute immediately without a payload
    if id == "overwatch" and _timespace:
        if _timespace.can_perform(current_actor, "overwatch", null):
            _timespace.perform(current_actor, "overwatch", null)
            # Mark status flag for simple visual overlay
            if current_actor.get("STS") != null:
                current_actor.STS = int(current_actor.STS) | 1
    else:
        services.abilities.execute(current_actor, id, null, null)
    _rebuild()
