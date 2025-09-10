extends Node2D
class_name GridRealtimeRenderer

const GPULabelBatcher = preload("res://scripts/modules/gpu_label_batcher.gd")

# Layer selection and opacity
@export var enabled_layers: Array[StringName] = ["Fill", "Heat", "Glyph", "Labels", "Outline"]
@export_range(0.0, 1.0, 0.01) var layer_opacity_fill := 1.0
@export_range(0.0, 1.0, 0.01) var layer_opacity_heat := 1.0
@export_range(0.0, 1.0, 0.01) var layer_opacity_glyph := 1.0
@export_range(0.0, 1.0, 0.01) var layer_opacity_labels := 1.0
@export_range(0.0, 1.0, 0.01) var layer_opacity_outline := 1.0

@export var world_offset: Vector2 = Vector2.ZERO

# Basic grid configuration
@export var cell_size: Vector2 = Vector2(48, 48)
@export var grid_size: Vector2i = Vector2i(16, 9)

@export var show_grid_lines := true
@export var grid_line_thickness := 1.0
@export var grid_line_modulate := Color(1, 1, 1, 0.15)

# Layer toggles derived from enabled_layers
var enable_fill := true
var enable_heat := true
var enable_marks := true
var enable_strokes := true
var enable_hatch := false

# Opacity per layer (mapped from layer_opacity_*)
var opacity_fill := 1.0
var opacity_heat := 1.0
var opacity_marks := 1.0
var opacity_strokes := 1.0
var opacity_hatch := 0.4

# Labels
@export var label_font: Font
@export var max_labels := 256
@export var use_gpu_labels := true
var _label_pool: Array[Label] = []
var _label_in_use := 0
var _gpu_batcher: GPULabelBatcher

# Vision shader modes
@export_enum("default","night_vision","fog_of_war","colorblind") var shader_mode := 0
var _palette_overlay: ColorRect
var _palette_material: ShaderMaterial

# Heatmap gradient
@export var heat_gradient: Gradient = Gradient.new()

# Multimesh objects
var _fill_mm
var _fill_mmi: MultiMeshInstance2D

var _mark_mm: MultiMesh
var _mark_mmi: MultiMeshInstance2D
var _mark_mat: ShaderMaterial

var _stroke_mm: MultiMesh
var _stroke_mmi: MultiMeshInstance2D
var _stroke_mat: ShaderMaterial

var _hatch_mm: MultiMesh
var _hatch_mmi: MultiMeshInstance2D
var _hatch_mat: ShaderMaterial

# Data
var _w := 0
var _h := 0
var _tile_count := 0
var _channels := {}
var _auto_minmax := {}
var _vis_mask := PackedFloat32Array()

var _time := 0.0
@export var ascii_update_sec := 0.5
var _ascii_accum := 0.0
var ascii_debug := ""
@export var ascii_stream_enabled := false
@export var ascii_use_color := false
@export var ascii_actor_group: StringName = "actors"
@export var ascii_include_actors := true
@export var ascii_show_facing := false

var _ascii_entities: Dictionary = {} ## maps `Vector2i` to `Array` of stacked entity dictionaries
var _footprint_cache: Dictionary = {} ## actor RID -> Array[Vector2i] relative tile offsets
var _actor_cells: Dictionary = {} ## actor RID -> Array[Vector2i] absolute cells for removal
var _actor_states: Dictionary = {} ## actor RID -> {"pos": Vector2i, "size": Vector2i}
var _symbol_map: Dictionary = {}      ## optional mapping from class/group/name to {char,color,priority,z_index}
## Terrain mapping: tag -> {char, color, priority}
var _terrain_map: Dictionary = {}
var _grid_map_ref: Object = null ## expected to expose width, height, tile_tags: Dictionary
## Done: incremental updates now touch only changed cells by tracking actor positions.
## NEXT SESSION: detect symbol/color changes without movement and add per-entity z-index for layered glyphs.

# Popup overlays (e.g., damage/heal numbers)
const _POPUP_ID := -777
var _popups: Array = [] ## each: {text: String, pos_f: Vector2, ttl: float, color: Color, drift: Vector2}
var _last_popup_cells: Array[Vector2i] = []


func _ready() -> void:
    _w = grid_size.x
    _h = grid_size.y
    _tile_count = _w * _h
    enable_fill = enabled_layers.has("Fill")
    enable_heat = enabled_layers.has("Heat")
    enable_marks = enabled_layers.has("Glyph")
    enable_strokes = enabled_layers.has("Outline")
    enable_hatch = enabled_layers.has("Debug")
    opacity_fill = layer_opacity_fill
    opacity_heat = layer_opacity_heat
    opacity_marks = layer_opacity_glyph
    opacity_strokes = layer_opacity_outline
    opacity_hatch = layer_opacity_outline
    if heat_gradient.get_point_count() == 0:
        heat_gradient.add_point(0.0, Color(0, 0, 0, 0.0))
        heat_gradient.add_point(1.0, Color(1, 0, 0, 0.75))
    _build_layers()
    _build_label_pool()
    _build_palette_overlay()
    # Disable 2D drawing by default; ASCII + logic still run.
    visible = false
    set_process(true)

func _process(delta: float) -> void:
    _time += delta
    if _mark_mat:
        _mark_mat.set_shader_parameter("u_time", _time)
    if _hatch_mat:
        _hatch_mat.set_shader_parameter("u_time", _time)
    _update_popups(delta)
    _ascii_accum += delta
    if _ascii_accum >= ascii_update_sec:
        _ascii_accum = 0.0
        if ascii_include_actors and is_inside_tree():
            var actors = get_tree().get_nodes_in_group(ascii_actor_group)
            collect_ascii_entities(actors)
        _stamp_popups()
        ascii_debug = generate_ascii_field()
        if ascii_stream_enabled:
            print(ascii_debug)

## Record an entity on the ASCII grid if `p` lies within bounds.

## Entities may stack in a single cell; entries are sorted first by `priority`
## then by `z_index` so background layers remain beneath overlays.
## `id` identifies the source actor for selective removal.
func set_ascii_entity(p: Vector2i, symbol: String, color: Color = Color.WHITE, priority: int = 0, id: int = -1, z_index: int = 0) -> void:
    if p.x < 0 or p.y < 0 or p.x >= _w or p.y >= _h:
        return
    var list: Array = _ascii_entities.get(p, [])
    list.append({"char": symbol, "color": color, "priority": priority, "id": id, "z_index": z_index})
    list.sort_custom(func(a, b):
        if int(a.priority) == int(b.priority):
            return int(a.z_index) < int(b.z_index)
        return int(a.priority) < int(b.priority)
    )
    _ascii_entities[p] = list

