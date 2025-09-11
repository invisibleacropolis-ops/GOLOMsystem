extends CanvasLayer
class_name MainGUI

@export var services_path: NodePath
@export var controller_path: NodePath

@onready var services = get_node_or_null(services_path)
@onready var controller = get_node_or_null(controller_path)
@onready var event_log: Node = $Root/LeftPane/EventLog/Body/Scroll/Log
@onready var msg_feed: Node = $Root/LeftPane/EventLog/Body/MsgPane/MsgVBox/Msg
@onready var msg_input: LineEdit = $Root/LeftPane/EventLog/Body/MsgPane/MsgVBox/Input
@onready var msg_header: RichTextLabel = $Root/LeftPane/EventLog/Body/MsgPane/MsgVBox/Header
@onready var right_scroll: ScrollContainer = $Root/LeftPane/EventLog/Body/Scroll
@onready var left_pane: Control = $Root/LeftPane/EventLog/Body/MsgPane
@onready var inspector: Panel = $Root/RightPane/Inspector

func _ready() -> void:
    if services == null:
        services = get_tree().get_root().get_node_or_null("/root/VerticalSlice/Runtime")
    if services and services.get("event_bus") != null:
        var bus = services.get("event_bus")
        if bus and bus.has_signal("event_pushed"):
            bus.event_pushed.connect(_on_event)
            _dbg("MainGUI: connected to EventBus")
    # Provide services path to the event log humanizer if supported
    if event_log and event_log.has_method("configure_services"):
        event_log.configure_services(services.get_path() if services else NodePath(""))
    # Seed message feed with placeholder notes; future messages can be clickable.
    if msg_feed and msg_feed.has_method("push_message"):
        msg_feed.push_message("[b]Tips[/b]: Use Attack or Overwatch.")
        msg_feed.push_message("Grid: [i]32×32[/i]; Camera: isometric.")
        msg_feed.push_message("[url=help:controls]View Controls[/url] · [url=replay:last]Replay Last Turn[/url]")
    # Connect meta click handlers
    if msg_feed and msg_feed.has_signal("message_meta_clicked"):
        msg_feed.message_meta_clicked.connect(_on_msg_meta_clicked)
    if event_log and event_log.has_signal("meta_clicked"):
        event_log.meta_clicked.connect(_on_log_meta_clicked)
    if msg_input:
        msg_input.text_submitted.connect(_on_msg_input_submit)
    if msg_header:
        msg_header.meta_clicked.connect(_on_header_meta_clicked)
    # Lock heights between left (header+msg+input) and right (10 lines)
    call_deferred("_lock_heights")
    # Visual heartbeat in the log to confirm rendering
    if event_log and event_log is RichTextLabel:
        (event_log as RichTextLabel).append_text("[color=#88f]Event log online[/color]\n")
    # Inspector close wiring
    if inspector and inspector.has_node("VBox/Close"):
        inspector.get_node("VBox/Close").connect("pressed", func(): inspector.visible = false)
    # Toggle debug overlays (SliceDebug + ErrorOverlay) via UI button
    if has_node("Root/RightPane/Utility/UtilityVBox/Buttons/ToggleDebug"):
        $Root/RightPane/Utility/UtilityVBox/Buttons/ToggleDebug.pressed.connect(_toggle_debug_overlays)

func _on_msg_meta_clicked(meta):
    # Stub actions: route to help or trigger simple behaviors.
    if typeof(meta) == TYPE_STRING:
        if String(meta).begins_with("help:"):
            if event_log and event_log.has_method("append_text"):
                event_log.append_text("[color=#88f][i]Showing help for %s[/i][/color]\n" % String(meta).substr(5))
        elif String(meta) == "replay:last":
            if services and services.get("event_bus"):
                var json = services.event_bus.serialize()
                event_log.append_text("[color=#8f8][i]Replaying last log snapshot (%d events)[/i][/color]\n" % JSON.parse_string(json).size())

func _on_log_meta_clicked(meta):
    # Handle clicks on actor/item/ability/status references in the log.
    var s = String(meta)
    var parts = s.split(":", false, 2)
    var kind = parts[0]
    var payload = (parts[1] if parts.size() > 1 else "")
    match kind:
        "actor":
            if msg_feed and msg_feed.has_method("push_message"):
                msg_feed.push_message("Actor clicked: [code]%s[/code]" % payload)
        "item":
            if inspector and inspector.has_method("show_item"):
                (inspector as Node).call("show_item", payload)
        "ability":
            if inspector and inspector.has_method("show_ability"):
                (inspector as Node).call("show_ability", payload)
        "status":
            if msg_feed and msg_feed.has_method("push_message"):
                msg_feed.push_message("Status: [color=#ffd166]%s[/color]" % payload)
        _:
            if msg_feed and msg_feed.has_method("push_message"):
                msg_feed.push_message("Clicked: [code]%s[/code]" % s)

func _on_msg_input_submit(t: String) -> void:
    if t == "":
        return
    if event_log and event_log.has_method("append_text"):
        event_log.append_text("[color=#ccf]» %s[/color]\n" % t)
    msg_input.clear()

