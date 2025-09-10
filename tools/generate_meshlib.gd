@tool
extends EditorScript
# Godot 4.x — Terrain MeshLibrary & TileSet bootstrapper
# -----------------------------------------------------
# Purpose
# - Generate a MeshLibrary with 16 bitmask items per terrain (name0..name15).
# - (Optional) Generate a minimal TileSet with one tile per terrain and the
#   Custom Data fields expected by Tile-to-GridMap (Name, Height, Exclude).
# - Materials are pixel-art friendly (Unshaded + Nearest) and can use a flat
#   color or a tiny 16×16 texture.
#
# Usage
# 1) Put this file anywhere in your project (e.g., res://tools/generate_meshlib.gd).
# 2) With the editor open, run: Project > Tools > "Run" (or press the triangle
#    in the script header). This will execute _run().
# 3) The script writes resources to the configured output paths below.
#
# Safe to re-run; it overwrites the output assets.
# -----------------------------------------------------

# ---- CONFIG ---------------------------------------------------------------
# World scaling / visual intent
var TILE_WORLD_SIZE: float = 4.0         # 1 tile (X/Z) = 4 world units (your spec)
var HEIGHT_UNIT_SIZE: float = 2.0        # 1 grid-height step (Y) = 2 world units
var PIXELS_PER_TILE: int = 16            # tiny texture size for pixel look

# Mesh thickness in *grid-height units*.
#   1.0 => one height step (2ft). 2.0 => a full "cube" (4ft) visually.
var MESH_THICKNESS_UNITS: float = 1.0    # default slab = 1 step tall

# Terrain set to generate. Each entry: { name, color, height }
# - name   -> base name used by the plugin (creates name0..name15 in MeshLibrary)
# - color  -> placeholder color for the material
# - height -> written into TileSet Custom Data (int). Keep 0 if flat.
var TERRAINS := [
    {"name": "grass",  "color": Color(0.30, 0.80, 0.30), "height": 0},
    {"name": "dirt",   "color": Color(0.55, 0.40, 0.20), "height": 0},
    {"name": "water",  "color": Color(0.20, 0.55, 0.95), "height": -1},
    {"name": "roof_wood",  "color": Color(0.60, 0.40, 0.25), "height": 1},
    {"name": "roof_stone", "color": Color(0.55, 0.55, 0.60), "height": 1},
    {"name": "wall_brick", "color": Color(0.75, 0.25, 0.25), "height": 2},
]

# Output paths
var OUTPUT_MESHLIB_PATH := "res://meshes/terrain_basic.meshlib"
var OUTPUT_TILESET_PATH := "res://tilesets/terrain_minimal.tres"

# Behavior flags
var CREATE_TILESET: bool = true          # also create a minimal TileSet
var USE_TEXTURED_MATERIAL: bool = true   # false => flat albedo color only
var MATERIAL_UNSHADED: bool = true       # pixel flat look

# Column mesh generation
var GENERATE_COLUMNS: bool = true
var OUTPUT_COLUMNS_MESHLIB_PATH := "res://meshes/terrain_columns.meshlib"
# --------------------------------------------------------------------------

func _run():
    _ensure_dirs()
    var meshlib := _build_mesh_library()
    var err := ResourceSaver.save(OUTPUT_MESHLIB_PATH, meshlib)
    if err != OK:
        push_error("Failed to save MeshLibrary: %s" % err)
    else:
        print("Saved MeshLibrary to ", OUTPUT_MESHLIB_PATH)

    if GENERATE_COLUMNS:
        var col_ml := _build_columns_mesh_library()
        err = ResourceSaver.save(OUTPUT_COLUMNS_MESHLIB_PATH, col_ml)
        if err != OK:
            push_error("Failed to save Columns MeshLibrary: %s" % err)
        else:
            print("Saved Columns MeshLibrary to ", OUTPUT_COLUMNS_MESHLIB_PATH)

    if CREATE_TILESET:
        var tileset := _build_tileset()
        err = ResourceSaver.save(OUTPUT_TILESET_PATH, tileset)
        if err != OK:
            push_error("Failed to save TileSet: %s" % err)
        else:
            print("Saved TileSet to ", OUTPUT_TILESET_PATH)

    print("Done. Assign the MeshLibrary to a GridMap and (optionally) the TileSet to your T2GTerrainLayer.\n",
        "In the layer, set Custom Data fields to match the terrain names above (already set if you used the generated TileSet).\n",
        "Press 'Build Gridmap' in the plugin.")

# --- Helpers ---------------------------------------------------------------

