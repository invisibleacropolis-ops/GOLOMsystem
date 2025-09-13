extends Camera3D
class_name IsometricCamera3D

@export var grid_root_path: NodePath
@export var overlay_control_path: NodePath
@export var yaw_deg: float = 45.0
@export var pitch_deg: float = -35.264  # classic isometric tilt
@export var margin_ratio: float = 0.06  # extra padding around bounds
@export var zoom_speed: float = 1.07
@export var min_size: float = 4.0
@export var max_size: float = 300.0
@export var orbit_speed: float = 0.25
@export var pan_speed: float = 0.35
@export var pan_radius: float = 0.0  # world units; 0 = auto (derived from grid size)
@export var debug_logging: bool = false  # emits to WorkspaceDebugger and stdout
@export var controls_enabled: bool = true  # toggled by UI to enable/disable camera input

var _drag_orbit := false
var _drag_pan := false
var _last_mouse := Vector2.ZERO
var _target_center := Vector3.ZERO
var _target_dist := 40.0
var _home_center := Vector3.ZERO
var _pan_limit := 20.0
var _last_log_time := 0.0

func _ready() -> void:
    projection = PROJECTION_ORTHOGONAL
    # Defer so the 3D GridMap has time to be added by the controller.
    call_deferred("_fit_view")
    _log("ready: yaw=%s pitch=%s" % [str(yaw_deg), str(pitch_deg)])

func _fit_view() -> void:
    if not is_inside_tree():
        return
    var grid_map = _find_grid_map()
    if grid_map == null:
        return
    var cell: Vector3 = grid_map.cell_size if grid_map.has_method("get") else Vector3.ONE
    var used: Array = grid_map.get_used_cells()
    if used.is_empty():
        return
    var min_x = used[0].x; var max_x = used[0].x
    var min_z = used[0].z; var max_z = used[0].z
    for c in used:
        min_x = min(min_x, c.x); max_x = max(max_x, c.x)
        min_z = min(min_z, c.z); max_z = max(max_z, c.z)
    var width_world: float = (max_x - min_x + 1) * cell.x
    var height_world: float = (max_z - min_z + 1) * cell.z
    var center_world = Vector3((min_x + max_x + 1) * 0.5 * cell.x, 0.0, (min_z + max_z + 1) * 0.5 * cell.z)

    # Configure isometric orientation (yaw then pitch).
    var basis = Basis()
    # Apply pitch around the camera's local X after yaw, so the ground
    # lays horizontally (sky up, ground down) instead of skewing vertically.
    basis = basis.rotated(Vector3.UP, deg_to_rad(yaw_deg))
    basis = basis.rotated(basis.x, deg_to_rad(pitch_deg))
    global_transform.basis = basis
    # Place camera along its forward vector looking at center
    var fwd = -basis.z
    _target_center = center_world
    _home_center = center_world
    # Configure pan limit (auto if not explicitly set)
    _pan_limit = (pan_radius if pan_radius > 0.0 else max(width_world, height_world) * 0.35)
    _log("fit_view: center=%s size(ortho)=%s pan_limit=%s" % [str(_target_center), str(size), str(_pan_limit)])
    _target_dist = 40.0
    global_transform.origin = _target_center - fwd * _target_dist

    # Compute orthographic size to fit bounds into target region.
    var corners = [
        Vector3(min_x * cell.x, 0.0, min_z * cell.z),
        Vector3((max_x + 1) * cell.x, 0.0, min_z * cell.z),
        Vector3(min_x * cell.x, 0.0, (max_z + 1) * cell.z),
        Vector3((max_x + 1) * cell.x, 0.0, (max_z + 1) * cell.z),
    ]
    var min_lx = INF; var max_lx = -INF
    var min_ly = INF; var max_ly = -INF
    for p in corners:
        var local = global_transform.affine_inverse() * p
        min_lx = min(min_lx, local.x); max_lx = max(max_lx, local.x)
        min_ly = min(min_ly, local.y); max_ly = max(max_ly, local.y)
    var width_cam = max_lx - min_lx
    var height_cam = max_ly - min_ly

    if get_viewport() == null:
        return
    var vp_size: Vector2 = get_viewport().size
    var area_size = vp_size
    var overlay = get_node_or_null(overlay_control_path)
    if overlay and overlay is Control:
        area_size = (overlay as Control).size
        if area_size.x <= 0 or area_size.y <= 0:
            area_size = vp_size

    var aspect = vp_size.x / max(1.0, vp_size.y)
    # Orthographic height visible on full viewport is `size`.
    # We want the content to fit inside the overlay area (a fraction of full viewport).
    var h_frac = area_size.y / max(1.0, vp_size.y)
    var w_frac = area_size.x / max(1.0, vp_size.x)
    var req_size_by_h = height_cam / max(0.001, h_frac)
    var req_size_by_w = (width_cam / max(0.001, w_frac)) / max(0.001, aspect)
    var target_size = max(req_size_by_h, req_size_by_w)
    size = clamp(target_size * (1.0 + margin_ratio), min_size, max_size)

