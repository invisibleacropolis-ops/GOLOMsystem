extends Node

# Root scene that bootstraps the workspace, executes all module tests,
# and, once the logic layer is verified, procedurally builds the world.
const TEST_LOOP := preload("res://scripts/tests/test_loop.gd")
const WORLD_SCENE := preload("res://scenes/world.tscn")
const HUD_SCENE := preload("res://scenes/MainHUD.tscn") # HUD overlay; expects Runtime and WorldRoot siblings
const ProceduralMapGenerator := preload("res://scripts/modules/procedural_map_generator.gd")
const T2GBridge := preload("res://scripts/integration/t2g_bridge.gd")
const RuntimeServices := preload("res://scripts/modules/runtime_services.gd")
const PlayerActor := preload("res://scripts/actors/player_actor.gd")
const EnemyActor := preload("res://scripts/actors/enemy_actor.gd")
const NpcActor := preload("res://scripts/actors/npc_actor.gd")
const GRID_RENDERER_SCENE := preload("res://scenes/modules/GridRealtimeRenderer.tscn")

var workspace: Node = null
# References stored for headless ASCII mode interaction.
var runtime: RuntimeServices
var player: PlayerActor
var _renderer: GridRealtimeRenderer
var _input_thread: Thread
# Maps actor instances to their corresponding Sprite2D nodes for visual updates.
var _actor_sprites: Dictionary = {}


func _ready() -> void:
    var args := OS.get_cmdline_args()
    if "--run-tests" in args:
        # TestLoop continuously exercises every logic module and reports results
        # through the Workspace debugger.
        var tester = Node.new()
        tester.set_script(TEST_LOOP)
        tester.tests_completed.connect(_on_tests_completed)
        add_child(tester)
    else:
        _init_game()


func _on_tests_completed(result: Dictionary) -> void:
    if result.get("failed", 0) > 0:
        var log: String = result.get("log", "")
        WorkspaceDebugger.log_error(
            "Module tests failed (%d/%d)\n%s" % [result.failed, result.total, log]
        )
        push_error("Module tests failed; see workspace log")
        return

    WorkspaceDebugger.log_info("All module tests passed (%d)" % result.total)
    _init_game()
    # HUD omitted in headless mode


## Build the world and core actors, starting the game in a playable state.
func _init_game() -> void:
    # Only instantiate the world and HUD once even if tests loop.

    if not get_node_or_null("WorldRoot") and WORLD_SCENE:
        var world := WORLD_SCENE.instantiate()
        world.name = "WorldRoot"
        add_child(world)

        var gen = ProceduralMapGenerator.new()
        var params := {"width": 64, "height": 64, "seed": "demo", "terrain": "plains"}
        var logic_map := gen.generate(params)
        gen.free()  # Avoid leaking the generator instance

        # Bridge the logical grid into the TileToGridMap system.
        var bridge := T2GBridge.new()
        bridge.logic = logic_map
        bridge.terrain_layer_path = world.get_node("TerrainLayers/Ground").get_path()
        world.add_child(bridge)

        # Runtime services coordinate grid and turn logic for actors.
        runtime = RuntimeServices.new()
        runtime.name = "Runtime"
        runtime.grid_map = logic_map
        runtime.timespace.set_grid_map(runtime.grid_map)
        add_child(runtime)

        # Visual renderer for interactive mode; in headless mode ASCII is used.
        if DisplayServer.get_name() != "headless":
            _renderer = GRID_RENDERER_SCENE.instantiate()
            _renderer.ascii_include_actors = true
            _renderer.ascii_actor_group = "actors"
            _renderer.set_grid_size(runtime.grid_map.width, runtime.grid_map.height)
            add_child(_renderer)

        # Instantiate core actors and register them with the timespace.
        player = PlayerActor.new("Player")
        var enemy = EnemyActor.new("Enemy")
        var npc = NpcActor.new("NPC")
        player.runtime = runtime
        enemy.runtime = runtime
        npc.runtime = runtime
        player.add_to_group("actors")
        enemy.add_to_group("actors")
        npc.add_to_group("actors")
        add_child(player)
        add_child(enemy)
        add_child(npc)

        # Create simple sprites so actors are visible in non-headless mode.
        if DisplayServer.get_name() != "headless":
            _create_visual_for_actor(player, Color(0.2, 0.6, 1.0))
            _create_visual_for_actor(enemy, Color(1.0, 0.2, 0.2))
            _create_visual_for_actor(npc, Color(0.2, 1.0, 0.2))

        runtime.timespace.add_actor(player, 10, 2, Vector2i(8, 8))
        runtime.timespace.add_actor(enemy, 5, 2, Vector2i(20, 20))
        runtime.timespace.add_actor(npc, 1, 2, Vector2i(32, 32))
        runtime.timespace.start_round()
        runtime.timespace.action_performed.connect(_on_action_performed)

        if DisplayServer.get_name() == "headless":
            _start_ascii_mode(runtime.grid_map)
        else:
            _update_all_actor_visuals()



func _start_ascii_mode(grid_map) -> void:
    # Instantiate the ASCII renderer and start stdin loop for interaction.
    _renderer = GRID_RENDERER_SCENE.instantiate()
    _renderer.ascii_include_actors = true
    _renderer.ascii_actor_group = "actors"
    _renderer.set_grid_size(grid_map.width, grid_map.height)
    add_child(_renderer)

    # Spawn a thread to handle stdin so the main thread keeps processing.
    _input_thread = Thread.new()
    _input_thread.start(Callable(self, "_stdin_loop"))


func _stdin_loop() -> void:
    while true:
        var line := OS.read_string_from_stdin(1024).strip_edges()
        if line == "quit":
            call_deferred("_quit_game")
            return
        var dir := Vector2i.ZERO
        match line:
            "w":
                dir = Vector2i.UP
            "s":
                dir = Vector2i.DOWN
            "a":
                dir = Vector2i.LEFT
            "d":
                dir = Vector2i.RIGHT
            _:
                pass
        if dir != Vector2i.ZERO:
            call_deferred("_try_move_player", dir)


func _create_visual_for_actor(actor: BaseActor, color: Color) -> void:
    # Generate a simple colored square to represent the actor.
    var img := Image.create(int(_renderer.cell_size.x), int(_renderer.cell_size.y), false, Image.FORMAT_RGBA8)
    img.fill(color)
    var tex := ImageTexture.create_from_image(img)
    var sprite := Sprite2D.new()
    sprite.texture = tex
    actor.add_child(sprite)
    _actor_sprites[actor] = sprite

func _update_actor_visual(actor: BaseActor) -> void:
    var sprite: Sprite2D = _actor_sprites.get(actor)
    if sprite and _renderer:
        sprite.position = Vector2(actor.grid_pos.x * _renderer.cell_size.x, actor.grid_pos.y * _renderer.cell_size.y)

func _update_all_actor_visuals() -> void:
    for a in get_tree().get_nodes_in_group("actors"):
        _update_actor_visual(a)

func _on_action_performed(actor, action_id: String, _payload) -> void:
    # React to movement actions so Sprite2D nodes track logical positions.
    if action_id == "move":
        _update_actor_visual(actor)

func _quit_game() -> void:
    if _input_thread:
        _input_thread.wait_to_finish()
    get_tree().quit()


func _try_move_player(dir: Vector2i) -> void:
    if runtime == null or player == null:
        return
    if runtime.timespace.get_current_actor() != player:
        return
    var pos: Vector2i = runtime.grid_map.actor_positions.get(player, Vector2i.ZERO)
    var target = pos + dir
    if runtime.timespace.move_current_actor(target):
        runtime.timespace.end_turn()
