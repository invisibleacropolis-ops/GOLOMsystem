extends Panel

## Enforces a square minimap frame anchored to the bottom of the right pane.

@onready var _frame: Panel = $MiniVBox/MiniFrame

func _ready() -> void:
    _resize_square()
    if has_signal("resized"):
        resized.connect(_resize_square)

func _resize_square() -> void:
    if _frame == null:
        return
    var pad_left := 8.0
    var pad_right := 8.0
    var available_w := max(0.0, size.x - (pad_left + pad_right))
    var target := available_w
    # Cap by available height in this panel
    var pad_top := 8.0
    var pad_bottom := 8.0
    var available_h := max(0.0, size.y - (pad_top + pad_bottom))
    if target > available_h:
        target = available_h
    # Enforce exact square by setting minimum and removing expansion flags.
    _frame.custom_minimum_size = Vector2(target, target)
    _frame.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
    _frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
