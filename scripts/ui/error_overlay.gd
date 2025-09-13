extends CanvasLayer
class_name ErrorOverlay

@export var visible_lines := 6
@export var paused := false

var _lines: Array[String] = []

func _ready() -> void:
    layer = 100
    if not has_node("Panel"):
        var p = Panel.new()
        p.name = "Panel"
        p.offset_left = 8
        p.offset_top = 8
        p.offset_right = 520
        p.offset_bottom = 8 + 18 * visible_lines + 16
        add_child(p)
        var hb = HBoxContainer.new()
        hb.name = "Toolbar"
        hb.offset_left = 8
        hb.offset_top = 4
        hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        p.add_child(hb)
        var btn_pause = Button.new(); btn_pause.text = "Pause"; hb.add_child(btn_pause)
        var btn_clear = Button.new(); btn_clear.text = "Clear"; hb.add_child(btn_clear)
        var btn_save = Button.new(); btn_save.text = "Save"; hb.add_child(btn_save)
        btn_pause.pressed.connect(func(): paused = !paused)
        btn_clear.pressed.connect(func(): _lines.clear(); _rebuild())
        btn_save.pressed.connect(func():
            var hub = get_tree().root.get_node_or_null("/root/ErrorHub")
            var out = ""
            if hub: out = hub.export_to_file()
            var dbg = get_tree().root.get_node_or_null("/root/WorkspaceDebugger")
            if dbg and out != "": dbg.log_info("Saved error snapshot to: %s" % out)
        )
        var lbl = RichTextLabel.new()
        lbl.name = "Log"
        lbl.bbcode_enabled = true
        lbl.fit_content = true
        lbl.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
        lbl.scroll_active = true
        lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
        lbl.offset_left = 8
        lbl.offset_top = 28
        lbl.offset_right = 8
        lbl.offset_bottom = 8
        p.add_child(lbl)
    var hub = get_tree().root.get_node_or_null("/root/ErrorHub")
    if hub:
        hub.entry_added.connect(func(e): _on_log(String(e.get("msg","")), String(e.get("level","info"))) )
    else:
        var dbg = get_tree().get_root().get_node_or_null("/root/WorkspaceDebugger")
        if dbg:
            dbg.log_emitted.connect(_on_log)

func _on_log(message: String, level: String) -> void:
    if paused:
        return
    var color = "#ffffff"
    if level == "warn": color = "#ffcc66"
    if level == "error": color = "#ff6666"
    _lines.append("[color=%s]%s[/color]" % [color, message])
    while _lines.size() > visible_lines:
        _lines.remove_at(0)
    _rebuild()

func _rebuild() -> void:
    var lbl: RichTextLabel = $Panel/Log
    if lbl == null:
        return
    lbl.text = ""
    for l in _lines:
        lbl.append_text(l + "\n")
