extends Node

## Applies the project-wide UI theme at startup so all text fields use
## the provided font until overridden by control-specific themes.
## Also ensures newly added Controls inherit the theme unless they
## already specify a custom theme.

const THEME_PATH := "res://themes/app_theme.tres"
var _theme: Theme

func _ready() -> void:
    _theme = preload(THEME_PATH)
    if _theme:
        get_tree().root.theme = _theme
        # Apply to existing controls that don't have an explicit theme
        _apply_theme_to_tree()
        # Keep future nodes themed
        get_tree().node_added.connect(_on_node_added)
        _log("ThemeBootstrap applied theme to existing Controls")

func _on_node_added(n: Node) -> void:
    if not _theme:
        return
    if n is Control:
        var c := n as Control
        if c.theme == null:
            c.theme = _theme

func _apply_theme_to_tree() -> void:
    var root = get_tree().root
    _apply_recursive(root)

func _apply_recursive(n: Node) -> void:
    if n is Control and (n as Control).theme == null:
        (n as Control).theme = _theme
    for c in n.get_children():
        if c is Node:
            _apply_recursive(c)

func _log(msg: String) -> void:
    var dbg = get_tree().get_root().get_node_or_null("/root/WorkspaceDebugger")
    if dbg and dbg.has_method("log_info"):
        dbg.log_info("[ThemeBootstrap] %s" % msg)