func _ensure_dirs():
    var mesh_dir := OUTPUT_MESHLIB_PATH.get_base_dir()
    var tile_dir := OUTPUT_TILESET_PATH.get_base_dir()
    DirAccess.make_dir_recursive_absolute(mesh_dir)
    DirAccess.make_dir_recursive_absolute(tile_dir)
    DirAccess.make_dir_recursive_absolute(OUTPUT_COLUMNS_MESHLIB_PATH.get_base_dir())

func _build_mesh_library() -> MeshLibrary:
    var ml := MeshLibrary.new()

    # Base slab mesh reused for everything (1xTHICKNESSx1 in grid units)
    var base_mesh := _make_slab_mesh(1.0, MESH_THICKNESS_UNITS)

    for t in TERRAINS:
        var base_name: String = t.name
        var mat := _make_pixel_material(t.color)
        var mesh_copy := base_mesh.duplicate() as ArrayMesh
        _apply_material_to_mesh(mesh_copy, mat)

        for i in 16:
            var id := ml.get_last_unused_item_id()
            ml.create_item(id)
            ml.set_item_name(id, "%s%d" % [base_name, i])
            ml.set_item_mesh(id, mesh_copy)
            ml.set_item_mesh_transform(id, Transform3D())

    return ml

func _make_slab_mesh(tile_xy_units: float, thickness_units: float) -> ArrayMesh:
    # Build a slab that spans exactly 1x1 in GridMap cell units (X/Z) and
    # 'thickness_units' in Y. World-space meters are controlled by GridMap scale.
    var box := BoxMesh.new()
    box.size = Vector3(tile_xy_units, thickness_units, tile_xy_units)

    var arr := box.surface_get_arrays(0)
    var am := ArrayMesh.new()
    am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
    return am

func _apply_material_to_mesh(mesh: ArrayMesh, mat: Material) -> void:
    for s in mesh.get_surface_count():
        mesh.surface_set_material(s, mat)

