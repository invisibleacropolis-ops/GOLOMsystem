extends Node3D
class_name Actor3DProxy

var actor
var _gridmap: GridMap
var _mesh: MeshInstance3D
var _last_grid_pos: Vector2i = Vector2i(-9999, -9999)

func setup(a, gridmap: GridMap, color: Color = Color(0.8, 0.9, 1.0)) -> void:
    actor = a
    _gridmap = gridmap
    _build_mesh(color)
    _sync_transform(true)

func _build_mesh(color: Color) -> void:
    if _mesh:
        _mesh.queue_free()
    _mesh = MeshInstance3D.new()
    _mesh.name = "ActorMesh"
    var quad := QuadMesh.new()
    quad.size = Vector2(0.8, 0.8)
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
    _mesh.mesh = quad
    _mesh.material_override = mat
    # lift the quad slightly above the ground and rotate upright
    _mesh.rotation_degrees.x = -90
    _mesh.position.y = 0.5
    add_child(_mesh)

func update_from_actor() -> void:
    _sync_transform(false)

func _sync_transform(force: bool) -> void:
    if actor == null or _gridmap == null:
        return
    if not is_inside_tree():
        return
    var pos: Vector2i = actor.get("grid_pos") if actor.has_method("get") else Vector2i.ZERO
    if not force and pos == _last_grid_pos:
        return
    _last_grid_pos = pos
    var cell := Vector3i(pos.x, 0, pos.y)
    var world := _gridmap.map_to_local(cell)
    global_transform.origin = world
    # Yaw from facing vector (supports 8 directions)
    var f: Vector2i = actor.get("facing") if actor.has_method("get") else Vector2i.RIGHT
    var yaw_deg = rad_to_deg(atan2(float(f.x), -float(f.y)))
    rotation_degrees.y = yaw_deg
