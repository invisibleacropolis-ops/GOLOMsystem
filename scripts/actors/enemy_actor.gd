extends "res://scripts/core/base_actor.gd"
class_name EnemyActor

## Basic enemy AI that seeks out player-controlled units.
## On its turn the enemy will attack if a target is within `attack_range`.
## Otherwise it will pathfind toward the closest player before ending its turn.
## The actor always yields the initiative once an action has been taken.
const PlayerActor = preload("res://scripts/actors/player_actor.gd")

var runtime
var attack_range: int = 1 ## Maximum Manhattan distance for attacks.
var weapon_name: String = "Rusty Axe"
var mesh_kind: String = "cube" ## visual proxy shape

func _ready() -> void:
    if runtime:
        runtime.timespace.turn_started.connect(_on_turn_started)

## Evaluate the battlefield when this actor's turn begins.
## Prioritizes attacking targets in range before advancing toward them.
func _on_turn_started(actor: Object) -> void:
    if actor != self:
        return
    await get_tree().create_timer(0.5).timeout

    # Current grid position for this actor.
    var pos: Vector2i = runtime.grid_map.actor_positions.get(self, Vector2i.ZERO)
    var players: Array[Object] = []
    # Collect all player-controlled actors currently on the grid.
    for a in runtime.grid_map.actor_positions.keys():
        if a is PlayerActor:
            players.append(a)

    if players.is_empty():
        runtime.timespace.end_turn()
        return

    # Identify the closest player unit by Manhattan distance.
    var target := players[0]
    var target_pos: Vector2i = runtime.grid_map.actor_positions[target]
    var target_dist = runtime.grid_map.get_distance(pos, target_pos)
    for player in players:
        var player_pos: Vector2i = runtime.grid_map.actor_positions[player]
        var dist = runtime.grid_map.get_distance(pos, player_pos)
        if dist < target_dist:
            target = player
            target_pos = player_pos
            target_dist = dist

    if target_dist <= attack_range:
        # Engage the target when it is close enough for the equipped weapon.
        runtime.timespace.perform(self, "attack", target)
    else:
        # Advance one tile along the shortest path toward the target.
        var path: Array[Vector2i] = runtime.grid_map.find_path_for_actor(self, pos, target_pos)
        if path.size() > 1:
            # The path includes the current tile at index 0.
            runtime.timespace.move_current_actor(path[1])

    # Always end the turn after taking an action or failing to move.
    runtime.timespace.end_turn()