func clear_ascii_entities() -> void:
    _ascii_entities.clear()
    _actor_cells.clear()
    _actor_states.clear()

## Remove a specific actor's ASCII footprint using cached cell positions.
func remove_ascii_actor(actor) -> void:
    _remove_ascii_actor_rid(actor.get_instance_id())

## Internal helper that erases cached cells and state for an actor RID.
func _remove_ascii_actor_rid(rid: int) -> void:
    var cells: Array = _actor_cells.get(rid, [])
    for cell in cells:
        var list: Array = _ascii_entities.get(cell, [])
        for i in range(list.size() - 1, -1, -1):
            if int(list[i].id) == rid:
                list.remove_at(i)
        if list.is_empty():
            _ascii_entities.erase(cell)
        else:
            _ascii_entities[cell] = list
    _actor_cells.erase(rid)
    _actor_states.erase(rid)

## Populate ASCII symbols from an array of actor nodes.
## Supports multi-tile actors via their `size` property and skips out-of-bounds cells.
## Actors may implement `get_ascii_z_index()` for layered glyphs.
## This version tracks previous positions so only changed actors touch the grid.

func collect_ascii_entities(actors: Array) -> void:
    var seen: Dictionary = {} ## track which actors are processed this pass
    for actor in actors:
        if actor == null:
            continue
        var pos = actor.get("grid_pos")
        if typeof(pos) != TYPE_VECTOR2I:
            continue
        pos = pos as Vector2i
        var ch := "@"
        var col := Color.WHITE
        var priority := 0
        var z_index := 0
        # Actor-provided hooks take precedence
        if actor.has_method("get_ascii_symbol"):
            ch = actor.get_ascii_symbol()
        if actor.has_method("get_ascii_color"):
            col = actor.get_ascii_color()
        if actor.has_method("get_ascii_priority"):
            priority = int(actor.get_ascii_priority())
        if actor.has_method("get_ascii_z_index"):
            z_index = int(actor.get_ascii_z_index())
        # Fallback to symbol map when not overridden
        if ch == "@" and not _symbol_map.is_empty():
            var s = _lookup_symbol_for_actor(actor)
            if s:
                ch = String(s.get("char", ch))
                col = s.get("color", col)
                priority = int(s.get("priority", priority))
                z_index = int(s.get("z_index", z_index))

        # Optional facing indicator overrides the character with directional glyphs.
        if ascii_show_facing and actor.has_method("get") and actor.get("facing") is Vector2i:
            var f: Vector2i = actor.get("facing")
            if f == Vector2i.UP:
                ch = "^"
            elif f == Vector2i.DOWN:
                ch = "v"
            elif f == Vector2i.LEFT:
                ch = "<"
            elif f == Vector2i.RIGHT:
                ch = ">"

        var size = actor.get("size")
        if typeof(size) != TYPE_VECTOR2I:
            size = Vector2i.ONE
        else:
            size = size as Vector2i
        var rid: int = actor.get_instance_id()
        seen[rid] = true
        var prev = _actor_states.get(rid)
        ## Skip actors that haven't moved or resized since the last update
        if prev and prev.pos == pos and prev.size == size:
            continue
        ## Remove old cells before stamping the new footprint
        _remove_ascii_actor_rid(rid)
        var footprint := _get_cached_footprint(rid, size)
        var cells: Array[Vector2i] = []
        for offset in footprint:
            var cell: Vector2i = pos + offset
            set_ascii_entity(cell, ch, col, priority, rid, z_index)
            cells.append(cell)
        # Status overlay hook
        if actor.has_method("get_ascii_status_overlay"):
            var overlays = actor.get_ascii_status_overlay()
            if overlays is Array:
                for sym in overlays:
                    set_ascii_entity(pos, String(sym), Color.YELLOW, priority + 50, rid, z_index + 1)
        elif actor.has_method("get") and int(actor.get("STS")) > 0:
            set_ascii_entity(pos, "!", Color.YELLOW, priority + 50, rid, z_index + 1)
        _actor_cells[rid] = cells
        _actor_states[rid] = {"pos": pos, "size": size}
    ## Any previously tracked actors missing from this pass are removed
    for rid in Array(_actor_cells.keys()):
        if not seen.has(rid):
            _remove_ascii_actor_rid(rid)

## Retrieve a cached array of relative cell offsets for an actor's footprint.
## Footprints are keyed by actor RID and recalculated only when `size` changes.
func _get_cached_footprint(rid: int, size: Vector2i) -> Array[Vector2i]:
    var entry = _footprint_cache.get(rid)
    if entry and entry.size == size:
        return entry.tiles
    var tiles: Array[Vector2i] = []
    for y in size.y:
        for x in size.x:
            tiles.append(Vector2i(x, y))
    _footprint_cache[rid] = {"size": size, "tiles": tiles}
    return tiles


# ---------------------------------------------------------------------------
# ASCII API helpers
func get_ascii_frame() -> String:
    return generate_ascii_field()

func set_ascii_stream(enabled: bool) -> void:
    ascii_stream_enabled = enabled

func set_ascii_rate(hz: float) -> void:
    var r = max(0.001, hz)
    ascii_update_sec = 1.0 / r

func set_symbol_map(m: Dictionary) -> void:
    _symbol_map = (m if m != null else {})

func set_terrain_symbol_map(m: Dictionary) -> void:
    _terrain_map = (m if m != null else {})

func spawn_ascii_popup(text: String, pos: Vector2i, ttl: float = 1.0, color: Color = Color.WHITE, drift: Vector2 = Vector2(0, -0.6)) -> void:
    # Store sub-tile drift in floating point; stamp as overlay each frame until ttl expires.
    if text == null or text.is_empty():
        return
    var entry := {
        "text": String(text),
        "pos_f": Vector2(float(pos.x), float(pos.y)),
        "ttl": float(ttl),
        "color": color,
        "drift": drift
    }
    _popups.append(entry)

func set_grid_map(map: Object) -> void:
    _grid_map_ref = map
    # Best effort to sync grid size from the map if provided.
    if map and map.has_method("get"):
        var w = int(map.get("width"))
        var h = int(map.get("height"))
        if w > 0 and h > 0:
            set_grid_size(w, h)

