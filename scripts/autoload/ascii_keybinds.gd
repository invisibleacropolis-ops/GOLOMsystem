extends Node

@export var enabled := true
@export var select_key := KEY_ENTER
@export var clear_key := KEY_C
@export var target_key := KEY_T
@export var click_key := KEY_SPACE

func _unhandled_input(event: InputEvent) -> void:
    if not enabled:
        return
    var gw = get_tree().get_root().get_node_or_null("/root/AsciiGateway")
    if gw == null:
        return
    if event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_W:
                gw.apply_input(Vector2i(0, -1), "move")
            KEY_S:
                gw.apply_input(Vector2i(0, 1), "move")
            KEY_A:
                gw.apply_input(Vector2i(-1, 0), "move")
            KEY_D:
                gw.apply_input(Vector2i(1, 0), "move")
            select_key:
                gw.apply_input(Vector2i.ZERO, "select")
            clear_key:
                gw.apply_input(Vector2i.ZERO, "clear")
            target_key:
                gw.apply_input(Vector2i.ZERO, "target")
            click_key:
                gw.apply_input(Vector2i.ZERO, "click")

