# GridRealtimeRenderer Manual

`GridRealtimeRenderer` is a high-performance overlay renderer built for tactical grid games. It leverages Godot's `MultiMeshInstance2D` to efficiently batch tile fills, allowing thousands of per-frame updates without creating individual `CanvasItem` nodes. This makes it ideal for dynamic visual feedback like highlighting, heatmaps, and various overlays. It also supports numeric channels that can be mapped through a `Gradient` to display heatmaps.

## Responsibilities

-   Maintain a static grid of quads sized to `cell_size` and `grid_size`.
-   Provide direct per-cell color fills via `set_cell_color()` and `clear_*()` helpers.
-   Track arbitrary numeric channels and convert them into colors with `apply_heatmap()`.
-   Optionally draw grid lines and lightweight overlays such as current actor, paths, areas of effect, and zones of control.
-   Generate ASCII snapshots of the grid for headless debugging and testing.
-   Manage GPU-accelerated text labels.

## Core Concepts and API Details

The `GridRealtimeRenderer` is designed for visual debugging and dynamic UI elements on a grid. Its efficiency comes from batching drawing operations.

### Class: `GridRealtimeRenderer` (inherits from `Node2D`)

As a `Node2D`, it can be added to your scene tree and positioned relative to your game world.

#### Members

The `GridRealtimeRenderer` exposes numerous members for configuration and internal state. Here are some key ones:

*   **`enabled_layers`** (`StringName[]`, Default: `[...]`): Controls which visual layers (fill, heat, glyph, stroke, labels, outline) are currently active.
*   **`layer_opacity_fill`**, **`layer_opacity_heat`**, etc. (`float`, Default: `1.0`): Control the transparency of individual visual layers.
*   **`world_offset`** (`Vector2`, Default: `Vector2(0, 0)`): An offset applied to the entire rendered grid, useful for aligning with a camera or other world elements.
*   **`cell_size`** (`Vector2`, Default: `Vector2(48, 48)`): The size of each individual grid cell in pixels.
*   **`grid_size`** (`Vector2i`, Default: `Vector2i(16, 9)`): The dimensions of the grid in cells (width, height).
*   **`show_grid_lines`** (`bool`, Default: `true`): Toggles the visibility of grid lines.
*   **`grid_line_thickness`** (`float`, Default: `1.0`): Thickness of the grid lines.
*   **`grid_line_modulate`** (`Color`, Default: `Color(1, 1, 1, 0.15)`): Color and transparency of the grid lines.
*   **`enable_fill`**, **`enable_heat`**, **`enable_marks`**, **`enable_strokes`**, **`enable_hatch`** (`bool`): Enable/disable specific rendering features.
*   **`opacity_fill`**, **`opacity_heat`**, etc. (`float`): Opacity settings for various visual elements.
*   **`label_font`** (`Font`): The font resource used for rendering text labels.
*   **`max_labels`** (`int`, Default: `256`): Maximum number of labels that can be batched.
*   **`use_gpu_labels`** (`bool`, Default: `true`): Enables/disables GPU-accelerated label rendering.
*   **`heat_gradient`** (`Gradient`, Default: `new()`): The color gradient used for heatmaps.
*   **`ascii_update_sec`** (`float`, Default: `0.5`): How often the ASCII debug snapshot is updated.
*   **`ascii_debug`** (`String`): The generated ASCII snapshot of the grid.
*   **`ascii_use_color`** (`bool`, Default: `false`): If `true`, the ASCII output will include ANSI color codes.
*   **`ascii_actor_group`** (`StringName`, Default: `&"actors"`): The group name used to find actors for ASCII representation.
*   **`ascii_include_actors`** (`bool`, Default: `true`): If `true`, actors in `ascii_actor_group` will be included in the ASCII snapshot.
*   **`input_pos`** (`Vector2i`), **`input_action`** (`String`): Exposed properties for headless input simulation.

#### Methods