func _lookup_symbol_for_actor(actor: Object) -> Dictionary:
    # Resolution order: explicit name -> class_name -> fallback "default"
    var key_name = String(actor.get("name")) if actor.has_method("get") else ""
    if key_name != "" and _symbol_map.has(key_name):
        return _symbol_map[key_name]
    var cls := ""
    if actor.has_method("get_class"):
        cls = String(actor.get_class())
        if _symbol_map.has(cls):
            return _symbol_map[cls]
    return _symbol_map.get("default", {})

# ---------------------------------------------------------------------------
# Popup overlay internals
func _update_popups(delta: float) -> void:
    if _popups.is_empty():
        return
    for i in range(_popups.size() - 1, -1, -1):
        var p = _popups[i]
        p.ttl = float(p.ttl) - delta
        p.pos_f = p.pos_f + p.drift * delta
        if p.ttl <= 0.0:
            _popups.remove_at(i)

func _remove_entries_with_id(cell: Vector2i, id: int) -> void:
    var list: Array = _ascii_entities.get(cell, [])
    if list.is_empty():
        return
    for j in range(list.size() - 1, -1, -1):
        if int(list[j].id) == id:
            list.remove_at(j)
    if list.is_empty():
        _ascii_entities.erase(cell)
    else:
        _ascii_entities[cell] = list

func _stamp_popups() -> void:
    # Clear cells used in the previous stamp pass
    for c in _last_popup_cells:
        _remove_entries_with_id(c, _POPUP_ID)
    _last_popup_cells.clear()
    if _popups.is_empty():
        return
    # Stamp each popup across its text width, left-to-right
    var used: Array[Vector2i] = []
    for p in _popups:
        var base := Vector2i(int(round(p.pos_f.x)), int(round(p.pos_f.y)))
        var txt: String = p.text
        var col: Color = p.color
        var n := txt.length()
        for k in n:
            var ch := txt.substr(k, 1)
            var cell := base + Vector2i(k, 0)
            if cell.x < 0 or cell.y < 0 or cell.x >= _w or cell.y >= _h:
                continue
            set_ascii_entity(cell, ch, col, 9000, _POPUP_ID, 999)
            used.append(cell)
    _last_popup_cells = used


# ---------------------------------------------------------------------------
# Layer construction
func _build_layers() -> void:
    var quad := QuadMesh.new()
    quad.size = cell_size

    # FILL -------------------------------------------------
    _fill_mm = MultiMesh.new()
    _fill_mm.transform_format = MultiMesh.TRANSFORM_2D
    _fill_mm.use_colors = true
    _fill_mm.mesh = quad
    _fill_mm.instance_count = _tile_count
    var idx := 0
    for y in _h:
        for x in _w:
            var xf := Transform2D.IDENTITY
            xf.origin = world_offset + Vector2(x * cell_size.x, y * cell_size.y)
            _fill_mm.set_instance_transform_2d(idx, xf)
            _fill_mm.set_instance_color(idx, Color(0,0,0,0))
            idx += 1
    _fill_mmi = MultiMeshInstance2D.new()
    _fill_mmi.name = "GridFillMMI"
    _fill_mmi.multimesh = _fill_mm
    _fill_mmi.visible = enable_fill or enable_heat
    add_child(_fill_mmi)

    # MARKS ------------------------------------------------
    _mark_mm = MultiMesh.new()
    _mark_mm.transform_format = MultiMesh.TRANSFORM_2D
    _mark_mm.use_colors = true
    _mark_mm.use_custom_data = true
    _mark_mm.mesh = quad
    _mark_mm.instance_count = _tile_count
    idx = 0
    for y in _h:
        for x in _w:
            var xf2 := Transform2D.IDENTITY
            xf2.origin = world_offset + Vector2(x * cell_size.x, y * cell_size.y)
            _mark_mm.set_instance_transform_2d(idx, xf2)
            _mark_mm.set_instance_color(idx, Color(1,1,1,0))
            _mark_mm.set_instance_custom_data(idx, Color(0,0,0,0))
            idx += 1
    _mark_mmi = MultiMeshInstance2D.new()
    _mark_mmi.name = "GridMarksMMI"
    _mark_mmi.multimesh = _mark_mm
    _mark_mi_visible_refresh()
    _mark_mat = ShaderMaterial.new()
    _mark_mat.shader = _make_mark_shader()
    _mark_mmi.material = _mark_mat
    add_child(_mark_mmi)

    # STROKES ----------------------------------------------
    _stroke_mm = MultiMesh.new()
    _stroke_mm.transform_format = MultiMesh.TRANSFORM_2D
    _stroke_mm.use_colors = true
    _stroke_mm.use_custom_data = true
    _stroke_mm.mesh = quad
    _stroke_mm.instance_count = _tile_count
    idx = 0
    for y in _h:
        for x in _w:
            var xf3 := Transform2D.IDENTITY
            xf3.origin = world_offset + Vector2(x * cell_size.x, y * cell_size.y)
            _stroke_mm.set_instance_transform_2d(idx, xf3)
            _stroke_mm.set_instance_color(idx, Color(1,1,1,0))
            _stroke_mm.set_instance_custom_data(idx, Color(0,0,0,0))
            idx += 1
    _stroke_mmi = MultiMeshInstance2D.new()
    _stroke_mmi.name = "GridStrokesMMI"
    _stroke_mmi.multimesh = _stroke_mm
    _stroke_mmi.visible = enable_strokes
    _stroke_mat = ShaderMaterial.new()
    _stroke_mat.shader = _make_stroke_shader()
    _stroke_mmi.material = _stroke_mat
    add_child(_stroke_mmi)

    # HATCH -------------------------------------------------
    if enable_hatch:
        _hatch_mm = MultiMesh.new()
        _hatch_mm.transform_format = MultiMesh.TRANSFORM_2D
        _hatch_mm.use_colors = true
        _hatch_mm.use_custom_data = true
        _hatch_mm.mesh = quad
        _hatch_mm.instance_count = _tile_count
        idx = 0
        for y in _h:
            for x in _w:
                var xf4 := Transform2D.IDENTITY
                xf4.origin = world_offset + Vector2(x * cell_size.x, y * cell_size.y)
                _hatch_mm.set_instance_transform_2d(idx, xf4)
                _hatch_mm.set_instance_color(idx, Color(1,1,1,0))
                _hatch_mm.set_instance_custom_data(idx, Color(0,0,0,0))
                idx += 1
        _hatch_mmi = MultiMeshInstance2D.new()
        _hatch_mmi.name = "GridHatchMMI"
        _hatch_mmi.multimesh = _hatch_mm
        _hatch_mmi.visible = true
        _hatch_mat = ShaderMaterial.new()
        _hatch_mat.shader = _make_hatch_shader()
        _hatch_mat.set_shader_parameter("u_opacity", opacity_hatch)
        _hatch_mmi.material = _hatch_mat
        add_child(_hatch_mmi)