func _on_header_meta_clicked(meta):
    _flash(msg_header)
    if String(meta) == "search":
        var query = msg_input.text
        if event_log and event_log.has_method("perform_search"):
            var ok = event_log.perform_search(query)
            if msg_feed and msg_feed.has_method("push_message"):
                msg_feed.push_message(("[color=#ffbf00]SEARCH[/color]: [i]%s[/i] %s" % [query, ("→ found" if ok else "→ no match")]))

func _flash(node: CanvasItem) -> void:
    if node == null:
        return
    var t = create_tween()
    var orig = node.self_modulate
    t.tween_property(node, "self_modulate", Color(1,1,0.6,1), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
    t.tween_property(node, "self_modulate", orig, 0.12).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _lock_heights() -> void:
    var h = right_scroll.custom_minimum_size.y
    if h <= 0:
        return
    left_pane.custom_minimum_size.y = h
    # Ensure header occupies one line visually
    if msg_header:
        var f: Font = msg_header.get_theme_font("normal_font")
        var size: int = msg_header.get_theme_font_size("normal_font_size")
        if f and size > 0:
            var one = int(ceil(f.get_height(size)))
            msg_header.custom_minimum_size.y = float(one)
    # Wire buttons if a controller is present
    if controller == null:
        controller = get_tree().get_root().get_node_or_null("/root/VerticalSlice/BattleController")
    # Actions tab buttons
    var act_root = get_node_or_null("Root/RightPane/TopTabs/Actions/Buttons")
    if act_root:
        var btn_end: Button = act_root.get_node_or_null("EndTurn")
        var btn_atk: Button = act_root.get_node_or_null("Attack")
        var btn_ow: Button = act_root.get_node_or_null("Overwatch")
        if btn_end:
            btn_end.pressed.connect(func():
                if controller and controller.has_method("_on_end_turn_pressed"): controller._on_end_turn_pressed())
        if btn_atk:
            btn_atk.pressed.connect(func():
                if controller and controller.has_method("_enter_attack_mode"): controller._enter_attack_mode())
        if btn_ow:
            btn_ow.pressed.connect(func():
                if services and services.get("timespace") != null and services.timespace.get_current_actor():
                    var actor = services.timespace.get_current_actor()
                    if services.timespace.can_perform(actor, "overwatch", null):
                        services.timespace.perform(actor, "overwatch", null))
    # Utility: Toggle debug overlays and camera control
    if has_node("Root/RightPane/Utility/UtilityVBox/Buttons/ToggleDebug"):
        $Root/RightPane/Utility/UtilityVBox/Buttons/ToggleDebug.pressed.connect(_toggle_debug_overlays)
    if has_node("Root/RightPane/Utility/UtilityVBox/Buttons/ToggleCamera"):
        $Root/RightPane/Utility/UtilityVBox/Buttons/ToggleCamera.pressed.connect(_toggle_camera_controls)
    if has_node("Root/LeftPane/WorldOverlay/Buttons/ToggleCamera"):
        $Root/LeftPane/WorldOverlay/Buttons/ToggleCamera.pressed.connect(_toggle_camera_controls)
    _sync_camera_buttons()

func _on_event(evt: Dictionary) -> void:
    if event_log and event_log.has_method("append_entry"):
        event_log.append_entry(evt)

func _toggle_debug_overlays() -> void:
    var slice_dbg = get_tree().root.get_node_or_null("/root/VerticalSlice/SliceDebug")
    if slice_dbg:
        slice_dbg.visible = not slice_dbg.visible
    var err = get_tree().root.get_node_or_null("/root/VerticalSlice/ErrorOverlay")
    if err:
        err.visible = not err.visible

func _toggle_camera_controls() -> void:
    var cam = get_tree().root.get_node_or_null("/root/VerticalSlice/World3D/Camera3D")
    if cam and cam.has_variable("controls_enabled"):
        cam.controls_enabled = not cam.controls_enabled
    _sync_camera_buttons()

func _sync_camera_buttons() -> void:
    var cam = get_tree().root.get_node_or_null("/root/VerticalSlice/World3D/Camera3D")
    var enabled := true
    if cam and cam.has_variable("controls_enabled"):
        enabled = cam.controls_enabled
    if has_node("Root/RightPane/Utility/UtilityVBox/Buttons/ToggleCamera"):
        $Root/RightPane/Utility/UtilityVBox/Buttons/ToggleCamera.button_pressed = enabled
    if has_node("Root/LeftPane/WorldOverlay/Buttons/ToggleCamera"):
        $Root/LeftPane/WorldOverlay/Buttons/ToggleCamera.button_pressed = enabled

func _dbg(msg: String) -> void:
    var dbg = get_tree().get_root().get_node_or_null("/root/WorkspaceDebugger")
    if dbg and dbg.has_method("log_info"):
        dbg.log_info("[MainGUI] %s" % msg)
    else:
        print("[MainGUI] %s" % msg)