*   **`set_grid_size(w: int, h: int) -> void`**
    Resizes the grid to the specified `w` (width) and `h` (height) in cells. This method rebuilds the underlying multimesh, so it should not be called frequently.
*   **`set_cell_color(p: Vector2i, color: Color) -> void`**
    Assigns a solid `color` fill to the grid cell at position `p`.
*   **`set_cells_color_bulk(cells: PackedVector2Array, color: Color) -> void`**
    Applies a `color` fill to multiple cells efficiently.
*   **`clear_all() -> void`**
    Resets all grid cells to transparent, effectively clearing all fills, marks, strokes, and hatches.
*   **`ensure_channel(name: String) -> void`**
    Ensures a named numeric channel exists for heatmap data.
*   **`set_channel_value(name: String, p: Vector2i, v: float) -> void`**
    Writes a numeric `v` (value) to a named channel at position `p`. This data is used for heatmaps.
*   **`apply_heatmap_auto(name: String, alpha: float = 0.8) -> void`**
    Applies a heatmap visualization for the given channel `name`, automatically determining the min/max values from the channel's data.
*   **`apply_heatmap(name: String, vmin: float, vmax: float, alpha: float = 0.8) -> void`**
    Applies a heatmap visualization for the given channel `name`, mapping values between `vmin` and `vmax` to colors from the `heat_gradient`.
*   **`apply_color_map(colors: Array) -> void`**
    Applies a bulk color map (an array of `Color` objects) to the grid, typically generated by procedural world services.
*   **`set_mark(p: Vector2i, mark_type: int, color: Color = Color(1, 1, 1, 1), size01: float = 1.0, rotation_rad: float = 0.0, thickness01: float = 0.5) -> void`**
    Draws a specific `mark_type` (e.g., `DOT`, `CROSS`, `ARROW`) at position `p` with a given `color` and other visual properties.
*   **`clear_mark(p: Vector2i) -> void`**
    Removes any mark from the cell at `p`.
*   **`set_stroke(p: Vector2i, color: Color = Color(1, 1, 1, 1), thickness01: float = 0.25, corner01: float = 0.0) -> void`**
    Draws an outline (stroke) around the cell at `p` with a specified `color` and `thickness`.
*   **`clear_stroke(p: Vector2i) -> void`**
    Removes any stroke from the cell at `p`.
*   **`set_hatch(p: Vector2i, pattern: int, color: Color, scale01: float = 0.5, angle01: float = 0.0, anim01: float = 0.0) -> void`**
    Applies a hatch pattern (e.g., `CHECKER`, `DIAG`, `STRIPES`) to the cell at `p`.
*   **`stroke_outline_for(tiles: PackedVector2Array, color: Color = Color(1, 1, 1, 0.9), thickness01: float = 0.15, corner01: float = 0.0) -> void`**
    A convenience method to draw outlines around a collection of tiles, useful for highlighting paths or selected areas.
*   **`set_world_offset(offset: Vector2) -> void`**
    Sets the global offset for the renderer, useful for camera alignment.
*   **`generate_ascii_field() -> String`**
    Generates and returns a string representation of the current grid state, suitable for console output.
*   **`set_ascii_entity(p: Vector2i, symbol: String, color: Color = Color(1, 1, 1, 1), priority: int = 0, id: int = -1, z_index: int = 0) -> void`**
    Places an ASCII `symbol` at position `p`. Entities may stack, and are sorted by `priority` then `z_index`. `id` identifies the source actor for selective removal.
*   **`clear_ascii_entities() -> void`**
    Clears all ASCII entities from the grid.
*   **`remove_ascii_actor(actor: Variant) -> void`**
    Removes a specific actor's ASCII representation from the grid.
*   **`collect_ascii_entities(actors: Array) -> void`**
    Gathers ASCII entities from a list of actors, respecting their `size` and `get_ascii_z_index()` for multi-tile representation.