func _mark_mi_visible_refresh() -> void:
    _mark_mmi.visible = enable_marks

# ---------------------------------------------------------------------------
# Label pool
func _build_label_pool():
    if use_gpu_labels:
        _gpu_batcher = GPULabelBatcher.new()
        _gpu_batcher.name = "GPULabelBatcher"
        _gpu_batcher.font = label_font
        add_child(_gpu_batcher)
    else:
        for i in max_labels:
            var l: Label = Label.new()
            l.name = "GridLabel_%d" % i
            l.visible = false
            l.modulate.a = layer_opacity_labels
            if label_font:
                l.add_theme_font_override("font", label_font)
            add_child(l)
            _label_pool.append(l)

func _build_palette_overlay() -> void:
    if shader_mode == 0:
        return
    _palette_overlay = ColorRect.new()
    _palette_overlay.name = "PaletteOverlay"
    _palette_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _palette_overlay.size = Vector2(_w * cell_size.x, _h * cell_size.y)
    _palette_overlay.position = world_offset
    _palette_overlay.z_index = 100
    _palette_material = ShaderMaterial.new()
    _palette_material.shader = load("res://scripts/shaders/vision_palette.gdshader")
    _palette_material.set_shader_parameter("mode", shader_mode)
    _palette_overlay.material = _palette_material
    add_child(_palette_overlay)

func set_shader_mode(mode: int) -> void:
    shader_mode = mode
    if _palette_material:
        _palette_material.set_shader_parameter("mode", shader_mode)
        if shader_mode == 0 and _palette_overlay:
            _palette_overlay.queue_free()
            _palette_overlay = null
            _palette_material = null
    elif shader_mode != 0:
        _build_palette_overlay()

func begin_labels():
    if use_gpu_labels and _gpu_batcher:
        _gpu_batcher.begin()
    else:
        _label_in_use = 0

func push_label(text: String, p: Vector2i, color: Color = Color.WHITE, y_offset: float = 0.0):
    if use_gpu_labels and _gpu_batcher:
        var pos := Vector2(p.x * cell_size.x + cell_size.x * 0.5, p.y * cell_size.y + cell_size.y * 0.5 + y_offset)
        var alpha := layer_opacity_labels
        if not _vis_mask.is_empty():
            alpha *= _vis_mask[_idx(p)]
        var c := Color(color.r, color.g, color.b, color.a * alpha)
        _gpu_batcher.push(text, pos, c)
    else:
        if _label_in_use >= _label_pool.size():
            return
        var l: Label = _label_pool[_label_in_use]
        _label_in_use += 1
        l.text = text
        l.position = Vector2(p.x * cell_size.x + cell_size.x * 0.5, p.y * cell_size.y + cell_size.y * 0.5 + y_offset)
        var alpha2 := layer_opacity_labels
        if not _vis_mask.is_empty():
            alpha2 *= _vis_mask[_idx(p)]
        l.modulate = Color(color.r, color.g, color.b, color.a * alpha2)
        l.visible = true
        l.z_index = 50

func end_labels():
    if use_gpu_labels and _gpu_batcher:
        _gpu_batcher.end()
    else:
        for i in range(_label_in_use, _label_pool.size()):
            _label_pool[i].visible = false

# ---------------------------------------------------------------------------
func _draw() -> void:
    if not show_grid_lines:
        return
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
    var w_px := _w * cell_size.x
    var h_px := _h * cell_size.y
    for x in _w + 1:
        var xpx := x * cell_size.x
        draw_line(Vector2(xpx, 0), Vector2(xpx, h_px), grid_line_modulate, grid_line_thickness)
    for y in _h + 1:
        var ypx := y * cell_size.y
        draw_line(Vector2(0, ypx), Vector2(w_px, ypx), grid_line_modulate, grid_line_thickness)

# ---------------------------------------------------------------------------
# Helpers
func _idx(p: Vector2i) -> int:
    return p.y * _w + p.x

func in_bounds(p: Vector2i) -> bool:
    return p.x >= 0 and p.y >= 0 and p.x < _w and p.y < _h

func _alpha_over(a: Color, b: Color) -> Color:
    var out := b
    out.r = b.r + a.r * (1.0 - b.a)
    out.g = b.g + a.g * (1.0 - b.a)
    out.b = b.b + a.b * (1.0 - b.a)
    out.a = b.a + a.a * (1.0 - b.a)
    return out

# ---------------------------------------------------------------------------
# Visibility & channels
func set_visibility(p: Vector2i, v: float) -> void:
    if _vis_mask.is_empty():
        _vis_mask.resize(_tile_count)
    if in_bounds(p):
        _vis_mask[_idx(p)] = clamp(v, 0.0, 1.0)

func ensure_channel(name: String) -> void:
    if not _channels.has(name):
        var a := PackedFloat32Array()
        a.resize(_tile_count)
        _channels[name] = a
        _auto_minmax[name] = Vector2(INF, -INF)

func set_channel_value(name: String, p: Vector2i, v: float) -> void:
    if not in_bounds(p):
        return
    ensure_channel(name)
    var i := _idx(p)
    var arr: PackedFloat32Array = _channels[name]
    arr[i] = v
    var mm: Vector2 = _auto_minmax[name]
    mm.x = min(mm.x, v)
    mm.y = max(mm.y, v)
    _auto_minmax[name] = mm

func apply_heatmap_auto(name: String, alpha: float = 0.8) -> void:
    var mm: Vector2 = _auto_minmax.get(name, Vector2(0.0, 1.0))
    apply_heatmap(name, mm.x, mm.y, alpha)

