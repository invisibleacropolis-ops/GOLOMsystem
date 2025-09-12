extends Node2D
class_name GridInteractor

## Provides mouse interaction utilities for grid-based games.
##
## This node translates mouse input into tile coordinates and exposes
## signals for click and marquee selection. It expects references to a
## `GridRealtimeRenderer` for preview drawing and a grid logic node that
## can report actor occupancy. The implementation follows the design
## supplied in the project brief and remains compatible with both main
## viewports and `SubViewport` setups.

signal tile_clicked(tile: Vector2i, button: int, modifiers: int)
signal tiles_selected(tiles: PackedVector2Array, additive: bool, toggle: bool)
signal actor_clicked(actor_id, tile: Vector2i, button: int, modifiers: int)
signal actors_selected(actor_ids: Array, tiles: PackedVector2Array, additive: bool, toggle: bool)

@export var grid_renderer_path: NodePath
@export var grid_logic_path: NodePath

@onready var _vis := get_node_or_null(grid_renderer_path)
@onready var _logic := get_node_or_null(grid_logic_path)

# --- Tunables ---
@export var click_drag_threshold_px := 6.0
@export var drag_preview_color := Color(0.2, 0.9, 1.0, 0.6)
@export var drag_outline_color := Color(0.2, 1.0, 0.9, 0.95)
@export var drag_outline_thickness := 0.14
@export var drag_outline_corner := 0.04
@export var select_fill_color := Color(0.0, 0.6, 1.0, 0.28)

# --- State ---
var _press_screen_pos := Vector2.ZERO
var _press_tile := Vector2i(-1, -1)
var _dragging := false
var _last_drag_rect_tiles: PackedVector2Array = PackedVector2Array()
var _right_dragging := false
var _press_offset := Vector2.ZERO
var _path_actor: Object = null
var _hover_tile := Vector2i(-1, -1)
var _path_mark_tiles: PackedVector2Array = PackedVector2Array()

@export var path_mark_color := Color(1.0, 0.9, 0.2, 0.9)

func _ready() -> void:
    set_process_unhandled_input(true)
    _clear_drag_preview()

# Coordinate helpers ----------------------------------------------------------

func _mouse_world() -> Vector2:
    return get_global_mouse_position()

func world_to_tile(world_pos: Vector2) -> Vector2i:
    var local = world_pos - _vis.world_offset
    var cs = _vis.cell_size
    return Vector2i(floor(local.x / cs.x), floor(local.y / cs.y))

func _tile_in_bounds(p: Vector2i) -> bool:
    return _vis.in_bounds(p)

func _tile_has_actor(p: Vector2i) -> bool:
    if _logic == null:
        return false
    if _logic.has_method("has_actor_at"):
        return _logic.has_actor_at(p)
    if _logic.has_method("is_occupied"):
        return _logic.is_occupied(p)
    return false

func _actor_at_tile(p: Vector2i):
    if _logic and _logic.has_method("get_actor_at"):
        return _logic.get_actor_at(p)
    return null

# Path preview ---------------------------------------------------------------

## Set the actor used for path previews. The actor's current tile will be
## used as the origin when generating hover paths.
func set_path_preview_actor(actor: Object) -> void:
    _path_actor = actor
    _hover_tile = Vector2i(-1, -1)
    _clear_path_marks()

## Clear any existing path preview and detach the tracked actor.
func clear_path_preview() -> void:
    _path_actor = null
    _hover_tile = Vector2i(-1, -1)
    _clear_path_marks()

func _clear_path_marks() -> void:
    if _path_mark_tiles.is_empty():
        return
    if _vis and _vis.has_method("clear_mark"):
        for v in _path_mark_tiles:
            _vis.clear_mark(Vector2i(int(v.x), int(v.y)))
    _path_mark_tiles = PackedVector2Array()

func _preview_path_to(tile: Vector2i) -> void:
    if _path_actor == null or _logic == null or _vis == null:
        return
    if not _tile_in_bounds(tile):
        _clear_path_marks()
        return
    if tile == _hover_tile:
        return
    _hover_tile = tile
    _clear_path_marks()

    var start := Vector2i(-1, -1)
    if _logic.has("actor_positions"):
        start = _logic.actor_positions.get(_path_actor, Vector2i(-1, -1))
    if start.x < 0:
        return
    var path: Array[Vector2i] = []
    if _logic.has_method("find_path_for_actor"):
        path = _logic.find_path_for_actor(_path_actor, start, tile)
    elif _logic.has_method("find_path"):
        path = _logic.find_path(start, Vector2i.RIGHT, tile, Vector2i.ONE)
    if path.is_empty():
        return
    for i in range(1, path.size()):
        var step: Vector2i = path[i]
        var prev: Vector2i = path[i - 1]
        var rot := (step - prev).angle()
        if _vis.has_method("set_mark"):
            _vis.set_mark(step, 0, path_mark_color, 1.0, rot)
        _path_mark_tiles.push_back(step)