*   **`update_input(pos: Vector2i, action: String) -> void`**
    Simulates user input for headless tools, marking a grid location and recording the last interaction. Supported actions include `select`, `move`, `target`, `click`, `drag_start`, `drag`, `drag_end`, and `clear`.

## Usage Example

```gdscript
var grid_vis := GridRealtimeRenderer.new()
add_child(grid_vis) # Add to the scene tree

# Set the grid size (important for initialization)
grid_vis.set_grid_size(32, 32)

# Direct colors: Highlight a specific cell in red
grid_vis.set_cell_color(Vector2i(1, 2), Color.RED)

# Heatmap: Visualize a "danger" channel
grid_vis.ensure_channel("danger") # Make sure the channel exists
for y in range(grid_vis.grid_size.y):
    for x in range(grid_vis.grid_size.x):
        # Simulate some danger value based on position
        var danger_value = float(x + y) / (grid_vis.grid_size.x + grid_vis.grid_size.y) * 100.0
        grid_vis.set_channel_value("danger", Vector2i(x, y), danger_value)

grid_vis.apply_heatmap("danger", 0.0, 100.0, 0.65) # Map values 0-100 to heatmap colors with 65% opacity

# Bulk color maps: Apply a map generated by a procedural world service
# Assuming 'colors' is an Array of Colors from a map generator
# grid_vis.apply_color_map(colors)
```

## GPU Labels

For rendering text labels efficiently, especially many of them, enable `use_gpu_labels`. This batches text rendering, improving performance. Always wrap your label calls with `begin_labels()` and `end_labels()` to ensure all strings are drawn in a single optimized pass.

### Class: `GPULabelBatcher` (inherits from `Node2D`)

The `GPULabelBatcher` is an internal component used by `GridRealtimeRenderer` when `use_gpu_labels` is enabled. You typically won't interact with it directly.

#### Methods (used internally by `GridRealtimeRenderer`)

*   **`begin() -> void`**: Prepares the batcher for new labels.
*   **`push(text: String, pos: Vector2, color: Color = Color(1, 1, 1, 1)) -> void`**: Adds a single label to the batch.
*   **`end() -> void`**: Renders all batched labels.

```gdscript
# Ensure use_gpu_labels is true on your GridRealtimeRenderer instance
grid_vis.use_gpu_labels = true
grid_vis.label_font = preload("res://path/to/your_font.tres") # Set a font resource

grid_vis.begin_labels()
grid_vis.push_label("HQ", Vector2i(0,0).to_float() * grid_vis.cell_size, Color.WHITE) # Convert grid pos to world pos
grid_vis.push_label("Enemy", Vector2i(5,5).to_float() * grid_vis.cell_size, Color.RED)
grid_vis.end_labels()
```

## Vision Shaders

The renderer supports different shader modes to apply global visual effects, such as night vision or fog of war.

*   **`set_shader_mode(mode: int) -> void`**
    Switches the active shader mode. The integer `mode` corresponds to predefined visual effects.
    *   `grid_vis.set_shader_mode(1)`: Activates a "night vision" effect.
    *   `grid_vis.set_shader_mode(2)`: Activates a "fog of war" effect.

## ASCII Debug Output

`GridRealtimeRenderer` can generate a lightweight ASCII snapshot of the grid, which is incredibly useful for headless tests, CI/CD pipelines, or inspecting game state in a terminal without a graphical display.

*   The `ascii_update_sec` export controls how often the `ascii_debug` string refreshes.
*   Every interval, the renderer prints this string, enabling headless tests or external tools to inspect state.
*   The snapshot now mirrors the visual renderer more closely. Characters are assigned per cell using the same priority rules (glyph, stroke, fill, empty).
*   It can also include arbitrary actor symbols registered through `set_ascii_entity()`.
*   When `ascii_include_actors` is enabled, the renderer scans `ascii_actor_group` (default: "actors") every refresh and automatically inserts symbols for any nodes in that group.
*   Each actor can override `get_ascii_symbol()`, `get_ascii_color()`, `get_ascii_priority()`, and `get_ascii_z_index()` to customize its representation and layering in the ASCII output.
*   When `ascii_use_color` is enabled, the output uses ANSI color codes derived from the underlying cell color, allowing terminals to display the map with colored glyphs.

