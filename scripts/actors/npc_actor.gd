extends "res://scripts/core/base_actor.gd"
class_name NpcActor

## Non-combatant NPC that slowly wanders using a timer.
var runtime

func _ready() -> void:
    if runtime:
        runtime.timespace.turn_started.connect(_on_turn_started)

func _on_turn_started(actor: Object) -> void:
    if actor != self:
        return
    await get_tree().create_timer(1.0).timeout
    var choices = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.ZERO]
    choices.shuffle()
    var pos: Vector2i = runtime.grid_map.actor_positions.get(self, Vector2i.ZERO)
    for dir in choices:
        var target = pos + dir
        if runtime.timespace.move_current_actor(target):
            runtime.timespace.end_turn()
            return
    runtime.timespace.end_turn()
