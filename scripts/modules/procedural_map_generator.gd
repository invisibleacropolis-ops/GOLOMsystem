extends Node
class_name ProceduralMapGenerator

const LogicGridMap = preload("res://scripts/grid/grid_map.gd")
const MapProfiles = preload("res://scripts/modules/map_profiles.gd")

## Generates a LogicGridMap using layered noise to create height, terrain
## and connected road features. The first tag controls rendering while
## subsequent tags describe underlying terrain (e.g. `"grass","dirt"`).
##
## Params may include:
## - `width` (int)
## - `height` (int)
## - `seed` (String) used for deterministic output
## - `terrain` (String) selects a preset profile, use `"random"` for variety
func generate(params: Dictionary) -> LogicGridMap:
    var width: int = int(params.get("width", 32))
    var height: int = int(params.get("height", 32))
    var seed_str: String = str(params.get("seed", ""))
    var terrain: String = str(params.get("terrain", "random"))

    var profile: Dictionary = MapProfiles.get_profile(terrain)
    if profile.is_empty():
        profile = MapProfiles.pick_profile(seed_str)

    var map := LogicGridMap.new()
    map.width = width
    map.height = height

    var elev := FastNoiseLite.new()
    elev.seed = seed_str.hash()
    elev.frequency = profile.get("elev_freq", 0.05)
    var grass := FastNoiseLite.new()
    grass.seed = seed_str.hash() + 1
    grass.frequency = profile.get("grass_freq", 0.2)
    var trees := FastNoiseLite.new()
    trees.seed = seed_str.hash() + 2
    trees.frequency = profile.get("tree_freq", 0.3)
    var water_t: float = float(profile.get("water_threshold", -0.3))
    var dirt_t: float = float(profile.get("dirt_threshold", 0.0))
    var hill_t: float = float(profile.get("hill_threshold", 0.4))
    var tree_t: float = float(profile.get("tree_threshold", 0.6))

    for x in width:
        for y in height:
            var pos := Vector2i(x, y)
            var n := elev.get_noise_2d(x, y)
            var tags: Array[String] = []
            var h := 1
            if n < water_t:
                h = 0
                tags.append("water")
            elif n < dirt_t:
                h = 1
                tags.append("dirt")
            elif n < hill_t:
                h = 2
                tags.append("hill")
            else:
                h = 3
                tags.append("mountain")
            if tags[0] == "dirt" and grass.get_noise_2d(x, y) > 0.0:
                tags.insert(0, "grass")
            if tags[0] == "grass" and trees.get_noise_2d(x, y) > tree_t:
                tags.insert(0, "forest")
            map.tile_tags[pos] = tags
            map.height_levels[pos] = h

    _carve_roads(map, seed_str)
    _assign_cover(map)

    return map

## Carves a simple cross-shaped road network so paths remain connected.
## The cross position is randomized by seed to add variation.
func _carve_roads(map: LogicGridMap, seed_str: String) -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = hash(seed_str)
    var mid_y := rng.randi_range(0, map.height - 1)
    for x in map.width:
        var pos := Vector2i(x, mid_y)
        map.tile_tags[pos] = ["road"]
        map.height_levels[pos] = 1
    var mid_x := rng.randi_range(0, map.width - 1)
    for y in map.height:
        var pos := Vector2i(mid_x, y)
        map.tile_tags[pos] = ["road"]
        map.height_levels[pos] = 1

## Assigns simple cover and LOS blockers based on terrain tags.
## Currently mountains block line of sight and grant adjacent half cover.
## This allows battles to reason about defensive positions without
## additional post-processing by the caller.
func _assign_cover(map: LogicGridMap) -> void:
    for pos in map.tile_tags.keys():
        var tags: Array = map.tile_tags[pos]
        if tags.size() == 0:
            continue
        if tags[0] == "mountain":
            map.set_los_blocker(pos, true)
            for d: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
                var adj: Vector2i = pos + d
                if map.is_in_bounds(adj) and map.get_cover(adj) == "none":
                    map.set_cover(adj, "half")

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

    # Verify cover assignment for a manual mountain tile.
    total += 1
    var mtile := Vector2i(0, 0)
    map.tile_tags[mtile] = ["mountain"]
    map.cover_types.clear()
    gen._assign_cover(map)
    if map.get_cover(Vector2i(1, 0)) != "half":
        failed += 1

    # Release instances to prevent leaks in automated test runs
    gen.free()
    map = null

    return {"failed": failed, "total": total}
