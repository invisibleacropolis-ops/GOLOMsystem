LogicGridMap (GDScript) — README
A pure-logic tactical grid model for Godot 4.x.
 This Resource tracks actor placement, movement costs, line of sight (LOS), zones of control (ZOC), flanking, and AOE queries. It’s intentionally render-free so you can plug it into any presentation layer (2D/3D, tilemap/meshes, etc.).
TL;DR: Treat this as your “game rules database.” Feed it map metadata + actors, ask it questions (“can I see/shoot/move there?”), and then draw whatever you like in your scene tree.

Contents
●       Design Goals

●       Coordinate System & Terminology

●       Data Model

●       Actor Contract

●       Core Features

●       API Overview

●       Usage Examples

●       Pathfinding Details

●       Line of Sight Details

●       ZOC, Flanking & AOE

●       Performance Notes

●       Serialization & Save/Load

●       Extending & Modding

●       Troubleshooting Guide

●       Testing Tips

●       Roadmap / Ideas


Design Goals
●       Deterministic, presentation-agnostic rules.

●       Supports multi-tile actors (e.g., 2×2 mechs).

●       Cheap queries for common tactics (LOS/ZOC/cover).

●       Single source of truth for tile metadata (height, cost, cover, tags).

●       Simple to serialize (it’s a Resource).


Coordinate System & Terminology
●       Grid coordinates are Vector2i (x, y) in cell units.

●       Top-left origin; x → right, y → down (Godot default).

●       Distances:

○       Manhattan for “taxicab” distance (|Δx| + |Δy|).

○       Chebyshev for square radius (max(|Δx|, |Δy|)), also used as A* heuristic.

●       Footprint: the set of tiles an actor occupies (size Vector2i(w, h)), with the origin at the top-left tile.


Data Model
Map bounds
●       width, height (in cells). is_in_bounds(pos) guards everything.

Occupancy & positions
●       occupied : Dictionary[Vector2i, Object]
 Maps each occupied tile → actor Object. Multi-tile actors will appear multiple times with the same Object value.

●       actor_positions : Dictionary[Object, Vector2i]
 Reverse lookup: actor → origin tile.

⚠️ Keys are Object references. Prefer stable game objects (Nodes, ScriptedResources) that persist while on the grid.
Terrain & metadata
●       movement_costs : Dictionary[Vector2i, float] — default 1.0; use INF for impassable.

●       height_levels : Dictionary[Vector2i, int] — default 0.

●       covers : Dictionary[Vector2i, Dictionary] — `{type, direction, height}`.

●       los_blockers : Dictionary[Vector2i, bool] — hard LOS blockers.

●       tile_tags : Dictionary[Vector2i, Array[String]] — arbitrary tags (e.g. "grass", "smoke").

Movement constants
●       MAX_CLIMB_HEIGHT := 1

●       CLIMB_COST := 2.0 per level climbed

●       TURN_COST := 0.7 when facing changes during pathfinding


Actor Contract
Actors are plain Objects expected to expose:
●       grid_pos : Vector2i (origin tile; updated by move_actor)

●       size : Vector2i (default Vector2i(1,1))

●       facing : Vector2i (e.g., Vector2i.RIGHT, default RIGHT)

●       Optional: a set(property, value) method (so move_actor can set grid_pos).

The grid does not require actors to be Nodes; any object with those properties works.

Core Features
●       Safe placement & movement for single or multi-tile actors.

●       Heuristic A* pathfinding with:

○       diagonal steps (cost multiplier 1.4),

○       per-tile movement cost,

○       height climb limits and cost,

○       turn cost based on heading changes,

○       actor footprint collision checks.

●       LOS via Bresenham with diagonal-corner checks and cover/LOS blockers.

●       Range queries (tiles/actors within Chebyshev range, optional LOS).

●       Tactical helpers: ZOC (by arcs), flanking, attack arcs (front/left/right/rear).

●       AOE helpers: burst, cone, line, wall.


