extends Node2D
class_name GPULabelBatcher

@export var font: Font
var _commands: Array = []

func begin() -> void:
    _commands.clear()

func push(text: String, pos: Vector2, color: Color = Color.WHITE) -> void:
    _commands.append({"t": text, "p": pos, "c": color})

func end() -> void:
    queue_redraw()

func _draw() -> void:
    if not font:
        return
    for cmd in _commands:
        draw_string(font, cmd.p, cmd.t, HORIZONTAL_ALIGNMENT_CENTER, -1, cmd.c)
