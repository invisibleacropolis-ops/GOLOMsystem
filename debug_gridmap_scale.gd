extends Node

# Debug script to check GridMap and mesh scaling issues
# Attach this to a node in your scene and run it

@export var grid_map: GridMap
@export var terrain_layer: T2GTerrainLayer

func _ready():
    if grid_map and terrain_layer:
        debug_scaling_issues()

func debug_scaling_issues():
    print("=== DEBUGGING GRIDMAP SCALING ===")
    
    # Check GridMap properties
    print("GridMap cell_size: ", grid_map.cell_size)
    
    # Check MeshLibrary items
    if grid_map.mesh_library:
        var items = grid_map.mesh_library.get_item_list()
        print("MeshLibrary has ", items.size(), " items")
        
        for item_id in items:
            var item_name = grid_map.mesh_library.get_item_name(item_id)
            var mesh = grid_map.mesh_library.get_item_mesh(item_id)
            if mesh:
                var aabb = mesh.get_aabb()
                print("  ", item_name, " mesh size: ", aabb.size)
    
    # Check T2GTerrainLayer settings
    print("T2GTerrainLayer tile_size: ", terrain_layer.tile_size)
    print("T2GTerrainLayer chunk_size: ", terrain_layer.chunk_size)
    
    # Check actual placed cells
    var used_cells = grid_map.get_used_cells()
    print("GridMap has ", used_cells.size(), " used cells")
    
    if used_cells.size() > 0:
        var first_cell = used_cells[0]
        var item_id = grid_map.get_cell_item(first_cell)
        if item_id != -1:
            var item_name = grid_map.mesh_library.get_item_name(item_id)
            print("First cell ", first_cell, " has item: ", item_name)