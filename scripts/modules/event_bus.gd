extends Node
class_name EventBus

## Append-only event log for analytics and deterministic replays.
## Other modules may push structured dictionaries here.

var entries: Array = []

func push(evt: Dictionary) -> void:
    entries.append(evt)

func serialize() -> String:
    return JSON.stringify(entries)

func replay(json: String, handler: Callable) -> void:
    var arr = JSON.parse_string(json)
    if typeof(arr) != TYPE_ARRAY:
        return
    for evt in arr:
        handler.call(evt)

func run_tests() -> Dictionary:
    push({"t": "dummy"})
    var json = serialize()
    var replayed = []
    replay(json, func(evt): replayed.append(evt))
    var ok = replayed.size() == 1 and replayed[0]["t"] == "dummy"
    return {
        "failed": (0 if ok else 1),
        "total": 1,
        "log": replayed,
    }
