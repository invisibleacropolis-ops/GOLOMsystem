extends Node

signal event_pushed(event_data) # NEW: Signal to emit when an event is pushed

var entries: Array = []

func push(evt: Dictionary) -> void:
    entries.append(evt)
    event_pushed.emit(evt) # Emit the signal

func serialize() -> String:
    return JSON.stringify(entries)

## Save the current event log to a JSON file for later analysis.
func save_to_file(path: String) -> void:
    var f = FileAccess.open(path, FileAccess.WRITE)
    if f:
        f.store_string(serialize())
        f.close()

func replay(json: String, handler: Callable) -> void:
    var data = JSON.parse_string(json)
    if data is Array:
        for evt in data:
            handler.call(evt)

## Replay events from a JSON file on disk.
func replay_file(path: String, handler: Callable) -> void:
    var f = FileAccess.open(path, FileAccess.READ)
    if f:
        var txt = f.get_as_text()
        f.close()
        replay(txt, handler)

func run_tests() -> Dictionary:
    var failed := 0
    var total := 0
    var logs: Array[String] = []
    entries.clear()

    # Test push and serialization
    total += 1
    var test_event = {"t": "test_event", "data": {"msg": "hello"}}
    push(test_event)
    var serialized = serialize()
    var parsed_serialized = JSON.parse_string(serialized)
    if parsed_serialized != [test_event]:
        failed += 1
        logs.append("Serialization failed: Expected " + str([test_event]) + ", got " + str(parsed_serialized))

    # Test replay
    total += 1
    var replayed_events_container: Array = []
    replay(serialized, func(evt): replayed_events_container.append(evt))
    if replayed_events_container.size() != 1 or replayed_events_container[0] != test_event:
        failed += 1
        logs.append("Replay failed: Expected " + str([test_event]) + ", got " + str(replayed_events_container))

    # Test file save and replay
    total += 1
    var tmp_path = "user://event_bus_test.json"
    save_to_file(tmp_path)
    var file_events: Array = []
    replay_file(tmp_path, func(evt): file_events.append(evt))
    if file_events.size() != 1 or file_events[0] != test_event:
        failed += 1
        logs.append("File replay failed: Expected " + str([test_event]) + ", got " + str(file_events))
    DirAccess.remove_absolute(tmp_path)

    return {
        "failed": failed,
        "total": total,
        "log": "\n".join(logs)
    }