func _make_pixel_material(color: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if MATERIAL_UNSHADED else BaseMaterial3D.SHADING_MODE_PER_PIXEL
    m.albedo_color = color
    m.vertex_color_use_as_albedo = false
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
    if USE_TEXTURED_MATERIAL:
        m.albedo_texture = _make_tiny_texture(color)
        m.uv1_triplanar = false
    return m

func _make_tiny_texture(color: Color) -> Texture2D:
    var px := max(4, PIXELS_PER_TILE)
    var img := Image.create(px, px, false, Image.FORMAT_RGBA8)
    img.fill(color)
    var tex := ImageTexture.create_from_image(img)
    return tex

# --- TileSet generation (minimal) -----------------------------------------
func _build_tileset() -> TileSet:
    var ts := TileSet.new()
    # Use a single Atlas source to keep things simple; a single dummy tile region.
    var src := TileSetAtlasSource.new()
    var TILE := Vector2i(PIXELS_PER_TILE, PIXELS_PER_TILE)
    src.texture = _make_tiny_texture(Color.BLACK)  # a placeholder sheet
    src.texture_region_size = TILE

    # allocate N slots horizontally for N terrains
    for i in TERRAINS.size():
        var pos := Vector2i(i * TILE.x, 0)
        src.create_tile(pos)
    ts.add_source(src)

    # Custom Data layers: Name (String), Height (int), Exclude (String)
    var CDL_NAME := 0
    var CDL_HEIGHT := 1
    var CDL_EXCLUDE := 2
    ts.add_custom_data_layer()    # 0 -> Name
    ts.set_custom_data_layer_name(0, "Name")
    ts.set_custom_data_layer_type(0, Variant.Type.TYPE_STRING)

    ts.add_custom_data_layer()    # 1 -> Height
    ts.set_custom_data_layer_name(1, "Height")
    ts.set_custom_data_layer_type(1, Variant.Type.TYPE_INT)

    ts.add_custom_data_layer()    # 2 -> Exclude
    ts.set_custom_data_layer_name(2, "Exclude")
    ts.set_custom_data_layer_type(2, Variant.Type.TYPE_STRING)

    for i in TERRAINS.size():
        var base := TERRAINS[i]
        var pos := Vector2i(i * TILE.x, 0)
        ts.set_source_tile_custom_data(src.get_rid(), pos, CDL_NAME, base.name)
        ts.set_source_tile_custom_data(src.get_rid(), pos, CDL_HEIGHT, int(base.height))
        ts.set_source_tile_custom_data(src.get_rid(), pos, CDL_EXCLUDE, "")

    return ts

# ================================================================
# EXTRA: Column MeshLibrary for Stacked Heights (bottom/mid/top)
# ================================================================
# Call from _run() manually or run this script again after toggling
# GENERATE_COLUMNS to true.

func _build_columns_mesh_library() -> MeshLibrary:
    var ml := MeshLibrary.new()

    # All in grid units (1x1x1 footprint per step)
    var bottom_mesh := _make_slab_mesh(1.0, 1.0) # visually same as step
    var mid_mesh := _make_slab_mesh(1.0, 1.0)
    var top_mesh := _make_slab_mesh(1.0, 1.0)

    for t in TERRAINS:
        var name: String = t.name
        var mat := _make_pixel_material(t.color)
        var b := bottom_mesh.duplicate()
        var m := mid_mesh.duplicate()
        var tp := top_mesh.duplicate()
        _apply_material_to_mesh(b, mat)
        _apply_material_to_mesh(m, mat)
        _apply_material_to_mesh(tp, mat)

        var id := ml.get_last_unused_item_id()
        ml.create_item(id);                ml.set_item_name(id, "%s_bottom" % name); ml.set_item_mesh(id, b)
        id = ml.get_last_unused_item_id()
        ml.create_item(id);                ml.set_item_name(id, "%s_mid" % name);    ml.set_item_mesh(id, m)
        id = ml.get_last_unused_item_id()
        ml.create_item(id);                ml.set_item_name(id, "%s_top" % name);    ml.set_item_mesh(id, tp)

    return ml

# ================================================================
# EXTRA TOOL: Height Stacker → builds vertical columns in a GridMap
# ================================================================
# How to use:
# 1) Add a GridMap to your scene called e.g. "GridMap-columns" and assign
#    res://meshes/terrain_columns.meshlib as its MeshLibrary.
# 2) Add a TileMap/T2GTerrainLayer with a TileSet that carries Custom Data
#    `Name` (terrain id string) and `Height` (int number of 2ft steps).
# 3) Run this script's tool below or attach as a separate @tool node.

@tool
class HeightStacker:
    extends Node
    @export var tilemap_path: NodePath
    @export var columns_gridmap_path: NodePath
    @export var read_height_key: String = "Height"  # which custom data key to read
    @export var read_name_key: String = "Name"

    func build_columns():
        var tm := get_node_or_null(tilemap_path)
        var gm := get_node_or_null(columns_gridmap_path)
        if tm == null or gm == null:
            push_error("HeightStacker: Assign tilemap_path and columns_gridmap_path")
            return
        gm.clear()

        var used := tm.get_used_cells()
        for cell in used:
            var data := _read_tile_custom_data(tm, cell)
            if data == null:
                continue
            var terrain_name: String = data.get(read_name_key, "")
            var h: int = int(data.get(read_height_key, 0))
            if terrain_name == "" or h <= 0:
                continue
            # bottom / mid / top placement in GridMap Y = 0..h-1
            var y := 0
            if h == 1:
                _place(gm, cell, y, "%s_top" % terrain_name)
            else:
                _place(gm, cell, y, "%s_bottom" % terrain_name)
                for y in range(1, h-1):
                    _place(gm, cell, y, "%s_mid" % terrain_name)
                _place(gm, cell, h-1, "%s_top" % terrain_name)

    func _read_tile_custom_data(tm: TileMap, cell: Vector2i) -> Dictionary:
        var data := {}
        var rid := tm.get_cell_source_id(0, cell)
        if rid == -1:
            return null
        var src := tm.tile_set.get_source(rid)
        if src is TileSetAtlasSource:
            var atlas := tm.get_cell_atlas_coords(0, cell)
            # pull all custom layers present
            for layer_index in tm.tile_set.get_custom_data_layers_count():
                var key := tm.tile_set.get_custom_data_layer_name(layer_index)
                var val := tm.tile_set.get_source_tile_custom_data(src.get_rid(), atlas, layer_index)
                data[key] = val
        return data

    func _place(gm: GridMap, cell_xy: Vector2i, y: int, item_name: String) -> void:
        var id := _meshlib_find_item_id_by_name(gm.mesh_library, item_name)
        if id == -1:
            push_warning("GridMap missing item: %s" % item_name)
            return
        var pos := Vector3i(cell_xy.x, y, cell_xy.y)
        gm.set_cell_item(pos, id, 0)

    func _meshlib_find_item_id_by_name(ml: MeshLibrary, name: String) -> int:
        for id in ml.get_item_list():
            if ml.get_item_name(id) == name:
                return id
        return -1

# --- Addendum: Enterable / Roof tiles support ---------------------------------
# Some tiles are walkable on the roof level while also being hollow/enterable
# beneath. We model that with extra TileSet Custom Data keys and a stacking
# helper that places roofs into a dedicated GridMap so they can be toggled
# (hidden/shown) when actors go inside.
#
# Add these Custom Data keys to your TileSet (if you regenerate with this file
# later, wire them into _build_tileset):
#   - Enterable (bool)   : true if the tile forms a roof with interior space
#   - Clearance (int)    : how many height *steps* (2ft each) are empty below
#                           the roof (min 1)
#   - WalkTop (bool)     : allow walking on the roof surface itself
#
# Create a second GridMap called e.g. "GridMap-roofs" and assign the same
# terrain MeshLibrary (or a variant for roofs). Then use the helper below.

@tool
class_name HeightStackerEnterable
extends Node

@export var tilemap_path: NodePath
@export var columns_gridmap_path: NodePath
@export var roofs_gridmap_path: NodePath
@export var read_height_key := "Height"
@export var read_name_key := "Name"
@export var reveal_on_enter := true  # hide/show roofs when player enters

func build_all() -> void:
    var tm := get_node_or_null(tilemap_path) as TileMap
    var cols := get_node_or_null(columns_gridmap_path) as GridMap
    var roofs := get_node_or_null(roofs_gridmap_path) as GridMap
    if not tm or not cols or not roofs:
        push_error("Assign tilemap_path, columns_gridmap_path, roofs_gridmap_path")
        return
    cols.clear(); roofs.clear()

    for cell in tm.get_used_cells():
        var info := _tile_info(tm, cell)
        if info == null: continue
        var name: String = info.get("Name", "")
        var h: int = int(info.get(read_height_key, 0))
        var enterable: bool = bool(info.get("Enterable", false))
        var clearance: int = max(1, int(info.get("Clearance", 1)))
        var walk_top: bool = bool(info.get("WalkTop", true))
        if name == "" or h <= 0: continue

        if enterable:
            # Fill columns up to h-1 as walls (basic version). Customize to build
            # perimeters only if you prefer.
            for y in h-1:
                _place(cols, cell, y, "%s_mid" % name)
            if walk_top:
                _place(roofs, cell, h-1, "%s_top" % name)
            if reveal_on_enter:
                _spawn_enter_volume(tm, cell, clearance)
        else:
            if h == 1:
                _place(cols, cell, 0, "%s_top" % name)
            else:
                _place(cols, cell, 0, "%s_bottom" % name)
                for y in range(1, h-1):
                    _place(cols, cell, y, "%s_mid" % name)
                _place(cols, cell, h-1, "%s_top" % name)

func _tile_info(tm: TileMap, cell: Vector2i) -> Dictionary:
    var src_id := tm.get_cell_source_id(0, cell)
    if src_id == -1: return null
    var src := tm.tile_set.get_source(src_id)
    if not (src is TileSetAtlasSource): return null
    var atlas := tm.get_cell_atlas_coords(0, cell)
    var d := {}
    for i in tm.tile_set.get_custom_data_layers_count():
        var key := tm.tile_set.get_custom_data_layer_name(i)
        d[key] = tm.tile_set.get_source_tile_custom_data(src.get_rid(), atlas, i)
    return d

func _place(gm: GridMap, xy: Vector2i, y: int, item_name: String) -> void:
    var id := _find_item(gm.mesh_library, item_name)
    if id == -1: return
    gm.set_cell_item(Vector3i(xy.x, y, xy.y), id)

func _find_item(ml: MeshLibrary, name: String) -> int:
    for id in ml.get_item_list():
        if ml.get_item_name(id) == name:
            return id
    return -1

func _spawn_enter_volume(parent: Node, cell: Vector2i, clearance: int) -> void:
    var area := Area3D.new()
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = Vector3(1, float(clearance), 1)
    cs.shape = sh
    area.add_child(cs)
    area.transform.origin = Vector3(cell.x + 0.5, float(clearance) * 0.5, cell.y + 0.5)
    area.body_entered.connect(_on_enter)
    area.body_exited.connect(_on_exit)
    parent.add_sibling(area)

func _on_enter(_b: Node) -> void:
    var roofs := get_node_or_null(roofs_gridmap_path) as GridMap
    if roofs: roofs.visible = false

func _on_exit(_b: Node) -> void:
    var roofs := get_node_or_null(roofs_gridmap_path) as GridMap
    if roofs: roofs.visible = true
