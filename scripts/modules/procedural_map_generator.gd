extends Node
class_name ProceduralMapGenerator

const LogicGridMap = preload("res://scripts/grid/grid_map.gd")

## Generates a LogicGridMap using layered noise to create height, terrain
## and connected road features. The first tag controls rendering while
## subsequent tags describe underlying terrain (e.g. `"grass","dirt"`).
##
## Params may include:
## - `width` (int)
## - `height` (int)
## - `seed` (String) used for deterministic output
## - `terrain` (String) selects a preset profile
func generate(params: Dictionary) -> LogicGridMap:
    var width: int = int(params.get("width", 16))
    var height: int = int(params.get("height", 16))
    var seed_str: String = str(params.get("seed", ""))
    var terrain: String = str(params.get("terrain", "plains"))

    var map := LogicGridMap.new()
    map.width = width
    map.height = height

    var elev := FastNoiseLite.new()
    elev.seed = seed_str.hash()
    elev.frequency = 0.05
    var grass := FastNoiseLite.new()
    grass.seed = seed_str.hash() + 1
    grass.frequency = 0.2

    for x in width:
        for y in height:
            var pos := Vector2i(x, y)
            var n := elev.get_noise_2d(x, y)
            var tags: Array[String] = []
            var h := 1
            if n < -0.3:
                h = 0
                tags.append("water")
            elif n < 0.0:
                h = 1
                tags.append("dirt")
            elif n < 0.4:
                h = 2
                tags.append("hill")
            else:
                h = 3
                tags.append("mountain")
            if tags[0] == "dirt" and grass.get_noise_2d(x, y) > 0.0:
                tags.insert(0, "grass")
            map.tile_tags[pos] = tags
            map.height_levels[pos] = h

    _carve_roads(map)
    return map

## Carves a simple cross-shaped road network so paths remain connected.
func _carve_roads(map: LogicGridMap) -> void:
    var mid_y := map.height / 2
    for x in map.width:
        var pos := Vector2i(x, mid_y)
        map.tile_tags[pos] = ["road"]
        map.height_levels[pos] = 1
    var mid_x := map.width / 2
    for y in map.height:
        var pos := Vector2i(mid_x, y)
        map.tile_tags[pos] = ["road"]
        map.height_levels[pos] = 1

## Lightweight self-test for CI usage.
func run_tests() -> Dictionary:
    var failed := 0
    var total := 0
    var gen = get_script().new()
    var params = {"width": 4, "height": 4, "seed": "demo", "terrain": "plains"}
    var map = gen.generate(params)

    total += 1
    if map.width != 4 or map.height != 4:
        failed += 1

    total += 1
    if map.tile_tags.size() != 16:
        failed += 1

    total += 1
    if map.height_levels.size() != 16:
        failed += 1

    total += 1
    var road_count := 0
    for tags in map.tile_tags.values():
        if tags.size() > 0 and tags[0] == "road":
            road_count += 1
    if road_count == 0:
        failed += 1

    # Release instances to prevent leaks in automated test runs
    gen.free()
    map = null

    return {"failed": failed, "total": total}