API Overview
Bounds & occupancy
●       is_in_bounds(pos: Vector2i) -> bool

●       is_occupied(pos: Vector2i) -> bool

●       move_actor(actor: Object, to: Vector2i) -> bool

●       remove_actor(actor: Object) -> void

●       get_actor_at(pos: Vector2i) -> Object | null

●       get_all_actors() -> Array[Object]

●       get_occupied_tiles(actor: Object) -> Array[Vector2i]

Distances
●       get_distance(a, b) -> int (Manhattan)

●       get_chebyshev_distance(a, b) -> int

Line of sight
●       set_los_blocker(pos, blocks := true)

●       is_los_blocker(pos) -> bool

●       has_line_of_sight(a, b) -> bool

Range
●       get_actors_in_radius(center, radius, require_los := false) -> Array[Object]

●       get_positions_in_range(center, range_val, require_los := false) -> Array[Vector2i]

Pathfinding
●       find_path_for_actor(actor, start, goal) -> Array[Vector2i]

●       find_path(start, start_facing, goal, actor_size := Vector2i(1,1)) -> Array[Vector2i]

AOE
●       get_aoe_tiles(shape: "burst"|"cone"|"line"|"wall", origin, direction, range) -> Array[Vector2i]

Tactics
●       get_zone_of_control(actor, radius := 1, arc := "all") -> Array[Vector2i]
 Arcs: "all"|"front"|"rear"|"left"|"right"|"sides".

●       get_tiles_under_zoc(radius := 1, arc := "all") -> Array[Vector2i]

●       actor_in_zoc(defender, threat_actor, radius := 1, arc := "all") -> bool

●       get_threatened_tiles_by(actor, radius := 1, arc := "all") -> Array[Vector2i]

●       get_attack_arc(defender, attacker) -> String ("front"|"rear"|"left"|"right"|"none")

●       is_flanked(actor) -> bool

Terrain, tags & cover
●       set_movement_cost(pos, cost) / get_movement_cost(pos) -> float

●       set_height(pos, level) / get_height(pos) -> int

●       add_tile_tag(pos, tag) / remove_tile_tag(pos, tag) / has_tile_tag(pos, tag) -> bool

●       set_cover(pos, type, direction, height := 1) / get_cover(pos) -> Dictionary


Usage Examples
1) Creating & seeding a grid
var grid := LogicGridMap.new()
grid.width = 32
grid.height = 24

# Terrain:
for x in range(32):
    grid.set_height(Vector2i(x, 10), 1) # a ridge line
    grid.set_movement_cost(Vector2i(x, 10), 2.0)
grid.set_cover(Vector2i(5, 5), "full", "north")
grid.set_los_blocker(Vector2i(6, 5), true)
grid.add_tile_tag(Vector2i(4, 4), "forest")

2) Registering actors & moving them
# Example actor (Node or any Object with the required properties)
var soldier := {
    "grid_pos": Vector2i(2, 2),
    "size": Vector2i(1, 1),
    "facing": Vector2i.RIGHT
}

# Place
var placed := grid.move_actor(soldier, Vector2i(2, 2))
assert(placed)

# Pathfind and then move step-by-step
var goal := Vector2i(12, 7)
var path := grid.find_path_for_actor(soldier, soldier["grid_pos"], goal)
for step in path.slice(1, path.size()): # skip current tile
    grid.move_actor(soldier, step)

3) LOS and tactical checks
var enemy := {"grid_pos": Vector2i(10, 7), "size": Vector2i(1,1), "facing": Vector2i.LEFT}
grid.move_actor(enemy, enemy["grid_pos"])

var can_see := grid.has_line_of_sight(soldier["grid_pos"], enemy["grid_pos"])
var in_enemy_zoc := grid.actor_in_zoc(soldier, enemy)
var arc := grid.get_attack_arc(enemy, soldier)
var flanked := grid.is_flanked(enemy)

4) AOE selection
var cone_tiles := grid.get_aoe_tiles("cone", origin=enemy["grid_pos"], direction=Vector2i.LEFT, range=5)


