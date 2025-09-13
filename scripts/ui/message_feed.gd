extends RichTextLabel
class_name MessageFeed

## Fixed-area message feed for interactive notices.
## - Exact 10-line viewport (computed from terminal-style font)
## - Emits meta clicks for parent UI handling

signal message_meta_clicked(meta)

@export var visible_lines := 10
@export var target_font_size := 14
@export var terminal_font_families := PackedStringArray(["Terminus", "Courier New", "DejaVu Sans Mono", "Noto Sans Mono"])  ## preference order

var _lines: Array[String] = []

func _ready() -> void:
    bbcode_enabled = true
    autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    scroll_active = false
    meta_clicked.connect(func(m): message_meta_clicked.emit(m))
    _apply_terminal_font()
    _apply_metrics()

func push_message(text_line: String) -> void:
    if text_line == null:
        return
    _lines.append(String(text_line))
    while _lines.size() > visible_lines:
        _lines.remove_at(0)
    _rebuild()

func clear_messages() -> void:
    _lines.clear()
    _rebuild()

func _rebuild() -> void:
    text = ""
    for l in _lines:
        append_text(l + "\n")

func _apply_terminal_font() -> void:
    var sf = SystemFont.new()
    sf.font_names = terminal_font_families
    add_theme_font_override("normal_font", sf)
    add_theme_font_size_override("normal_font_size", target_font_size)

func _apply_metrics() -> void:
    var f: Font = get_theme_font("normal_font")
    var size: int = get_theme_font_size("normal_font_size")
    if f == null or size <= 0:
        return
    var one = int(ceil(f.get_height(size)))
    var h = one * max(1, visible_lines)
    custom_minimum_size.y = float(h)
