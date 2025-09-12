extends Node
class_name SimpleEnemyAI

##\
## Basic enemy turn logic for the vertical slice.
##
## This stateless helper consults `RuntimeServices` to decide a single
## action for an enemy actor each time its turn begins. It listens to
## `TurnBasedGridTimespace` signals so it can chain additional actions
## if the actor still has Action Points remaining. When it cannot act
## further, the AI ends the actor's turn.
##
var services: Node
var _acting: Object = null

func _init(_services: Node) -> void:
    services = _services

func _ready() -> void:
    if services and services.timespace:
        services.timespace.action_performed.connect(_on_action_performed)
        services.timespace.turn_ended.connect(_on_turn_ended)

##
## Initiates the enemy's decision loop for the given actor.
##
func take_turn(actor: Object) -> void:
    _acting = actor
    _decide_next_action()

func _decide_next_action() -> void:
    if _acting == null:
        return
    var a_pos = services.grid_map.actor_positions.get(_acting, null)
    if a_pos == null:
        services.timespace.end_turn(); return
    var my_fac := String(_acting.get("faction")) if _acting.has_method("get") else ""
    var target = _nearest_opponent(a_pos, my_fac)
    if target == null:
        services.timespace.end_turn(); return
    var t_pos = services.grid_map.actor_positions.get(target, null)
    if t_pos == null:
        services.timespace.end_turn(); return
    # Flee if critically wounded
    var hp := int(_acting.get("HLTH")) if _acting.has_method("get") else 1
    if hp <= 1:
        var away := _step_away(a_pos, t_pos)
        if away != a_pos and services.timespace.can_perform(_acting, "move", away):
            services.timespace.perform(_acting, "move", away)
            return
    if services.grid_map.has_line_of_sight(a_pos, t_pos) and services.timespace.can_perform(_acting, "attack", target):
        services.timespace.perform(_acting, "attack", target)
        return
    var path: Array[Vector2i] = services.grid_map.find_path_for_actor(_acting, a_pos, t_pos)
    if path.size() >= 2:
        var next_step: Vector2i = path[1]
        if services.timespace.can_perform(_acting, "move", next_step):
            services.timespace.perform(_acting, "move", next_step)
            return
    if services.timespace.can_perform(_acting, "overwatch", null):
        services.timespace.perform(_acting, "overwatch", null)
    services.timespace.end_turn()

func _on_action_performed(actor: Object, _action_id: String, _payload: Variant) -> void:
    if actor != _acting:
        return
    if services.timespace.get_action_points(actor) > 0:
        _decide_next_action()
    else:
        services.timespace.end_turn()

func _on_turn_ended(actor: Object) -> void:
    if actor == _acting:
        _acting = null

func _nearest_opponent(from_pos: Vector2i, my_fac: String):
    var best = null
    var best_d = 1_000_000
    for other in services.grid_map.get_all_actors():
        if other == null:
            continue
        var fac = String(other.get("faction")) if other.has_method("get") else ""
        if fac == my_fac:
            continue
        if int(other.get("HLTH")) <= 0:
            continue
        var p = services.grid_map.actor_positions.get(other, null)
        if p == null:
            continue
        var d = services.grid_map.get_chebyshev_distance(from_pos, p)
        if d < best_d:
            best_d = d
            best = other
    return best

func _step_away(from_pos: Vector2i, threat_pos: Vector2i) -> Vector2i:
    var dx = sign(from_pos.x - threat_pos.x)
    var dy = sign(from_pos.y - threat_pos.y)
    var candidates = [Vector2i(from_pos.x + dx, from_pos.y), Vector2i(from_pos.x, from_pos.y + dy), Vector2i(from_pos.x + dx, from_pos.y + dy)]
    for c in candidates:
        if services.grid_map.is_in_bounds(c) and not services.grid_map.is_occupied(c):
            return c
    return from_pos
