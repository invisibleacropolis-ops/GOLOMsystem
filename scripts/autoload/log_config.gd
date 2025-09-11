extends Node
class_name EventLogConfig

## EventLogConfig: global verbosity settings for event logging.
##
## This autoload exposes two independent verbosity levels:
## - `gui_level`: controls how much the in-game EventLogUI displays.
## - `file_level`: controls which events are written to the persistent
##   text log via EventTapLogger.
##
## Levels are defined by the `Verbosity` enum and can be adjusted at
## runtime via `set_gui_level` and `set_file_level`.
##
## Other modules can query `event_level(evt)` to determine the level for
## a given event dictionary.

enum Verbosity {
    MINIMAL,   ## Core high-level events only (battle start/end, turns).
    NORMAL,    ## Includes common gameplay events like actions and damage.
    VERBOSE    ## Includes all events for detailed debugging.
}

var gui_level: int = Verbosity.NORMAL
var file_level: int = Verbosity.NORMAL

signal gui_level_changed(level: int)
signal file_level_changed(level: int)

func set_gui_level(level: int) -> void:
    """Set GUI verbosity and notify listeners."""
    gui_level = clamp(level, Verbosity.MINIMAL, Verbosity.VERBOSE)
    gui_level_changed.emit(gui_level)

func set_file_level(level: int) -> void:
    """Set file log verbosity and notify listeners."""
    file_level = clamp(level, Verbosity.MINIMAL, Verbosity.VERBOSE)
    file_level_changed.emit(file_level)

func event_level(evt: Dictionary) -> int:
    """Determine the verbosity level for a given event."""
    var t := String(evt.get("t", ""))
    match t:
        "map_loaded", "battle_begins", "round_start", "round_end", "turn_start", "turn_end", "battle_over":
            return Verbosity.MINIMAL
        "ap", "action", "damage", "status_on", "status_off", "reaction":
            return Verbosity.NORMAL
        _:
            return Verbosity.VERBOSE
