# GridVisualLogic Module

`GridVisualLogic` is a `Node2D` that renders a rectangular grid using Godot's immediate drawing API. It serves as the visual companion to `LogicGridMap` by painting each tile according to a supplied state.

## Features
- Configurable grid dimensions and cell size.
- Optional connection to a `LogicGridMap` resource to adopt its width and height.
- Per-cell state dictionary accepting either:
  - a `Color` to fill the tile, or
  - a `Callable` that receives `(self, Rect2)` to perform custom drawing.
- Lightweight `run_tests()` helper verifying basic state management.
- Batch `update_cells(states)` helper for applying many tile changes at once.

## Usage
```gdscript
var map := LogicGridMap.new()
map.width = 4
map.height = 3
var vis := GridVisualLogic.new()
vis.set_grid_map(map)
vis.set_cell_state(Vector2i(1, 1), Color.RED)
add_child(vis)
```

Custom drawing example:
```gdscript
vis.set_cell_state(Vector2i(0, 0), func(self, rect):
    self.draw_circle(rect.position + rect.size / 2, rect.size.x / 2, Color.YELLOW))
```

The module can be tested headlessly via the shared test runner:
```bash
godot4 --headless --path . --script scripts/test_runner.gd
```

## API Summary

| Property/Method | Purpose |
|-----------------|---------|
| `cell_size` | Pixel dimensions of each grid tile. |
| `grid_size` | `Vector2i` counting tiles in x/y.  Updated automatically when a `LogicGridMap` is assigned. |
| `set_grid_map(map)` | Attach a `LogicGridMap` and adopt its dimensions. |
| `set_grid_size(w, h)` | Manually specify width and height in tiles. |
| `set_cell_state(pos, state)` | Assign a `Color` or `Callable` to a tile.  Callables receive `(self, Rect2)` during `_draw()` |
| `clear_cell_state(pos)` | Remove state for a tile. |
| `update_cells(states)` | Replace cell states using a `{pos: Color/Callable}` dictionary. |

## Integration Notes

- Use this node strictly for visualization or debugging; it does not own game state.
- When embedding in a scene, call `queue_redraw()` after modifying states to refresh the display.
- To avoid leaks in unit tests, free instances that inherit from `CanvasItem` once done.

## Testing

Run the built-in self-test via:

```bash
godot4 --headless --path . --script scripts/test_runner.gd -- --module=grid_visual_logic
```

The test verifies cell size assignment, color storage, and callable handling.