func _input(event: InputEvent) -> void:
    if not controls_enabled:
        return
    if event is InputEventMouseButton:
        var mb := event as InputEventMouseButton
        _last_mouse = mb.position
        # Desired mapping:
        #  - Hold RIGHT to rotate (orbit)
        #  - Hold LEFT to move/pan (slow, bounded)
        if mb.button_index == MOUSE_BUTTON_RIGHT:
            _drag_orbit = mb.pressed
            _log("orbit %s at %s" % ["start" if mb.pressed else "end", str(mb.position)])
        elif mb.button_index == MOUSE_BUTTON_LEFT:
            # Ignore if over overlay UI area to avoid fighting the GUI.
            if _is_over_overlay(mb.position):
                _drag_pan = false
                if mb.pressed:
                    _log("pan ignored (over overlay) at %s" % str(mb.position))
            else:
                _drag_pan = mb.pressed
                _log("pan %s at %s" % ["start" if mb.pressed else "end", str(mb.position)])
        elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
            size = clamp(size / zoom_speed, min_size, max_size)
        elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
            size = clamp(size * zoom_speed, min_size, max_size)
    elif event is InputEventMouseMotion:
        var mm := event as InputEventMouseMotion
        var delta := mm.relative
        if _drag_orbit:
            yaw_deg += delta.x * orbit_speed
            pitch_deg = clamp(pitch_deg - delta.y * orbit_speed, -85.0, -10.0)
            _apply_pose()
            _maybe_log_throttle("orbit delta=%s yaw=%s pitch=%s" % [str(delta), str(yaw_deg), str(pitch_deg)])
        elif _drag_pan:
            _pan_by_pixels(delta)
            _maybe_log_throttle("pan delta=%s center=%s" % [str(delta), str(_target_center)])
    elif event is InputEventKey:
        var k := event as InputEventKey
        if k.pressed and not k.echo:
            if k.keycode == KEY_F:
                _fit_view()

func _apply_pose() -> void:
    if not is_inside_tree():
        return
    # Recompute basis from yaw/pitch while keeping distance and center.
    var basis := Basis()
    basis = basis.rotated(Vector3.UP, deg_to_rad(yaw_deg))
    basis = basis.rotated(basis.x, deg_to_rad(pitch_deg))
    global_transform.basis = basis
    var fwd := -basis.z
    global_transform.origin = _target_center - fwd * _target_dist

func _pan_by_pixels(delta: Vector2) -> void:
    if not is_inside_tree():
        return
    # Convert screen pixel delta to ground-plane world movement
    var vp = get_viewport().size
    if vp.y <= 0.0:
        return
    var aspect = vp.x / max(1.0, vp.y)
    var world_per_px_y = (2.0 * size) / vp.y
    var world_per_px_x = world_per_px_y * aspect
    var move_x = -delta.x * world_per_px_x * pan_speed
    var move_z = delta.y * world_per_px_y * pan_speed
    # Move along camera right/forward projected onto ground plane
    var b := global_transform.basis
    var right := Vector3(b.x.x, 0.0, b.x.z).normalized()
    var fwd := Vector3(b.z.x, 0.0, b.z.z).normalized() * -1.0
    var move_vec = right * move_x + fwd * move_z
    # Propose new center and clamp to a radius around the home center on the ground plane.
    var proposed_center = _target_center + move_vec
    var off = proposed_center - _home_center
    off.y = 0.0
    var d = off.length()
    if d > _pan_limit and d > 0.0:
        off = off.normalized() * _pan_limit
    var clamped_center = _home_center + off
    var applied = clamped_center - _target_center
    _target_center = clamped_center
    global_transform.origin += applied

func _is_over_overlay(p: Vector2) -> bool:
    var overlay = get_node_or_null(overlay_control_path)
    if overlay and overlay is Control:
        var r: Rect2 = (overlay as Control).get_global_rect()
        return r.has_point(p)
    return false

func _maybe_log_throttle(msg: String) -> void:
    if not debug_logging:
        return
    var t = Time.get_ticks_msec() / 1000.0
    if (t - _last_log_time) > 0.2:
        _last_log_time = t
        _log(msg)

func _log(msg: String) -> void:
    if not debug_logging:
        return
    var full = "[IsoCam] %s" % msg
    var dbg = get_tree().get_root().get_node_or_null("/root/WorkspaceDebugger")
    if dbg and dbg.has_method("log_info"):
        dbg.log_info(full)
    else:
        print(full)

func _find_grid_map() -> GridMap:
    var root = get_node_or_null(grid_root_path)
    if root == null:
        root = get_tree().get_root()
    var stack = [root]
    while stack.size() > 0:
        var n = stack.pop_back()
        if n is GridMap:
            return n
        for c in n.get_children():
            if c is Node:
                stack.append(c)
    return null