Pathfinding Details
●       Algorithm: A* over 8 neighbors (cardinal + diagonal).

●       Costs:

○       Base step: get_movement_cost(tile) (impassable if >= INF).

○       Diagonals: multiplier 1.4 (approx √2).

○       Climb: height_diff * CLIMB_COST (if height_diff > 0).

○       Facing: TURN_COST when the movement direction ≠ current facing.

●       Facing state: During expansion, facing is derived from edge direction. The initial node uses start_facing.

●       Footprint validation: For each neighbor, every tile in the footprint must be in-bounds and unoccupied except:

○       The goal is allowed even if currently occupied (so you can path to a currently blocked goal).

●       Success: Reconstructs path when current == goal. If start is unreachable from goal, returns [].

Tip: For large maps, consider an open set as a binary heap and a closed set to lower CPU churn if you profile hot spots.

Line of Sight Details
●       Bresenham line from A → B.

●       A line is blocked if any intermediate tile (not endpoints) is:

○       occupied,

○       flagged as los_blocker, or

○       has cover == "full".

●       Diagonal corner rule: when the ray steps diagonally, it checks both adjacent orthogonal corner tiles to prevent peeking “through corners.”

Note: Endpoints are always considered visible to themselves. If you want “target in hard cover blocks LOS at the target,” extend the rule to include pos == b.

ZOC, Flanking & AOE
●       ZOC: Based on actor border tiles (so large units project ZOC from their perimeter) and the requested arc.

○       Arc thresholds (cosine-like): FRONT_T = 0.25, SIDE_T = 0.25 (~±75° front, ~±75° sides).

○       Arcs: "front", "rear", "left", "right", "sides", "all".

●       Flanking: An actor is flanked if ≥2 attackers threaten it (in ZOC) and their direction vectors relative to the defender are nearly opposite (dot < -0.9).

●       Attack arc: front/left/right/rear computed from defender’s facing vs vector to attacker (using angle_to).

AOE shapes
●       burst: square radius using Chebyshev distance (via get_positions_in_range).

●       cone: forward-biased using a dot-product threshold (> 0.7 ≈ 90° total spread). Distance check currently uses Manhattan; see “Roadmap” for alternatives.

●       line: 1-tile line along direction, length n.

●       wall: line perpendicular to direction, centered at origin, total length.


Performance Notes
●       Dictionaries keyed by Vector2i are efficient in GDScript 2, but tight loops over big maps can still be hot.

●       Avoid frequent get_all_actors() in per-frame code; cache if needed.

●       Terrain metadata lookups are O(1).

●       A* uses a linear search over open_set for the best node. For very large searches, swap to a binary heap (priority queue) in GDScript or C#.

●       For multi-tile actors, footprint checks multiply the cost of neighbor evaluation. Consider lowering neighbor set (no diagonals) if needed.


Serialization & Save/Load
Being a Resource, this is straightforward:
# Save
ResourceSaver.save(grid, "user://tactical_grid.tres")

# Load
var grid := load("user://tactical_grid.tres") as LogicGridMap

If actors are Nodes, store a stable identifier (UUID, name path) outside the grid and re-bind after load. The grid only stores Object references; those won’t survive a fresh run unless they’re re-created.

Extending & Modding
●       Alternate heuristics: Replace get_chebyshev_distance with octile or weighted Manhattan.

●       Custom cover rules: `covers` already track facing and height; override `get_cover_modifier` for advanced effects.

●       Opportunity attacks: Use get_tiles_under_zoc to detect movement through enemy ZOCs.

●       Terrain effects: Leverage tile_tags (e.g., "mud" → extra TURN_COST, "ice" → forced slide, "smoke" → temporary los_blocker).

●       Team/faction logic: Wrap public API to filter threat checks by allegiance.


Troubleshooting Guide
“move_actor returns false unexpectedly”
●       Destination footprint out of bounds or collides with another actor.

