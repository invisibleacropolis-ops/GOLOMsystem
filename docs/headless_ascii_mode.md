# Headless ASCII Mode

The Golom project can be executed without a graphical window using its built-in ASCII renderer. This mode mirrors the normal GUI behavior by running all runtime services and actors while rendering the game world to your terminal. This is incredibly useful for automated testing, continuous integration (CI), or simply running the game on a server without a display.

## Running the Game in Headless ASCII Mode

To start the game in headless ASCII mode, use the following command:

```bash
godot4 --headless --path .
```

Upon execution, module tests will run first. If all tests are successful, the ASCII grid will begin updating directly in your terminal. The renderer prints the grid every half second by default, including actor positions (represented by `@` or custom symbols). Other AI-driven actors will continue to move during their turns, matching the behavior observed in the graphical user interface (GUI) version.

## How ASCII Rendering Works (Behind the Scenes)

The headless ASCII mode is powered by the `GridRealtimeRenderer` module. This module, typically used for high-performance visual overlays in the GUI, also has robust capabilities for generating text-based representations of the grid.

### Class: `GridRealtimeRenderer` (inherits from `Node2D`)

The `GridRealtimeRenderer` is responsible for converting the game's grid state into a human-readable ASCII format.

#### Key Members for ASCII Output

*   **`ascii_update_sec`** (`float`, Default: `0.5`): This member controls the update frequency of the ASCII output. A value of `0.5` means the grid will refresh every half second. You can adjust this value in the `GridRealtimeRenderer` instance if you need faster or slower updates.
*   **`ascii_debug`** (`String`): This read-only member holds the most recently generated ASCII string representation of the grid. The engine automatically prints this string to the console at the interval defined by `ascii_update_sec`.
*   **`ascii_use_color`** (`bool`, Default: `false`): If set to `true`, the ASCII output will include ANSI color codes. This allows terminals that support ANSI escape sequences to display the map with colored glyphs, making it easier to distinguish different elements (e.g., red for enemies, blue for allies).
*   **`ascii_actor_group`** (`StringName`, Default: `&"actors"`): The `GridRealtimeRenderer` automatically scans nodes belonging to this group to include their ASCII representations in the output. Ensure your actors are added to this group (e.g., `actor.add_to_group("actors")`).
*   **`ascii_include_actors`** (`bool`, Default: `true`): If `true`, actors found in the `ascii_actor_group` will have their symbols rendered on the ASCII grid.

#### Key Methods for ASCII Output and Interaction

*   **`generate_ascii_field() -> String`**: This method can be called directly to obtain the current ASCII snapshot of the grid on demand. This is particularly useful for scripting tests where you need to capture the grid state at a precise moment.
*   **`set_ascii_entity(p: Vector2i, symbol: String, color: Color, priority: int, id: int, z_index: int) -> void`**: Allows you to manually place custom ASCII symbols on the grid. This is useful for debugging specific points or marking temporary locations.
*   **`update_input(pos: Vector2i, action: String) -> void`**: This method is crucial for simulating user interactions in headless mode. The game's input handling system (likely in `Root.gd` or a similar top-level script) translates keyboard commands (`w`, `a`, `s`, `d`) into calls to this method.
    *   `pos`: The `Vector2i` grid coordinates relevant to the action.
    *   `action`: A `String` representing the type of interaction (e.g., `"select"`, `"move"`, `"target"`, `"click"`, `"drag_start"`, `"drag"`, `"drag_end"`, `"clear"`).

### Customizing Actor Representation

Actors can customize how they appear in the ASCII output. If your actor scripts inherit from `BaseActor` or a similar class, you can override these methods:

*   **`get_ascii_symbol() -> String`**: Returns the character to represent the actor (e.g., `"@"`, `"E"`, `"P"`).
*   **`get_ascii_color() -> Color`**: Returns the color for the actor's symbol (used if `ascii_use_color` is `true`).
*   **`get_ascii_priority() -> int`**: Determines which symbol appears if multiple entities occupy the same cell (higher priority wins).
*   **`get_ascii_z_index() -> int`**: Further refines layering for entities with the same priority.

## Interacting with the Game

When running in headless ASCII mode, you can interact with the game using simple keyboard commands:

*   **`w`, `a`, `s`, `d`**: These keys are typically mapped to movement actions for the player actor when it is their turn. The game's input system translates these into `update_input()` calls on the `GridRealtimeRenderer` (and subsequently, actions within `TurnBasedGridTimespace`).
*   **`quit`**: Type `quit` and press Enter in the terminal to gracefully exit the simulation.

## Example ASCII Output

```
+---+---+---+---+---+
| . | . | . | . | . |
+---+---+---+---+---+
| . | @ | . | . | . |
+---+---+---+---+---+
| . | . | . | E | . |
+---+---+---+---+---+
| . | . | . | . | . |
+---+---+---+---+---+
```
(Where `@` might be the player and `E` an enemy, depending on their `get_ascii_symbol()` implementation.)

## Testing in Headless Mode

The headless ASCII mode is invaluable for automated testing. You can write scripts that:
1.  Start the game in headless mode.
2.  Simulate input using `GridRealtimeRenderer.update_input()`.
3.  Capture the `GridRealtimeRenderer.generate_ascii_field()` output to assert the game state.
4.  Check the `EventBus` log for expected events.

This allows for rapid, deterministic testing of game logic without the overhead of rendering a full graphical interface.