func apply_heatmap(name: String, vmin: float, vmax: float, alpha: float = 0.8) -> void:
    if not enable_heat:
        return
    if not _channels.has(name):
        return
    var arr: PackedFloat32Array = _channels[name]
    var inv_range: float = 1.0 / max(0.00001, (vmax - vmin))
    var use_vis := not _vis_mask.is_empty()
    for i in _tile_count:
        var t: float = clamp((arr[i] - vmin) * inv_range, 0.0, 1.0)
        var c: Color = heat_gradient.sample(t)
        var a: float = alpha * opacity_heat * (_vis_mask[i] if use_vis else 1.0)
        c.a *= a
        var existing: Color = _fill_mm.get_instance_color(i)
        _fill_mm.set_instance_color(i, _alpha_over(existing, c))

# Fill helpers ---------------------------------------------------------------
func set_cell_color(p: Vector2i, color: Color) -> void:
    if not in_bounds(p) or not enable_fill:
        return
    var c := color
    c.a *= opacity_fill
    if not _vis_mask.is_empty():
        c.a *= _vis_mask[_idx(p)]
    _fill_mm.set_instance_color(_idx(p), c)

func set_cells_color_bulk(cells: PackedVector2Array, color: Color):
    if not enable_fill:
        return
    for p in cells:
        var pi := Vector2i(int(p.x), int(p.y))
        if in_bounds(pi):
            var c := color
            c.a *= opacity_fill
            if not _vis_mask.is_empty():
                c.a *= _vis_mask[_idx(pi)]
            _fill_mm.set_instance_color(_idx(pi), c)

# Apply a full color map in row-major order.
# `colors` must contain at least `grid_size.x * grid_size.y` entries.
func apply_color_map(colors: Array) -> void:
    if not enable_fill:
        return
    var count: int = min(colors.size(), _tile_count)
    for i in count:
        var c: Color = colors[i]
        c.a *= opacity_fill
        if not _vis_mask.is_empty():
            c.a *= _vis_mask[i]
        _fill_mm.set_instance_color(i, c)

func clear_all() -> void:
    for i in _tile_count:
        _fill_mm.set_instance_color(i, Color(0,0,0,0))
        if enable_marks:
            _mark_mm.set_instance_color(i, Color(1,1,1,0))
        if enable_strokes:
            _stroke_mm.set_instance_color(i, Color(1,1,1,0))
        if enable_hatch:
            _hatch_mm.set_instance_color(i, Color(1,1,1,0))

# Procedural marks -----------------------------------------------------------
enum MarkType { DOT=0, RING=1, CROSS=2, X=3, TRIANGLE=4, DIAMOND=5, ARROW=6 }

func set_mark(p: Vector2i, mark_type: int, color: Color = Color.WHITE, size01: float = 1.0, rotation_rad: float = 0.0, thickness01: float = 0.5):
    if not enable_marks or not in_bounds(p):
        return
    var i := _idx(p)
    var cd := Color(float(mark_type)/255.0, clamp(size01,0.0,1.0), fposmod(rotation_rad, TAU)/TAU, clamp(thickness01,0.0,1.0))
    var c := color
    c.a *= opacity_marks
    if not _vis_mask.is_empty():
        c.a *= _vis_mask[i]
    _mark_mm.set_instance_custom_data(i, cd)
    _mark_mm.set_instance_color(i, c)

func clear_mark(p: Vector2i):
    if not enable_marks or not in_bounds(p):
        return
    var i := _idx(p)
    _mark_mm.set_instance_color(i, Color(1,1,1,0))
    _mark_mm.set_instance_custom_data(i, Color(0,0,0,0))

# Strokes --------------------------------------------------------------------
func set_stroke(p: Vector2i, color: Color = Color(1,1,1,1), thickness01: float = 0.25, corner01: float = 0.0):
    if not enable_strokes or not in_bounds(p):
        return
    var i := _idx(p)
    var cd := Color(clamp(thickness01,0.0,1.0), clamp(corner01,0.0,1.0), 0.0, 0.0)
    var c := color
    c.a *= opacity_strokes
    if not _vis_mask.is_empty():
        c.a *= _vis_mask[i]
    _stroke_mm.set_instance_custom_data(i, cd)
    _stroke_mm.set_instance_color(i, c)

func clear_stroke(p: Vector2i):
    if not enable_strokes or not in_bounds(p):
        return
    var i := _idx(p)
    _stroke_mm.set_instance_color(i, Color(1,1,1,0))

static func _v2i(x:int, y:int) -> Vector2i:
    return Vector2i(x,y)

func stroke_outline_for(tiles: PackedVector2Array, color: Color = Color(1,1,1,0.9), thickness01:=0.15, corner01:=0.0):
    if not enable_strokes:
        return
    var set := {}
    for v in tiles:
        set[Vector2i(int(v.x), int(v.y))] = true
    for k in set.keys():
        var p: Vector2i = k
        var edge := false
        for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
            if not set.has(p + d):
                edge = true
                break
        if edge:
            set_stroke(p, color, thickness01, corner01)

# Hatch ----------------------------------------------------------------------
enum Hatch { CHECKER=0, DIAG=1, STRIPES=2 }

func set_hatch(p: Vector2i, pattern: int, color: Color, scale01: float = 0.5, angle01: float = 0.0, anim01: float = 0.0):
    if not enable_hatch or not in_bounds(p):
        return
    var i := _idx(p)
    var cd := Color(float(pattern)/255.0, clamp(scale01,0.0,1.0), clamp(angle01,0.0,1.0), clamp(anim01,0.0,1.0))
    var c := color
    c.a *= opacity_hatch
    if not _vis_mask.is_empty():
        c.a *= _vis_mask[i]
    _hatch_mm.set_instance_custom_data(i, cd)
    _hatch_mm.set_instance_color(i, c)

# World offset / resizing ----------------------------------------------------
func set_world_offset(offset: Vector2):
    world_offset = offset
    var i := 0
    for y in _h:
        for x in _w:
            var xf := Transform2D.IDENTITY
            xf.origin = world_offset + Vector2(x * cell_size.x, y * cell_size.y)
            _fill_mm.set_instance_transform_2d(i, xf)
            _mark_mm.set_instance_transform_2d(i, xf)
            _stroke_mm.set_instance_transform_2d(i, xf)
            if enable_hatch:
                _hatch_mm.set_instance_transform_2d(i, xf)
            i += 1

func set_grid_size(w: int, h: int) -> void:
    grid_size = Vector2i(w, h)
    for c in get_children():
        c.queue_free()
    _ready()
    queue_redraw()

