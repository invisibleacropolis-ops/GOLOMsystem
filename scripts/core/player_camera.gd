extends Camera2D

## Link to the base actor type so the `player` property can be strongly typed
## without tightly coupling to the concrete player implementation.
const BaseActor = preload("res://scripts/core/base_actor.gd")

## Camera that follows the `PlayerActor` each frame.
##
## The node searches the scene tree for a child named "Player" under
## the root node. Once the player reference is cached, the camera's
## position is updated every frame to match the player's logical grid
## coordinates. This keeps the viewport centered on the player without
## exposing any engine-specific coupling to the rest of the codebase.

var player: BaseActor = null


func _process(_delta: float) -> void:
	if player == null:
		var root := get_tree().get_root().get_node_or_null("Root")
		if root:
			player = root.get_node_or_null("Player")
	if player:
		# Player grid_pos is a Vector2i; cast to Vector2 for Camera2D position
		position = Vector2(player.grid_pos)
