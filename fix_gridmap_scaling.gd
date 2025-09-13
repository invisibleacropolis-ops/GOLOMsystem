@tool
extends EditorScript

# Script to fix GridMap scaling issues
# Run this from the editor: Tools -> Execute Script

func _run():
    print("=== FIXING GRIDMAP SCALING ISSUES ===")
    
    var scene = EditorInterface.get_edited_scene_root()
    if not scene:
        print("No scene opened in editor")
        return
    
    # Find all GridMap nodes in the scene
    var gridmaps = []
    _find_gridmaps(scene, gridmaps)
    
    if gridmaps.is_empty():
        print("No GridMap nodes found in scene")
        return
    
    for gridmap in gridmaps:
        print("Found GridMap: ", gridmap.name)
        print("  Current cell_size: ", gridmap.cell_size)
        
        # Fix the cell_size
        gridmap.cell_size = Vector3(1.0, 1.0, 1.0)
        print("  Updated cell_size to: ", gridmap.cell_size)
        
        # Check mesh library
        if gridmap.mesh_library:
            var items = gridmap.mesh_library.get_item_list()
            print("  MeshLibrary has ", items.size(), " items")
            
            if items.size() > 0:
                var first_item = items[0]
                var mesh = gridmap.mesh_library.get_item_mesh(first_item)
                if mesh:
                    var aabb = mesh.get_aabb()
                    print("  First mesh AABB size: ", aabb.size)
                    
                    # Suggest better cell_size based on mesh size
                    var suggested_size = Vector3(
                        max(0.8, aabb.size.x),
                        max(0.8, aabb.size.y), 
                        max(0.8, aabb.size.z)
                    )
                    print("  Suggested cell_size: ", suggested_size)
                    
                    # Apply suggested size
                    gridmap.cell_size = suggested_size
                    print("  Applied suggested cell_size: ", gridmap.cell_size)
    
    print("=== GRIDMAP SCALING FIX COMPLETE ===")
    print("You may need to rebuild your tilemap to see changes")

func _find_gridmaps(node: Node, result: Array):
    if node is GridMap:
        result.append(node)
    
    for child in node.get_children():
        _find_gridmaps(child, result)