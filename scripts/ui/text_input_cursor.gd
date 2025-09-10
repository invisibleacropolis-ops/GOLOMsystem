extends LineEdit
class_name TextInputCursor

## Endless text input cursor sized to exactly N monospace characters.
## Uses a terminal-style SystemFont by default and computes width
## from font metrics so the visible field shows `target_chars` columns.

@export var target_chars := 20
@export var target_font_size := 14
@export var terminal_font_families := PackedStringArray(["Terminus", "Courier New", "DejaVu Sans Mono", "Noto Sans Mono"])  ## preference order

func _ready() -> void:
    caret_blink = true
    context_menu_enabled = true
    secret = false
    max_length = 0  # unlimited
    _apply_terminal_font()
    _apply_width()

func _apply_terminal_font() -> void:
    var sf = SystemFont.new()
    sf.font_names = terminal_font_families
    add_theme_font_override("font", sf)
    add_theme_font_size_override("font_size", target_font_size)

func _apply_width() -> void:
    var f: Font = get_theme_font("font")
    var size: int = get_theme_font_size("font_size")
    if f == null or size <= 0:
        return
    # Estimate width of one monospace cell using "W" as a wide glyph.
    var one = int(ceil(f.get_string_size("W", size).x))
    var w = max(1, target_chars) * max(1, one)
    custom_minimum_size.x = float(w)
    # Propagate width to parent MsgPane so the whole left area matches 20 chars.
    var pane = get_parent()
    if pane and pane is Control:
        pane.custom_minimum_size.x = float(w)
        var pane2 = pane.get_parent()
        if pane2 and pane2 is Control:
            pane2.custom_minimum_size.x = float(w)
    # Ensure a single-line height for the input row.
    var h_one = int(ceil(f.get_height(size)))
    custom_minimum_size.y = float(h_one)
