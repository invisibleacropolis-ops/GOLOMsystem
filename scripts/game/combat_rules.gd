extends Node
class_name CombatRules

## Minimal combat helper for the vertical slice.
## Centralizes cover and damage calculations so abilities and AI
## can share a single reference point for tactical decisions.

## Computes the defensive penalty provided by cover between two units.
## @param a_pos Position of the attacker on the grid.
## @param d_pos Position of the defender on the grid.
## @param grid_map LogicGridMap instance providing cover queries.
## @return An integer penalty (negative values reduce hit chance).
static func compute_cover_bonus(a_pos: Vector2i, d_pos: Vector2i, grid_map: Object) -> int:
    if grid_map == null or not grid_map.has_method("get_cover_modifier"):
        return 0
    return int(grid_map.get_cover_modifier(a_pos, d_pos))

## Computes deterministic damage for a basic attack, factoring cover.
static func compute_damage(attacker: Object, defender: Object, grid_map: Object) -> int:
    if attacker == null or defender == null or grid_map == null:
        return 0
    var a_pos = grid_map.actor_positions.get(attacker, null)
    var d_pos = grid_map.actor_positions.get(defender, null)
    if a_pos == null or d_pos == null:
        return 0
    # Base damage for placeholder abilities
    var dmg := 1
    var pen := compute_cover_bonus(a_pos, d_pos, grid_map)
    # Treat strong cover as absorbing this basic hit entirely.
    if pen <= -40:
        dmg = 0
    return max(dmg, 0)

## Self-test exercising cover bonus calculation.
func run_tests() -> Dictionary:
    var failed := 0
    var total := 0
    var Grid = preload("res://scripts/grid/grid_map.gd")
    var grid := Grid.new()
    grid.width = 2
    grid.height = 1
    grid.set_cover(Vector2i(1, 0), "half")
    total += 1
    var pen := compute_cover_bonus(Vector2i(0, 0), Vector2i(1, 0), grid)
    if pen == 0:
        failed += 1
    grid.free()
    return {"failed": failed, "total": total}

