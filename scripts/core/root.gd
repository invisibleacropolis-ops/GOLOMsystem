extends Node

# Root scene that bootstraps the workspace,
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
# const ASCII_UI_MANAGER_SCENE := preload("res://scripts/modules/ascii_ui_manager.gd") # OLD: No longer needed
const CHARACTER_CREATOR_SCENE := preload("res://scripts/character_creation/character_creator.gd")
const CHARACTER_CREATION_DATA_SCENE := preload("res://scripts/character_creation/character_creation_data.gd")
const CHARACTER_CREATION_GUI_SCENE := preload("res://scenes/ui/CharacterCreationGUI.tscn") # NEW: GUI Scene

var workspace: Node = null
# References stored for headless ASCII mode interaction.
var runtime: RuntimeServices
var player: PlayerActor
var _renderer: GridRealtimeRenderer
# var _ascii_ui_manager: Node = null # OLD: No longer needed
# var _input_thread: Thread # OLD: No longer needed
# Maps actor instances to their corresponding Sprite2D nodes for visual updates.
var _actor_sprites: Dictionary = {}

var _character_creator_instance: Node
var _character_creation_data_instance: Node
var _character_creation_gui_instance: Control

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
        _init_character_creation()

func _init_character_creation() -> void:
    _character_creation_data_instance = CHARACTER_CREATION_DATA_SCENE.new()
    add_child(_character_creation_data_instance)

    _character_creation_gui_instance = CHARACTER_CREATION_GUI_SCENE.instantiate()
    add_child(_character_creation_gui_instance)

    _character_creator_instance = CHARACTER_CREATOR_SCENE.new()
    _character_creator_instance.character_creation_data_path = _character_creation_data_instance.get_path()
    _character_creator_instance.character_creation_gui_path = _character_creation_gui_instance.get_path()
    _character_creator_instance.character_creation_finished.connect(_on_character_creation_finished)
    add_child(_character_creator_instance)

    _character_creator_instance.start_character_creation()

func _on_character_creation_finished(character_profile: Resource) -> void:
    _character_creation_gui_instance.queue_free() # Remove GUI after creation
    _character_creation_data_instance.queue_free() # Free data loader
    _character_creator_instance.queue_free() # Free character creator

    print("Character creation finished for: " + character_profile.character_name)
    # Now proceed with game initialization, passing the character_profile
    _init_game(character_profile)

func _on_tests_completed(result: Dictionary) -> void:
    if result.get("failed", 0) > 0:
        var log: String = result.get("log", "")
        push_error("Module tests failed (%d/%d)\n%s" % [result.failed, result.total, log])
        return

    print("All module tests passed (%d)" % result.total)
    _init_character_creation()

## Build the world and core actors, starting the game in a playable state.
func _init_game(character_profile: Resource) -> void:
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
            _renderer.set_grid_size(runtime.grid_map.width, runtime.grid_map.height)
            add_child(_renderer)
        # else: # OLD: Headless ASCII mode is now handled by CharacterCreator if needed
        #     _renderer = GRID_RENDERER_SCENE.instantiate()
        #     add_child(_renderer)
        #     _ascii_ui_manager = ASCII_UI_MANAGER_SCENE.new()
        #     _ascii_ui_manager.runtime_services_path = runtime.get_path()
        #     _ascii_ui_manager.grid_realtime_renderer_path = _renderer.get_path()
        #     add_child(_ascii_ui_manager)

        # Instantiate core actors and register them with the timespace.
        player = PlayerActor.new(character_profile.character_name) # Use created character name
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

        # NEW: Set player_actor_path for AsciiUIManager after player is added to scene tree
        # if DisplayServer.get_name() == "headless" and _ascii_ui_manager:
        #     _ascii_ui_manager.player_actor_path = player.get_path()

        # Create simple sprites so actors are visible in non-headless mode.
        if DisplayServer.get_name() != "headless":
            _create_visual_for_actor(player, Color(0.2, 0.6, 1.0))
            _create_visual_for_actor(enemy, Color(1.0, 0.2, 0.2))
            _create_visual_for_actor(npc, Color(0.2, 1.0, 0.2))

        runtime.timespace.add_actor(player, 10, 2, Vector2i(8, 8)) # Use character_profile.attributes for AP/initiative later
        runtime.timespace.add_actor(enemy, 5, 2, Vector2i(20, 20))
        runtime.timespace.add_actor(npc, 1, 2, Vector2i(32, 32))
        runtime.timespace.start_round()
        runtime.timespace.action_performed.connect(_on_action_performed)

        # if DisplayServer.get_name() == "headless": # OLD: Handled by CharacterCreator
        #     pass
        # else:
        #     _update_all_actor_visuals()

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
    # if DisplayServer.get_name() == "headless" and _ascii_ui_manager: # OLD: No longer needed
    #     _ascii_ui_manager._update_ascii_display() # Call its update method

func _quit_game() -> void:
    # if _ascii_ui_manager and _ascii_ui_manager.has_method("quit_ascii_mode"): # OLD: No longer needed
    #     _ascii_ui_manager.quit_ascii_mode()
    get_tree().quit()