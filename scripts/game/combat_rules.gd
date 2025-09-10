extends Node
class_name CombatRules

## Minimal combat helper for the vertical slice.
## Computes deterministic damage for a basic attack, factoring cover.

static func compute_damage(attacker: Object, defender: Object, grid_map: Object) -> int:
    if attacker == null or defender == null or grid_map == null:
        return 0
    var a_pos = grid_map.actor_positions.get(attacker, null)
    var d_pos = grid_map.actor_positions.get(defender, null)
    if a_pos == null or d_pos == null:
        return 0
    # Base damage
    var dmg := 1
    # Apply simple cover mitigation using grid_map's cover helper if present.
    if grid_map.has_method("get_cover_modifier"):
        var pen := int(grid_map.get_cover_modifier(a_pos, d_pos))
        # Treat strong cover as absorbing this basic hit entirely.
        if pen <= -40:
            dmg = 0
    return max(dmg, 0)

