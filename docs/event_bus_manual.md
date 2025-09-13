# EventBus Module Manual

The `event_bus.gd` module provides a lightweight, append-only log of game events. Other systems push structured dictionaries here so analytics, replays, or debuggers can consume them later.

## Responsibilities

- Maintain the `entries` array of event dictionaries.
- Offer methods to append events, serialize the log, and replay events for deterministic testing or analysis.

## Core Concepts and API Details

The `EventBus` module is a foundational component for maintaining a clear, chronological record of everything that happens in the game. This "single source of truth" for events is invaluable for debugging complex interactions, performing game analytics, and enabling deterministic replays.

### Class: `EventBus` (inherits from `Node`)

This is the main class for managing the event log. As a `Node`, it can be easily integrated into your game's scene tree, typically as a singleton or part of a `RuntimeServices` aggregation.

#### Members

*   **`entries`** (`Array`, Default: `[]`): This array stores all the event dictionaries pushed to the `EventBus`. Each element in this array represents a single game event, recorded in the order it occurred. This array is the core data structure of the event log.

#### Methods

*   **`push(evt: Dictionary) -> void`**
    Appends a new event dictionary to the `entries` array. This is the primary method used by other modules to record game events.
    *   `evt`: A `Dictionary` representing the event. It's highly recommended that this dictionary includes a `t` (type) field to categorize the event (e.g., `{"t": "round_start"}`, `{"t": "damage_dealt"}`). Additional keys can be added to provide context specific to the event.
*   **`serialize() -> String`**
    Converts the entire `entries` array into a JSON-formatted string. This string can then be saved to a file, sent over a network, or stored in a database, allowing for persistence of the game's event history.
    *   **Returns:** A `String` containing the JSON representation of the event log.
*   **`replay(json: String, handler: Callable) -> void`**
    Replays a sequence of events from a serialized JSON string. This method is crucial for deterministic testing, debugging, and potentially for features like "rewind" or "spectator mode."
    *   `json`: A `String` containing the JSON-formatted event log (typically obtained from `serialize()`).
    *   `handler`: A `Callable` (e.g., a function or method) that will be invoked for each event in the replayed log. This allows external systems to react to the replayed events without directly modifying the game state during replay.

#### Signals

The `EventBus` itself does not emit signals, as its primary role is to be a passive, append-only log. Other modules that push events to the `EventBus` might emit their own signals.

## Usage

```gdscript
var bus := EventBus.new()

# Example 1: Pushing a simple event
bus.push({"t": "round_start", "round": 1, "timestamp": OS.get_unix_time()})

# Example 2: Pushing an event with more details
var actor_id = "player_1"
var ability_id = "fireball"
var target_pos = Vector2i(5, 3)
bus.push({
    "t": "ability_executed",
    "actor_id": actor_id,
    "ability": ability_id,
    "target_position": target_pos,
    "damage_dealt": 25
})

# Serialize the log for saving or debugging
var json_log := bus.serialize()
print("Serialized Event Log: " + json_log)

# Define a handler function for replaying events
func _on_event_replayed(event_data: Dictionary):
    print("Replayed Event: " + str(event_data))
    if event_data.has("t"):
        match event_data["t"]:
            "round_start":
                print("  -> Round " + str(event_data.get("round", "N/A")) + " started.")
            "ability_executed":
                print("  -> Actor " + event_data.get("actor_id", "N/A") + " used " + event_data.get("ability", "N/A") + ".")

# Replay the log using the handler
bus.replay(json_log, Callable(self, "_on_event_replayed"))
```

## Integration Notes

-   **Standardized Event Structure:** To maximize the utility of the `EventBus` for tooling and analysis, it's crucial to standardize the structure of event dictionaries. Always include a `t` field (for "type") to categorize the event. Additional keys can be added to provide context specific to the event. For example, all "damage_dealt" events should consistently use keys like `attacker_id`, `defender_id`, and `amount`.
-   **Deterministic Replays:** The `EventBus` is a cornerstone for deterministic replays. To achieve this, ensure that all non-random, state-changing operations are recorded as events. When replaying, you would typically disable direct game logic execution and instead drive the game state solely by processing events from the log. This is particularly useful for debugging hard-to-reproduce bugs or for competitive game analysis.
-   **Non-Mutating Replay Handler:** The `replay()` method accepts a `Callable` handler. This design allows tests or analytics tools to process events during replay without directly mutating the game's live state. This separation is vital for maintaining the integrity of the replay process.
-   **Performance Considerations:** While append-only, for very long game sessions, the `entries` array can grow large. Consider strategies for periodically serializing and clearing the log, or implementing a circular buffer if only recent history is needed.

## Testing

Run the shared test runner to verify the `EventBus` module's functionality:

```bash
godot4 --headless --path . --script scripts/test_runner.gd -- --module=event_bus
```

This test ensures that the module correctly records a dummy entry, can serialize it, and can successfully replay it using a provided handler, confirming its core responsibilities are met.