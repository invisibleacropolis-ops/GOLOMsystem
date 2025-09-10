extends Node

signal log_emitted(message: String, level: String)

var log_file: FileAccess
var log_path := "user://workspace_errors.log"

func _ready() -> void:
    log_file = FileAccess.open(log_path, FileAccess.WRITE)
    if log_file == null:
        push_error("Failed to open log file: %s" % log_path)
        return
    _log("Workspace debugger initialized", "info")

func _log(message: String, level: String = "info") -> void:
    var stamp := Time.get_datetime_string_from_system()
    var line := "[%s] %s: %s" % [stamp, level.to_upper(), message]
    log_file.store_line(line)
    log_file.flush()
    print(line)
    log_emitted.emit(message, level)
    var hub = get_tree().get_root().get_node_or_null("/root/ErrorHub")
    if hub:
        hub.call_deferred("_report", level, "Workspace", message, {})

func log_error(message: String) -> void:
    _log(message, "error")

func log_info(message: String) -> void:
    _log(message, "info")

func log_warning(message: String) -> void:
    _log(message, "warn")

func log_exception(context: String, data := {}) -> void:
    _log("Exception: %s | %s" % [context, JSON.stringify(data)], "error")