# Input handling --------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            _on_left_press(event)
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            _on_right_press(event)

    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        _on_drag_motion(event)
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        _on_right_drag_motion(event)
    elif event is InputEventMouseMotion:
        _on_hover_motion(event)

    elif event is InputEventMouseButton and not event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            _on_left_release(event)
        elif event.button_index == MOUSE_BUTTON_RIGHT:
            _on_right_release(event)

# Press / Drag / Release ------------------------------------------------------

func _on_left_press(ev: InputEventMouseButton) -> void:
    _press_screen_pos = ev.position
    _press_tile = world_to_tile(_mouse_world())
    _dragging = false
    _clear_drag_preview()
    _clear_path_marks()

func _on_drag_motion(ev: InputEventMouseMotion) -> void:
    if _press_tile.x < 0:
        return
    if _dragging == false and ev.position.distance_to(_press_screen_pos) >= click_drag_threshold_px:
        _dragging = true
    if _dragging:
        var cur_tile := world_to_tile(_mouse_world())
        _preview_drag_rect(_press_tile, cur_tile)

func _on_hover_motion(ev: InputEventMouseMotion) -> void:
    if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        return
    var tile := world_to_tile(_mouse_world())
    _preview_path_to(tile)

func _on_left_release(ev: InputEventMouseButton) -> void:
    var mods := _mod_bits()
    var additive := (mods & 1) != 0
    var toggle := (mods & 2) != 0
    var rel_tile := world_to_tile(_mouse_world())

    if _dragging:
        var rect_tiles := _tiles_in_rect(_press_tile, rel_tile)
        _emit_selection(rect_tiles, additive, toggle)
    else:
        if not _tile_in_bounds(_press_tile):
            return
        if _tile_has_actor(_press_tile):
            var actor_id = _actor_at_tile(_press_tile)
            actor_clicked.emit(actor_id, _press_tile, MOUSE_BUTTON_LEFT, mods)
        else:
            tile_clicked.emit(_press_tile, MOUSE_BUTTON_LEFT, mods)

    _clear_drag_preview()
    _dragging = false
    _press_tile = Vector2i(-1, -1)

func _on_right_press(ev: InputEventMouseButton) -> void:
    _right_dragging = false
    _press_screen_pos = ev.position
    _press_offset = _vis.world_offset
    _clear_drag_preview()

func _on_right_release(ev: InputEventMouseButton) -> void:
    var t := world_to_tile(_mouse_world())
    if _right_dragging:
        _right_dragging = false
        return
    if _tile_in_bounds(t):
        tile_clicked.emit(t, MOUSE_BUTTON_RIGHT, _mod_bits())
    else:
        _clear_drag_preview()

func _on_right_drag_motion(ev: InputEventMouseMotion) -> void:
    if ev.position.distance_to(_press_screen_pos) >= click_drag_threshold_px:
        _right_dragging = true
    if _right_dragging:
        var delta := ev.position - _press_screen_pos
        _vis.world_offset = _press_offset - delta

# Modifiers (Shift=add, Ctrl/Cmd=toggle) -------------------------------------

func _mod_bits() -> int:
    var m := 0
    if Input.is_key_pressed(KEY_SHIFT):
        m |= 1
    if Input.is_key_pressed(KEY_CTRL) or Input.is_key_pressed(KEY_META):
        m |= 2
    return m

# Drag rectangle -> tile list -------------------------------------------------

static func _minmax(a: int, b: int) -> Array:
    return [min(a, b), max(a, b)]

func _tiles_in_rect(a: Vector2i, b: Vector2i) -> PackedVector2Array:
    var out := PackedVector2Array()
    var xs := _minmax(a.x, b.x)
    var ys := _minmax(a.y, b.y)
    for y in range(ys[0], ys[1] + 1):
        for x in range(xs[0], xs[1] + 1):
            var p := Vector2i(x, y)
            if _tile_in_bounds(p):
                out.push_back(Vector2(p))
    return out

# Preview painting ------------------------------------------------------------

func _preview_drag_rect(a: Vector2i, b: Vector2i) -> void:
    _clear_drag_preview()
    var tiles := _tiles_in_rect(a, b)
    _last_drag_rect_tiles = tiles
    if tiles.size() == 0:
        return
    if _vis.has_method("set_cells_color_bulk"):
        _vis.set_cells_color_bulk(tiles, select_fill_color)
    if _vis.has_method("stroke_outline_for"):
        _vis.stroke_outline_for(tiles, drag_outline_color, drag_outline_thickness, drag_outline_corner)

func _clear_drag_preview() -> void:
    if _last_drag_rect_tiles.size() == 0:
        return
    _vis.clear_all()
    _last_drag_rect_tiles = PackedVector2Array()

# Selection emission ----------------------------------------------------------

func _emit_selection(tiles: PackedVector2Array, additive: bool, toggle: bool) -> void:
    tiles_selected.emit(tiles, additive, toggle)
    var actors := []
    if _logic and _logic.has_method("get_actor_at"):
        var seen := {}
        for v in tiles:
            var p := Vector2i(int(v.x), int(v.y))
            if _tile_has_actor(p):
                var id = _actor_at_tile(p)
                if not seen.has(id):
                    seen[id] = true
                    actors.append(id)
    if actors.size() > 0:
        actors_selected.emit(actors, tiles, additive, toggle)
