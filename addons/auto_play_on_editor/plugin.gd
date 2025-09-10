@tool
extends EditorPlugin

const DEFAULT_SCENE := "res://scenes/VerticalSlice.tscn"

var _played_once := false

func _log(msg: String) -> void:
    # Best-effort append to a small logfile for verification.
    var path := "user://editor_autoplay.log"
    var f := FileAccess.open(path, FileAccess.WRITE_READ)
    if f:
        f.seek_end()
        f.store_line("[%s] %s" % [Time.get_datetime_string_from_system(), msg])
        f.close()

func _enter_tree() -> void:
    _log("EditorPlugin enter_tree; scheduling autoplay")
    # Defer to allow editor UI to finish initializing.
    call_deferred("_maybe_autoplay")

func _maybe_autoplay() -> void:
    if _played_once:
        _log("Autoplay already attempted; skipping")
        return

    # Allow opting-out via CLI or env if needed.
    var args := OS.get_cmdline_args()
    if "--no-autoplay" in args or OS.get_environment("GODOT_NO_AUTOPLAY") != "":
        _log("Autoplay disabled by flag or env")
        return

    _played_once = true

    var ei := get_editor_interface()
    if ei == null:
        push_warning("AutoPlay: EditorInterface not available.")
        _log("EditorInterface null; cannot autoplay")
        return

    # Resolve target scene; prefer configured main_scene, fallback to DEFAULT_SCENE.
    var scene_path: String = ProjectSettings.get_setting("application/run/main_scene", DEFAULT_SCENE)
    if not ResourceLoader.exists(scene_path):
        scene_path = DEFAULT_SCENE
    _log("Resolved scene: %s" % scene_path)

    if not ResourceLoader.exists(scene_path):
        push_warning("AutoPlay: Scene not found: %s" % scene_path)
        _log("Scene not found: %s" % scene_path)
        return

    # Open the scene in the editor to ensure play_current_scene targets it.
    ei.open_scene_from_path(scene_path)
    _log("open_scene_from_path called")

    # Wait a couple frames to let the editor settle before playing.
    var st := Engine.get_main_loop()
    if st is SceneTree:
        await (st as SceneTree).process_frame
        await (st as SceneTree).process_frame

    if ei.has_method("play_current_scene"):
        _log("Calling play_current_scene")
        ei.play_current_scene()
    elif ei.has_method("play_main_scene"):
        _log("Calling play_main_scene")
        ei.play_main_scene()
    else:
        push_warning("AutoPlay: No play method available on EditorInterface.")
        _log("No play method available on EditorInterface")
