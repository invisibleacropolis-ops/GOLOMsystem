# Combining GridRealtimeRenderer with TurnBasedGridTimespace

This tutorial walks through wiring the high-performance `GridRealtimeRenderer` with the `TurnBasedGridTimespace` module. This combination is fundamental for creating tactical grid-based games, allowing you to visualize game state changes as turns progress.

## 1. Create the Scene Structure

First, set up your basic scene in Godot:

1.  Add a `Node2D` as the root of your new scene (e.g., `TacticalGame.tscn`).
2.  Instance `GridRealtimeRenderer` and `TurnBasedGridTimespace` as children of your root `Node2D`. You can do this by dragging their `.gd` scripts into the scene as new nodes, or by instantiating them in code.
3.  In the Inspector for `GridRealtimeRenderer`, set its `grid_size` (e.g., `Vector2i(32, 32)`) and `cell_size` (e.g., `Vector2(48, 48)`) to match the dimensions of your game map. These properties define the visual grid.

## 2. Register Actors and Initial Visualization

Once your scene is set up, you need to register your game's actors with the `TurnBasedGridTimespace` and provide an initial visual representation using the `GridRealtimeRenderer`.

```gdscript
# Get references to your instantiated nodes
@onready var timespace: TurnBasedGridTimespace = $TurnBasedGridTimespace
@onready var renderer: GridRealtimeRenderer = $GridRealtimeRenderer

func _ready() -> void:
    # Create an actor instance. BaseActor is a common base class for game entities.
    # Parameters: name, initial grid_pos, facing, size (footprint on grid)
    var actor := BaseActor.new("hero", Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE)
    add_child(actor) # Add the actor to the scene tree

    # Visualize the actor's initial position using the renderer
    # set_cell_color(p: Vector2i, color: Color) fills a grid cell with a color.
    renderer.set_cell_color(Vector2i.ZERO, Color.BLUE) # Highlight the hero's starting cell in blue

    # Register the actor with the TurnBasedGridTimespace
    # add_actor(actor: Object, initiative: int, action_points: int, pos: Vector2i, tie_break: int = -1)
    # This adds the actor to the turn order, sets their initial AP, and places them on the logical grid.
    timespace.add_actor(actor, 10, 2, Vector2i.ZERO, 0) # Hero has initiative 10, 2 AP, starts at (0,0)
```

*   **`BaseActor`:** This is a fundamental class for any entity that exists on the grid and participates in the turn-based system.
*   **`TurnBasedGridTimespace.add_actor()`:** This method is crucial. It not only adds the actor to the turn order but also associates them with a logical position on the grid, which `TurnBasedGridTimespace` uses for its internal logic.
*   **`GridRealtimeRenderer.set_cell_color()`:** This is a simple way to visually mark a cell. As the actor moves, you'll update this.

## 3. Advance Turns and Update Visualization

The core of a turn-based game is advancing turns and updating the game state and visuals accordingly.

```gdscript
# Call this to begin the first round of combat
timespace.start_round()

# In your game loop or input handler, when an actor performs an action:
# Example: Player moves to a new position
func _on_player_move_action(target_pos: Vector2i) -> void:
    var current_actor = timespace.get_current_actor()
    if current_actor == actor: # Check if it's the hero's turn
        # Perform the move action through the timespace
        # perform(actor: Object, action_id: String, payload: Variant = null) -> bool
        var success = timespace.perform(current_actor, "move", {"target_pos": target_pos})
        if success:
            # Update the renderer to reflect the new position
            renderer.clear_all() # Clear previous highlights
            renderer.set_cell_color(current_actor.grid_pos, Color.BLUE) # Highlight new position

            # After the actor has finished all actions for their turn, end it
            timespace.end_turn()
```

*   **`TurnBasedGridTimespace.start_round()`:** This method initializes the turn system, resets AP, and prepares for the first turn.
*   **`TurnBasedGridTimespace.perform()`:** This method is used to execute actions. It handles AP deduction, internal logic, and often updates the actor's `grid_pos` (if it's a movement action).
*   **`TurnBasedGridTimespace.end_turn()`:** After an actor has completed their actions, this method advances the turn to the next actor in the initiative order.
*   **`GridRealtimeRenderer` Updates:** Each time the game state changes (e.g., an actor moves, a status is applied), you'll need to update the `GridRealtimeRenderer` to reflect these changes. This might involve:
    *   `renderer.clear_all()`: To remove old highlights.
    *   `renderer.set_cell_color()`: To highlight new positions or areas.
    *   `renderer.set_mark()`: To place markers (e.g., target indicators).
    *   `renderer.push_label()`: To display text labels (e.g., damage numbers, actor names).

## 4. Use GPU Labels for Text

For efficient text rendering, especially when displaying many labels (like actor names or damage numbers), `GridRealtimeRenderer` supports GPU-accelerated labels via `GPULabelBatcher`.

```gdscript
# Ensure use_gpu_labels is true on your GridRealtimeRenderer instance
renderer.use_gpu_labels = true
renderer.label_font = preload("res://path/to/your_font.tres") # Set a font resource

# Wrap your label calls with begin_labels() and end_labels()
# This batches all labels for a single, optimized draw call.
renderer.begin_labels()
renderer.push_label("Hero", actor.grid_pos.to_float() * renderer.cell_size, Color.WHITE) # Convert grid pos to world pos
# Add more labels as needed
renderer.end_labels()
```

*   **`renderer.use_gpu_labels`:** Set this to `true` to enable GPU-accelerated label rendering.
*   **`renderer.label_font`:** Assign a `Font` resource here.
*   **`renderer.begin_labels()` / `renderer.end_labels()`:** These methods define a block within which all `push_label()` calls are batched. This significantly improves performance compared to drawing individual labels.
*   **`renderer.push_label(text: String, pos: Vector2, color: Color = Color(1, 1, 1, 1)) -> void`:** Adds a label to the batch. Note that `pos` is a `Vector2` (world coordinates), so you'll need to convert `Vector2i` grid positions to world positions (e.g., `actor.grid_pos.to_float() * renderer.cell_size`).

## 5. Night Vision or Fog of War (Shader Modes)

`GridRealtimeRenderer` supports different shader modes to apply global visual effects, useful for features like night vision or fog of war.

```gdscript
# Toggle visualization modes at runtime:
renderer.set_shader_mode(1) # Activates a "night vision" effect
# renderer.set_shader_mode(2) # Activates a "fog of war" effect
```

*   **`renderer.set_shader_mode(mode: int) -> void`:** This method switches the active shader mode. The integer `mode` corresponds to predefined visual effects implemented within the renderer's shaders.

This scene setup forms the basis for tactical prototypes, effectively combining the logical turn management of `TurnBasedGridTimespace` with the powerful visualization capabilities of `GridRealtimeRenderer`.