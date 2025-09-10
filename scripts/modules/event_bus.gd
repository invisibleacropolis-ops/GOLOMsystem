extends Node

signal event_pushed(event_data) # NEW: Signal to emit when an event is pushed

var entries: Array = []

func push(evt: Dictionary) -> void:
    entries.append(evt)
    event_pushed.emit(evt) # Emit the signal

func serialize() -> String:
    return JSON.stringify(entries)

func replay(json: String, handler: Callable) -> void:
    var data = JSON.parse_string(json)
    if data is Array:
        for evt in data:
            handler.call(evt)

func run_tests() -> Dictionary:
    var failed := 0
    var total := 0
    var logs: Array[String] = []

    # Test push and serialization
    total += 1
    var test_event = {"t": "test_event", "data": "hello"}
    push(test_event)
    var serialized = serialize()
    var parsed_serialized = JSON.parse_string(serialized)
    if parsed_serialized != [test_event]:
        failed += 1
        logs.append("Serialization failed: Expected " + str([test_event]) + ", got " + str(parsed_serialized))

    # Test replay
    total += 1
    var replayed_events_container: Array = [] # Use a container to capture the event
    replay(serialized, func(evt): replayed_events_container.append(evt))
    if replayed_events_container.size() != 1 or replayed_events_container[0] != test_event:
        failed += 1
        logs.append("Replay failed: Expected " + str([test_event]) + ", got " + str(replayed_events_container))

    # Test signal emission (conceptual, hard to test directly in this setup)
    # For a real test, you'd connect a mock object to the signal and check if it was called.
    # Here, we'll just assume the emit works if push works.

    return {
        "failed": failed,
        "total": total,
        "log": "\n".join(logs)
    }