### Default Layer Characters in ASCII Output:

| Char | Meaning |
|------|---------|
| `*`  | Glyph layer present |
| `#`  | Outline/stroke present |
| `+`  | Filled cell |
| `.`  | Empty |

The helper `generate_ascii_field()` can be called to obtain the current snapshot on demand.

```gdscript
# Example: Manually setting an ASCII entity
grid_vis.set_ascii_entity(Vector2i(1,0), "@", Color.BLUE, 10, -1, 1)
```

The optional `priority` and `z_index` parameters determine which symbol appears when multiple entries stack in a single cell; entries sort by priority then z-index. `set_ascii_entity` silently ignores positions that fall outside the configured grid bounds so stray markers do not corrupt the snapshot.

When `collect_ascii_entities()` gathers actors, it now respects each actor's `size` property and optional `get_ascii_z_index()` method, stamping every cell in its footprint. This makes multi-tile creatures render correctly in the ASCII output.

Footprints are cached by actor so repeated calls avoid rebuilding the same offset list each frame. When an actor is removed, `remove_ascii_actor(actor)` can erase only its symbols without clearing the entire ASCII field. The renderer also tracks each actor's last position and size so `collect_ascii_entities()` only re-stamps cells for actors that moved or resized, keeping incremental updates efficient even with large casts.

### Interactive Input (Headless)

`GridRealtimeRenderer` exposes `update_input(pos, action)` to allow headless tools to simulate user interactions and mark grid locations.

*   **`update_input(pos: Vector2i, action: String) -> void`**
    Records an interaction on the ASCII grid. Supported actions:
    *   `"select"`: Highlights a cell and remembers its contents.
    *   `"move"`: Relocates the previously selected marker to a new cell.
    *   `"target"`: Marks a cell with `T` for targeting.
    *   `"click"`: Marks a cell with `C` for generic clicks.
    *   `"drag_start"`, `"drag"`, `"drag_end"`: Used to preview a path while dragging.
    *   `"clear"`: Removes all ASCII entities.

For example:

```gdscript
grid_vis.update_input(Vector2i(2,1), "select")
print(grid_vis.generate_ascii_field()) # This highlights the chosen cell with an 'X'.
```

After selecting, `move` will relocate the chosen marker, `target` paints a `T`, and `click` marks a `C`. Drag operations stream a cyan `o` along the path between the drag start and the current cursor location, allowing quick previews of potential routes. Begin a drag with `drag_start`, update it with `drag`, and finalize with `drag_end`. Paths remain until `clear` removes all markers or another drag begins.

Actors can also be polled automatically:

```gdscript
var actor := BaseActor.new() # Assuming BaseActor is defined elsewhere
actor.grid_pos = Vector2i(1,0)
actor.add_to_group("actors") # Add to the group monitored by GridRealtimeRenderer
# GridRealtimeRenderer will pick up the actor on the next refresh if ascii_include_actors is true.
```

```gdscript
var grid_vis := GridRealtimeRenderer.new()
grid_vis.grid_size = Vector2i(2,2)
grid_vis._ready() # Call _ready manually if not in scene tree
grid_vis.set_cell_color(Vector2i(0,0), Color.RED)
print(grid_vis.generate_ascii_field())
```

## Testing

`GridRealtimeRenderer` includes a self-test that verifies the ASCII snapshot and other core functionalities. Run all module tests headlessly with:

```bash
godot4 --headless --path . --script scripts/test_runner.gd
```

This command ensures the renderer behaves as expected in a non-graphical environment, which is crucial for automated testing and continuous integration.