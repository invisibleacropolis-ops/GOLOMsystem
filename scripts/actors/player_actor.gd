extends "res://scripts/core/base_actor.gd"
class_name PlayerActor

## Controllable actor driven by player input.
## Uses RuntimeServices to move across the grid during its turn.

var runtime
var weapon_name: String = "Sword"

# BaseActor already defines `mesh_kind`; removing duplicate prevents
# "member already exists" parse errors when loading the script.

func _unhandled_input(event: InputEvent) -> void:
    if runtime == null:
        return
    if runtime.timespace.get_current_actor() != self:
        return
    var dir := Vector2i.ZERO
    if event.is_action_pressed("ui_up"):
        dir = Vector2i.UP
    elif event.is_action_pressed("ui_down"):
        dir = Vector2i.DOWN
    elif event.is_action_pressed("ui_left"):
        dir = Vector2i.LEFT
    elif event.is_action_pressed("ui_right"):
        dir = Vector2i.RIGHT
    if dir == Vector2i.ZERO:
        return
    var pos: Vector2i = runtime.grid_map.actor_positions.get(self, Vector2i.ZERO)
    var target = pos + dir
    if runtime.timespace.move_current_actor(target):
        runtime.timespace.end_turn()