# ---------------------------------------------------------------------------
# ASCII debug
func generate_ascii_field() -> String:
    var lines: Array[String] = []
    for y in _h:
        var line := ""
        for x in _w:
            var idx := _idx(Vector2i(x, y))
            var ch := "."
            var color := Color.WHITE
            var p := Vector2i(x, y)
            if _ascii_entities.has(p):

                var ent_list: Array = _ascii_entities[p]
                var ent = ent_list[-1]
                ch = ent.char
                color = ent.color

            elif enable_marks and _mark_mm and _mark_mm.get_instance_color(idx).a > 0.01:
                ch = "*"
                color = _mark_mm.get_instance_color(idx)
            elif enable_strokes and _stroke_mm and _stroke_mm.get_instance_color(idx).a > 0.01:
                ch = "#"
                color = _stroke_mm.get_instance_color(idx)
            elif enable_fill and _fill_mm and _fill_mm.get_instance_color(idx).a > 0.01:
                ch = "+"
                color = _fill_mm.get_instance_color(idx)
            elif _grid_map_ref and typeof(_terrain_map) == TYPE_DICTIONARY and not _terrain_map.is_empty():
                var tags: Array = []
                # grid_map_ref.tile_tags is a Dictionary keyed by Vector2i -> Array[String]
                if _grid_map_ref.has_method("get"):
                    var tt = _grid_map_ref.get("tile_tags")
                    if typeof(tt) == TYPE_DICTIONARY and tt.has(p):
                        tags = tt[p]
                var best = null
                var best_pri := -999999
                for t in tags:
                    if _terrain_map.has(t):
                        var e = _terrain_map[t]
                        var pri = int(e.get("priority", 0))
                        if pri >= best_pri:
                            best_pri = pri
                            best = e
                if best:
                    ch = String(best.get("char", ch))
                    color = best.get("color", color)
            if ascii_use_color:
                line += _ansi_color(color) + ch + "\u001b[0m"
            else:
                line += ch
        lines.append(line)
    return "\n".join(lines)

func _ansi_color(c: Color) -> String:
    var r := int(clamp(c.r * 255.0, 0, 255))
    var g := int(clamp(c.g * 255.0, 0, 255))
    var b := int(clamp(c.b * 255.0, 0, 255))
    return "\u001b[38;2;%d;%d;%dm" % [r, g, b]

# ---------------------------------------------------------------------------
# Interactive ASCII input
## Exposed input fields for grid coordinate and action.
@export var input_pos: Vector2i = Vector2i.ZERO
@export var input_action: String = ""

var _selected_pos: Vector2i = Vector2i(-1, -1)
var _selected_char: String = ""
var _selected_color: Color = Color.WHITE
var _selected_priority: int = 0
const DRAG_PATH_ID := -1000 ## identifier used for transient drag preview glyphs
var _drag_start: Vector2i = Vector2i(-1, -1) ## starting tile of an active drag operation

## Record an interaction on the ASCII grid.
## Supported actions:
## - "select" : highlight a cell and remember its contents
## - "move"   : move the previously selected marker to a new cell
## - "target" : mark a cell with `T` for targeting
## - "click"  : mark a cell with `C` for generic clicks
## - "drag_start"/"drag"/"drag_end" : preview a path while dragging
## - "clear"  : remove all ASCII entities
func update_input(pos: Vector2i, action: String) -> void:
    input_pos = pos
    input_action = action
    match action:
        "select":

            var ent_list: Array = _ascii_entities.get(pos, [])
            if ent_list and not ent_list.is_empty():
                var ent = ent_list[-1]

                _selected_char = ent.char
                _selected_color = ent.color
                _selected_priority = ent.priority
            else:
                _selected_char = "@"
                _selected_color = Color.WHITE
                _selected_priority = 0
            _selected_pos = pos

            set_ascii_entity(pos, "X", Color.YELLOW, 1000)
        "move":
            var list: Array = _ascii_entities.get(_selected_pos, [])
            if _selected_pos != Vector2i(-1, -1):
                if list.size() > 0:
                    list.pop_back() # remove highlight
                    if list.size() > 0:
                        list.pop_back() # remove selected entity
                if list.is_empty():
                    _ascii_entities.erase(_selected_pos)
                else:
                    _ascii_entities[_selected_pos] = list
                set_ascii_entity(pos, _selected_char, _selected_color, _selected_priority)
                _selected_pos = pos
        "target":
            set_ascii_entity(pos, "T", Color.GREEN, 1000)
        "click":
            set_ascii_entity(pos, "C", Color.RED, 1000)
        "drag_start":
            _drag_start = pos
            _render_drag_path(pos)
        "drag":
            if _drag_start != Vector2i(-1, -1):
                _render_drag_path(pos)
        "drag_end":
            if _drag_start != Vector2i(-1, -1):
                _render_drag_path(pos)
            _drag_start = Vector2i(-1, -1)
        "clear":
            clear_ascii_entities()
        _:
            pass

## Generate a temporary ASCII path from `_drag_start` to `end_pos`.
## Existing path glyphs are cleared before the new path is stamped.
func _render_drag_path(end_pos: Vector2i) -> void:
    _remove_ascii_actor_rid(DRAG_PATH_ID)
    var tiles: Array[Vector2i] = _bresenham(_drag_start, end_pos)
    var cells: Array[Vector2i] = []
    for p in tiles:
        set_ascii_entity(p, "o", Color.CYAN, 900, DRAG_PATH_ID)
        cells.append(p)
    _actor_cells[DRAG_PATH_ID] = cells

