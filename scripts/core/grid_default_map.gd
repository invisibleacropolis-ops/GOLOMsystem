extends Node2D

## Loads a 32x32 test map with three actors and keeps grid and
## timespace logic running for interactive updates.
const RuntimeServices := preload("res://scripts/modules/runtime_services.gd")
const GRID_RR_PATH := "res://scripts/modules/GridRealtimeRenderer.gd"
const BaseActor := preload("res://scripts/core/base_actor.gd")

class Actor extends BaseActor:
    var grid_color: Color
    func _init(name: String, color: Color):
        super(name)
        grid_color = color
    func get_grid_color() -> Color:
        return grid_color

var runtime: RuntimeServices
var grid_layer: Node2D
var grid_vis: Node

func _ready() -> void:
    # Initialize aggregate runtime services
    runtime = RuntimeServices.new()
    runtime.grid_map.width = 32
    runtime.grid_map.height = 32
    add_child(runtime)

    # Visual layer is isolated from the logic modules and other UI.
    # Skip creation when running in headless mode to avoid shader errors.
    if DisplayServer.get_name() != "headless":
        grid_layer = Node2D.new()
        add_child(grid_layer)
        var GridRealtimeRenderer = load(GRID_RR_PATH)
        grid_vis = GridRealtimeRenderer.new()
        grid_vis.set_grid_size(runtime.grid_map.width, runtime.grid_map.height)
        grid_layer.add_child(grid_vis)

    # Create actors with simple color coding
    var player := Actor.new("Player", Color.GREEN)
    var enemy := Actor.new("Enemy", Color.RED)
    var npc := Actor.new("NPC", Color.BLUE)
    add_child(player)
    add_child(enemy)
    add_child(npc)

    runtime.timespace.add_actor(player, 10, 2, Vector2i(1, 1))
    runtime.timespace.add_actor(enemy, 5, 2, Vector2i(10, 10))
    runtime.timespace.add_actor(npc, 1, 2, Vector2i(5, 5))

    _refresh_visual()

func _refresh_visual() -> void:
    if grid_vis:
        grid_vis.clear_all()
        for actor in runtime.grid_map.actor_positions.keys():
            var pos: Vector2i = runtime.grid_map.actor_positions[actor]
            var color: Color = actor.get_grid_color() if actor.has_method("get_grid_color") else Color.WHITE
            grid_vis.set_cell_color(pos, color)
