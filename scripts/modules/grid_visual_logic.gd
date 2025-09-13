extends Node2D
class_name GridVisualLogic

const LogicGridMap = preload("res://scripts/grid/grid_map.gd")
const Logging = preload("res://scripts/core/logging.gd")

## Visual grid renderer that draws colored cells or custom draw callables.
##
## This node uses Godot's immediate drawing API to render a rectangular grid
## in real time. Cell colors or draw instructions are pulled from its
## `cell_states` dictionary. The grid's dimensions can be configured directly
## or derived from an attached `LogicGridMap` instance.

# Size of each grid cell in pixels.
var cell_size: int = 32
# Current grid dimensions measured in cells.
var grid_size: Vector2i = Vector2i(8, 8)
# Optional backing logic map; when set, its width/height override `grid_size`.
var grid_map: LogicGridMap = null
# Maps tile coordinates to either a `Color` or a `Callable` that performs custom drawing.
var cell_states: Dictionary = {}
# Stores non-error events for later inspection.
var event_log: Array = []

## Assigns a LogicGridMap and adopts its dimensions.
func set_grid_map(map: LogicGridMap) -> void:
    grid_map = map
    if map:
        grid_size = Vector2i(map.width, map.height)
    queue_redraw()

## Manually sets the grid dimensions.
func set_grid_size(width: int, height: int) -> void:
    grid_size = Vector2i(width, height)
    queue_redraw()

## Records a Color or Callable to draw on the specified cell.
func set_cell_state(pos: Vector2i, state: Variant) -> void:
    cell_states[pos] = state
    queue_redraw()

## Clears any custom state for the specified cell.
func clear_cell_state(pos: Vector2i) -> void:
    cell_states.erase(pos)
    queue_redraw()

## Replace the entire cell state dictionary with `states` and redraw.
## `states` should map `Vector2i` positions to either a `Color` or a
## `Callable` used by `_draw()`.
func update_cells(states: Dictionary, clear_existing: bool = true) -> void:
    if clear_existing:
        cell_states.clear()
    for pos in states.keys():
        cell_states[pos] = states[pos]
    queue_redraw()

## Append a structured event to the module's event log.
func log_event(t: String, actor: Object = null, pos = null, data = null) -> void:
    Logging.log(event_log, t, actor, pos, data)

## Immediate-mode drawing callback.
func _draw() -> void:
    for x in range(grid_size.x):
        for y in range(grid_size.y):
            var rect := Rect2(x * cell_size, y * cell_size, cell_size, cell_size)
            var state = cell_states.get(Vector2i(x, y), null)
            if state is Color:
                draw_rect(rect, state)
            elif state is Callable:
                state.call(self, rect)
            draw_rect(rect, Color.WHITE, false)

## Minimal self-test ensuring basic state management works.
func run_tests() -> Dictionary:
    var failed := 0
    var total := 0
    var logs: Array[String] = []

    var vis := preload("res://scripts/modules/grid_visual_logic.gd").new()
    vis.set_grid_size(2, 3)
    total += 1
    if vis.grid_size != Vector2i(2, 3):
        failed += 1
        logs.append("set_grid_size failed")

    vis.set_cell_state(Vector2i(1, 2), Color.RED)
    total += 1
    if vis.cell_states.get(Vector2i(1, 2)) != Color.RED:
        failed += 1
        logs.append("set_cell_state failed")

    var dummy_draw := func(_self, _rect): pass
    vis.set_cell_state(Vector2i(0, 0), dummy_draw)
    total += 1
    if not (vis.cell_states.get(Vector2i(0, 0)) is Callable):
        failed += 1
        logs.append("callable state not stored")

    var batch := {Vector2i(0,1): Color.BLUE, Vector2i(1,0): Color.GREEN}
    vis.update_cells(batch)
    total += 1
    if vis.cell_states.size() != 2 or vis.cell_states.get(Vector2i(0,1)) != Color.BLUE:
        failed += 1
        logs.append("update_cells failed")

    # Free the test instance to avoid leaking a CanvasItem RID
    vis.free()

    return {
        "failed": failed,
        "total": total,
        "log": "\n".join(logs),
    }
