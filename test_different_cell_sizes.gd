@tool
extends EditorScript

# Test different GridMap cell sizes to find the perfect fit
# Run this from Tools -> Execute Script

func _run():
    print("=== TESTING DIFFERENT CELL SIZES ===")
    
    var scene = EditorInterface.get_edited_scene_root()
    if not scene:
        print("No scene opened")
        return
    
    # Find the GridMap
    var gridmap = _find_gridmap(scene)
    if not gridmap:
        print("No GridMap found")
        return
        
    print("Current cell_size: ", gridmap.cell_size)
    
    # Test different sizes
    var test_sizes = [
        Vector3(0.8, 1.0, 0.8),   # Smaller gaps
        Vector3(0.9, 1.0, 0.9),   # Slightly smaller
        Vector3(1.1, 1.0, 1.1),   # Slightly larger
        Vector3(1.2, 1.0, 1.2),   # Larger overlap
    ]
    
    print("\nSuggested cell_size values to try:")
    for i in range(test_sizes.size()):
        print("  Option ", i+1, ": ", test_sizes[i])
    
    # Try the first one
    gridmap.cell_size = test_sizes[0]
    print("\nApplied Option 1: ", test_sizes[0])
    print("If terrain still has gaps, try manually setting cell_size to one of the other options")

func _find_gridmap(node: Node) -> GridMap:
    if node is GridMap:
        return node
    
    for child in node.get_children():
        var result = _find_gridmap(child)
        if result:
            return result
    
    return null