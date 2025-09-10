extends CanvasLayer

@export var renderer_path: NodePath
@onready var _renderer = get_node_or_null(renderer_path)

@onready var _panel: Panel = $Panel
@onready var _ascii_checkbox: CheckBox = $Panel/VBox/AsciiStreamToOutput
@onready var _tcp_checkbox: CheckBox = $Panel/VBox/TcpStreamEnabled
@onready var _port_label: Label = $Panel/VBox/PortLabel
@onready var _overlay_checkbox: CheckBox = $Panel/VBox/ShowOverlay

func _ready() -> void:
    var srv = _get_server()
    if srv:
        _tcp_checkbox.button_pressed = srv.is_enabled()
        _port_label.text = "ASCII TCP: 127.0.0.1:%d" % srv.get_port()
    if _renderer:
        _ascii_checkbox.button_pressed = bool(_renderer.ascii_stream_enabled)
        _overlay_checkbox.button_pressed = bool(_renderer.visible)
    _ascii_checkbox.toggled.connect(_on_ascii_toggled)
    _tcp_checkbox.toggled.connect(_on_tcp_toggled)
    _overlay_checkbox.toggled.connect(_on_overlay_toggled)

func _get_server():
    return get_tree().root.get_node_or_null("AsciiStreamServer")

func _on_ascii_toggled(on: bool) -> void:
    if _renderer:
        if _renderer.has("ascii_stream_enabled"):
            _renderer.ascii_stream_enabled = on

func _on_tcp_toggled(on: bool) -> void:
    var srv = _get_server()
    if srv:
        srv.set_enabled(on)

func _on_overlay_toggled(on: bool) -> void:
    if _renderer:
        _renderer.visible = on
