extends Node

var log_file: FileAccess

func _ready() -> void:
    var log_path := "user://workspace_errors.log"
    log_file = FileAccess.open(log_path, FileAccess.WRITE)
    if log_file == null:
        push_error("Failed to open log file: %s" % log_path)
        return
    _log("Workspace debugger initialized")

func _log(message: String) -> void:
    var stamp := Time.get_datetime_string_from_system()
    log_file.store_line("[%s] %s" % [stamp, message])
    log_file.flush()
    # Echo log messages to stdout so headless runs surface progress
    # in the terminal instead of only writing to the log file.
    print(message)

func log_error(message: String) -> void:
    _log("ERROR: %s" % message)

func log_info(message: String) -> void:
    _log(message)