●       For multi-tile actors, every tile is validated; check all tiles in get_tiles_for_footprint(to, size).

“Actors disappear or duplicate in get_all_actors()”
●       Ensure actors are removed via remove_actor(actor) before freeing the underlying Node.

●       Don’t reuse the same Object for multiple entities simultaneously.

“Pathfinding can’t find a path that looks obvious”
●       Any tile along the route may have INF movement cost (impassable) or height_diff > MAX_CLIMB_HEIGHT.

●       Goal is allowed even if occupied, but intermediate nodes are not.

●       If facing changes are expensive, TURN_COST might discourage turning; try lowering TURN_COST.

“LOS is blocked when it shouldn’t be”
●       Check for diagonal corner cases—two corners adjacent to a diagonal step can block LOS.

●       Tiles with cover == "full" also block LOS (by design). Change if you want “cover reduces hit % but not LOS.”

“ZOC/Flanking feel too permissive/restrictive”
●       Tweak arc thresholds in get_zone_of_control (FRONT_T, SIDE_T) or the flank dot (-0.9).


Testing Tips
●       Unit tests (e.g., with [GUT] or @tool scripts):

○       Map edges: is_in_bounds, placing actors at borders.

○       Multi-tile: footprints across obstacles; movement into tight corridors.

○       LOS: rays grazing corners, blockers at endpoints vs intermediates.

○       Costs: INF walls; climb limits; turn penalties.

○       ZOC/Flank: arrange attackers at cardinal/diagonal positions and assert results.

●       Golden paths: Precompute expected paths on small maps and compare arrays.

Minimal example using built-in assertions:
func test_basic_path() -> void:
    var g := LogicGridMap.new()
    g.width = 8; g.height = 8
    var a := {"grid_pos": Vector2i(1,1), "size": Vector2i(1,1), "facing": Vector2i.RIGHT}
    assert(g.move_actor(a, a["grid_pos"]))
    g.set_movement_cost(Vector2i(3,1), INF) # wall
    var path := g.find_path_for_actor(a, a["grid_pos"], Vector2i(5,1))
    assert(path.size() > 0)
    assert(path.front() == a["grid_pos"] and path.back() == Vector2i(5,1))


Roadmap / Ideas
●       Priority queue for A* open_set.

●       Optional closed set and consistent heuristic toggles.

●       Team/faction filters for ZOC & flanking.

●       Directional cover and elevation advantage in LOS/hit chance.

●       Cone distance metric: switch from Manhattan to Chebyshev/Euclidean for smoother cones.

●       Configurable diagonal movement (on/off) and corner cutting rules.


Notes for Maintainers
●       The script already fixes a few typed array pitfalls by constructing typed Array[T] explicitly (e.g., get_all_actors). Keep that pattern to avoid analyzer warnings.

●       When adding new returns typed as Array[Vector2i]/Array[Object], explicitly type the local arrays and ensure all appends satisfy the type checker.

●       Be mindful of Object keys in dictionaries: if you migrate to C# or use signals/threading, ensure you don’t accidentally duplicate or free keys while referenced.

●       Internal helpers like _get_border_tiles and get_tiles_for_footprint form the backbone of multi-tile correctness—prefer extending them over inlining footprint logic elsewhere.


License & Attribution
This README describes the LogicGridMap GDScript resource intended for Godot 4.x projects. Adapt freely within your project’s license. If you publish improvements, consider contributing a patch/readme update so others can benefit ❤️

Quick Reference (Cheat Sheet)
●       Place: move_actor(actor, pos)

●       Remove: remove_actor(actor)

●       Path: find_path_for_actor(actor, from, to)

●       LOS: has_line_of_sight(a, b)

●       AOE: get_aoe_tiles("cone"|"burst"|"line"|"wall", origin, dir, range)

●       ZOC: get_zone_of_control(actor, r, "front"|...)

●       Flank: is_flanked(actor)

●       Terrain: set_movement_cost, set_height, set_cover, add_tile_tag


