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
	
	# Get actor faction to determine shape
	var faction = actor.get("faction") if actor.has_method("get") else ""
	var mesh_primitive
	
	match faction:
		"player":
			# Player = Capsule (humanoid)
			var capsule = CapsuleMesh.new()
			capsule.radius = 0.3
			capsule.height = 1.5
			mesh_primitive = capsule
			_mesh.position.y = 0.75  # Half height above ground
			
		"enemy": 
			# Enemy = Sphere (more alien/monster-like)
			var sphere = SphereMesh.new()
			sphere.radius = 0.4
			mesh_primitive = sphere
			_mesh.position.y = 0.4  # Radius above ground
			
		"npc":
			# NPC = Cylinder (neutral, pillar-like)
			var cylinder = CylinderMesh.new()
			cylinder.top_radius = 0.25
			cylinder.bottom_radius = 0.25
			cylinder.height = 1.2
			mesh_primitive = cylinder
			_mesh.position.y = 0.6  # Half height above ground
			
		_:
			# Default = Box (generic)
			var box = BoxMesh.new()
			box.size = Vector3(0.6, 1.0, 0.6)
			mesh_primitive = box
			_mesh.position.y = 0.5  # Half height above ground
	
	# Create material
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.roughness = 0.3
	mat.metallic = 0.1
	
	# Add slight rim lighting for better visibility
	mat.rim_enabled = true
	mat.rim = 0.2
	mat.rim_tint = 0.3
	
	_mesh.mesh = mesh_primitive
	_mesh.material_override = mat
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