## Compute all integer grid points between two coordinates using
## Bresenham's line algorithm.
func _bresenham(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
    ## Fully typed implementation of Bresenham's line algorithm to avoid
    ## Variant inference warnings under Godot's strict typing mode.
    var pts: Array[Vector2i] = []
    var x0: int = a.x
    var y0: int = a.y
    var x1: int = b.x
    var y1: int = b.y
    var dx: int = abs(x1 - x0)
    var dy: int = -abs(y1 - y0)
    var sx: int = 1 if x0 < x1 else -1
    var sy: int = 1 if y0 < y1 else -1
    var err: int = dx + dy
    while true:
        pts.append(Vector2i(x0, y0))
        if x0 == x1 and y0 == y1:
            break
        var e2: int = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy
    return pts

func _get_top_ascii_entity(p: Vector2i):
    var ents = _ascii_entities.get(p)
    if ents == null or ents.size() == 0:
        return null
    var best = ents[0]
    for e in ents:
        if e.priority > best.priority:
            best = e
    return best

class _MockMM:
    var colors: Array[Color] = []
    func _init(count: int):
        colors.resize(count)
        for i in count:
            colors[i] = Color(0,0,0,0)
    func set_instance_color(i: int, c: Color) -> void:
        colors[i] = c
    func get_instance_color(i: int) -> Color:
        return colors[i]

func run_tests() -> Dictionary:
    var result := {"total": 16, "failed": 0}

    _w = 2
    _h = 2
    _tile_count = 4
    enable_fill = true
    enable_marks = false
    enable_strokes = false
    _fill_mm = _MockMM.new(_tile_count)
    set_cell_color(Vector2i(0,0), Color.RED)
    ascii_use_color = false
    ascii_debug = generate_ascii_field()
    if ascii_debug != "+.\n..":
        result.failed += 1
        result.log = "ASCII field mismatch: %s" % ascii_debug
    set_ascii_entity(Vector2i(1,0), "@", Color.BLUE)
    ascii_debug = generate_ascii_field()
    if ascii_debug != "+@\n..":
        result.failed += 1
        result.log = "ASCII entity mismatch: %s" % ascii_debug
    clear_ascii_entities()
    set_ascii_entity(Vector2i(0,0), "@", Color.WHITE, 0)
    set_ascii_entity(Vector2i(0,0), "#", Color.RED, 1)
    ascii_debug = generate_ascii_field()
    if ascii_debug != "#.\n..":
        result.failed += 1
        result.log = "Priority stacking mismatch: %s" % ascii_debug
    clear_ascii_entities()
    set_ascii_entity(Vector2i(-1,0), "#", Color.WHITE)
    ascii_debug = generate_ascii_field()
    if ascii_debug != "+.\n..":
        result.failed += 1
        result.log = "Out-of-bounds entity affected field: %s" % ascii_debug
    clear_ascii_entities()
    set_ascii_entity(Vector2i(0,0), "A", Color.WHITE, 0)
    set_ascii_entity(Vector2i(0,0), "B", Color.WHITE, 1)
    ascii_debug = generate_ascii_field()
    if ascii_debug != "B.\n..":
        result.failed += 1
        result.log = "Priority stacking mismatch: %s" % ascii_debug
    clear_ascii_entities()
    set_ascii_entity(Vector2i(0,0), "A", Color.WHITE, 0, -1, 0)
    set_ascii_entity(Vector2i(0,0), "B", Color.WHITE, 0, -1, 1)
    ascii_debug = generate_ascii_field()
    if ascii_debug != "B.\n..":
        result.failed += 1
        result.log = "Z-index stacking mismatch: %s" % ascii_debug
    update_input(Vector2i(0,0), "select")
    if _selected_char != "B":
        result.failed += 1
        result.log = "Selection priority mismatch: %s" % _selected_char
    clear_ascii_entities()
    update_input(Vector2i(1,0), "select")
    ascii_debug = generate_ascii_field()
    if ascii_debug != "+X\n..":
        result.failed += 1
        result.log = "Input handling mismatch: %s" % ascii_debug
    clear_ascii_entities()
    update_input(Vector2i(0,1), "target")
    ascii_debug = generate_ascii_field()
    if ascii_debug != "+.\nT.":
        result.failed += 1
        result.log = "Target action mismatch: %s" % ascii_debug
    clear_ascii_entities()
    update_input(Vector2i(1,1), "click")
    ascii_debug = generate_ascii_field()
    if ascii_debug != "+.\n.C":
        result.failed += 1
        result.log = "Click action mismatch: %s" % ascii_debug
    clear_ascii_entities()
    set_ascii_entity(Vector2i(0,0), "@", Color.BLUE)
    update_input(Vector2i(0,0), "select")
    update_input(Vector2i(1,1), "move")
    ascii_debug = generate_ascii_field()
    if ascii_debug != "+.\n.@":
        result.failed += 1
        result.log = "Move action mismatch: %s" % ascii_debug
    clear_ascii_entities()
    var BaseActor = preload("res://scripts/core/base_actor.gd")
    var actor = BaseActor.new("test")
    actor.grid_pos = Vector2i(1,1)
    collect_ascii_entities([actor])
    ascii_debug = generate_ascii_field()
    if ascii_debug != "+.\n.@":
        result.failed += 1
        result.log = "Actor collection mismatch: %s" % ascii_debug
    clear_ascii_entities()
    var removable = BaseActor.new("rem")
    removable.grid_pos = Vector2i(0,0)
    collect_ascii_entities([removable])
    remove_ascii_actor(removable)
    ascii_debug = generate_ascii_field()
    if ascii_debug != "+.\n..":
        result.failed += 1
        result.log = "Removal mismatch: %s" % ascii_debug
    clear_ascii_entities()
    var big_actor = BaseActor.new("big")
    big_actor.grid_pos = Vector2i(0,0)
    big_actor.size = Vector2i(2,2)
    collect_ascii_entities([big_actor])
    ascii_debug = generate_ascii_field()
    if ascii_debug != "@@\n@@":
        result.failed += 1
        result.log = "Multi-tile actor mismatch: %s" % ascii_debug
    clear_ascii_entities()
    ascii_use_color = true
    ascii_debug = generate_ascii_field()
    if ascii_debug.find("\u001b[38;2;255;0;0m") == -1:
        result.failed += 1
        result.log = "Missing color codes: %s" % ascii_debug
    ascii_use_color = false
    clear_ascii_entities()
    var mover = BaseActor.new("mover")
    mover.grid_pos = Vector2i(0,0)
    collect_ascii_entities([mover])
    mover.grid_pos = Vector2i(1,1)
    collect_ascii_entities([mover])
    ascii_debug = generate_ascii_field()
    if ascii_debug != "+.\n.@":
        result.failed += 1
        result.log = "Move update mismatch: %s" % ascii_debug
    collect_ascii_entities([])
    ascii_debug = generate_ascii_field()
    if ascii_debug != "+.\n..":
        result.failed += 1
        result.log = "Auto-removal mismatch: %s" % ascii_debug
    clear_ascii_entities()
    update_input(Vector2i(0,0), "drag_start")
    update_input(Vector2i(1,1), "drag")
    ascii_debug = generate_ascii_field()
    if ascii_debug != "o.\n.o":
        result.failed += 1
        result.log = "Drag path mismatch: %s" % ascii_debug
    update_input(Vector2i(1,1), "drag_end")
    if _drag_start != Vector2i(-1,-1):
        result.failed += 1
        result.log = "Drag end did not reset start: %s" % str(_drag_start)
    return result

# ---------------------------------------------------------------------------
# Shaders
func _make_mark_shader() -> Shader:
    var s := Shader.new()
    s.code = """
shader_type canvas_item;

uniform float u_time = 0.0;
uniform float u_global_opacity = 1.0;

float sd_circle(vec2 p, float r) { return length(p) - r; }
float sd_box(vec2 p, vec2 b) { vec2 d = abs(p) - b; return length(max(d,0.0)) + min(max(d.x,d.y),0.0); }
float stroke(float d, float th) { return smoothstep(th, th-1.0, d); }
vec2 rot(vec2 p, float a){ float s = sin(a), c = cos(a); return mat2(vec2(c, -s), vec2(s, c)) * p; }
float sd_cross(vec2 p, float w, float h){ float a = sd_box(p, vec2(w, h)); p = vec2(p.y, p.x); float b = sd_box(p, vec2(w, h)); return min(a, b); }
float sd_x(vec2 p, float w, float h){ p = rot(p, 0.78539816339); return sd_cross(p, w, h); }
float sd_triangle_up(vec2 p, float s){ p.y += s*0.25; vec2 k = vec2(0.8660254, 0.5); p.x = abs(p.x); float m = p.y + k.x * p.x - s*0.5; float d = max(m, p.y - s*0.5); return d; }
float sd_diamond(vec2 p, float s){ return sd_box(rot(p, 0.78539816339), vec2(s,s)*0.5); }
float sd_arrow(vec2 p, float s){ float head = sd_triangle_up(p, s); float tail = sd_box(p + vec2(0.0, s*0.25), vec2(s*0.12, s*0.35)); return min(head, tail); }

void fragment(){
    vec2 uv = UV * 2.0 - 1.0;
    vec4 inst = vec4(0.0);
    #ifdef INSTANCE_CUSTOM
    inst = INSTANCE_CUSTOM;
    #endif
    int t = int(inst.r * 255.0 + 0.5);
    float size = clamp(inst.g, 0.0, 1.0);
    float rotz = inst.b * 6.28318530718;
    float thick = max(0.001, inst.a * 0.25);
    vec4 col = vec4(1.0);
    #ifdef INSTANCE_COLOR
    col = INSTANCE_COLOR;
    #endif
    col.a *= u_global_opacity;
    uv = rot(uv, rotz);
    float s = size;
    float d = 0.0;
    if (t == 0){ d = sd_circle(uv, s*0.35); col.a *= 1.0 - smoothstep(0.0, 0.01, d); }
    else if (t == 1){ float d0 = abs(sd_circle(uv, s*0.4)); col.a *= stroke(d0, thick*0.1); }
    else if (t == 2){ float d0 = sd_cross(uv, s*0.08, s*0.35); col.a *= stroke(d0, thick*0.08); }
    else if (t == 3){ float d0 = sd_x(uv, s*0.08, s*0.35); col.a *= stroke(d0, thick*0.08); }
    else if (t == 4){ float d0 = sd_triangle_up(uv, s*0.9); col.a *= stroke(d0, thick*0.08); }
    else if (t == 5){ float d0 = sd_diamond(uv, s*0.9); col.a *= stroke(d0, thick*0.08); }
    else { float d0 = sd_arrow(uv, s*0.9); col.a *= stroke(d0, thick*0.08); }
    if (col.a <= 0.001){ discard; }
    COLOR = col;
}
"""
    return s

func _make_stroke_shader() -> Shader:
    var s := Shader.new()
    s.code = """
shader_type canvas_item;
uniform float u_global_opacity = 1.0;

float sd_box(vec2 p, vec2 b) { vec2 d = abs(p) - b; return length(max(d,0.0)) + min(max(d.x,d.y),0.0); }
float stroke(float d, float w) { return smoothstep(w, w-1.0, d); }

void fragment(){
    vec2 uv = UV * 2.0 - 1.0;
    vec4 inst = vec4(0.0);
    #ifdef INSTANCE_CUSTOM
    inst = INSTANCE_CUSTOM;
    #endif
    float th = max(0.001, inst.r * 0.25);
    float rad = clamp(inst.g, 0.0, 1.0) * 0.25;
    vec2 b = vec2(1.0 - th - rad);
    float d = sd_box(uv, b) - rad;
    vec4 c = vec4(1.0);
    #ifdef INSTANCE_COLOR
    c = INSTANCE_COLOR;
    #endif
    c.a *= stroke(abs(d), 0.5) * u_global_opacity;
    if (c.a <= 0.001){ discard; }
    COLOR = c;
}
"""
    return s

func _make_hatch_shader() -> Shader:
    var s := Shader.new()
    s.code = """
shader_type canvas_item;
uniform float u_opacity = 0.4;
uniform float u_time = 0.0;

vec2 rot(vec2 p, float a){ float s=sin(a), c=cos(a); return mat2(vec2(c, -s), vec2(s, c)) * p; }

void fragment(){
    vec2 uv = (UV - 0.5) * 2.0;
    vec4 inst = vec4(0.0);
    #ifdef INSTANCE_CUSTOM
    inst = INSTANCE_CUSTOM;
    #endif
    int pid = int(inst.r * 255.0 + 0.5);
    float sc = mix(6.0, 24.0, inst.g);
    float ang = inst.b * 1.57079632679;
    float anim = inst.a;
    vec4 col = vec4(1.0);
    #ifdef INSTANCE_COLOR
    col = INSTANCE_COLOR;
    #endif
    col.a *= u_opacity;
    vec2 p = rot(uv, ang);
    float m = 0.0;
    if (pid == 0){ vec2 c = floor((p*sc + vec2(u_time*anim, 0.0))); m = mod(c.x + c.y, 2.0); }
    else if (pid == 1){ float v = floor((p.x + p.y) * sc + u_time*anim); m = mod(v,2.0); }
    else { float v = floor(p.x * sc + u_time*anim); m = mod(v,2.0); }
    if (m < 0.5){ discard; }
    COLOR = col;
}
"""
    return s
