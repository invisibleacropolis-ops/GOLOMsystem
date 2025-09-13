# Logic Flow Guide

This guide traces the startup sequence in `scripts/core/root.gd` from running workspace tests to launching the first round. It is intended to help engineers understand how the runtime pieces fit together, detailing the API interactions and the rationale behind the design.

## 1. Workspace Test Loop

The game's `Root` scene (`scripts/core/root.gd`) is the initial entry point. Its `_ready()` method is responsible for setting up the development environment and ensuring the core modules are functional before launching the game world.

```gdscript
func _ready() -> void:
        workspace = WORKSPACE_SCENE.instantiate() # Instantiates the Workspace scene
        add_child(workspace)

        # TestLoop continuously exercises every logic module and
        # reports results through the Workspace debugger.
        var tester = Node.new()
        tester.set_script(TEST_LOOP) # TEST_LOOP likely points to scripts/test_runner.gd
        tester.tests_completed.connect(_on_tests_completed) # Connects to the test completion signal
        add_child(tester)
```

*   **`Root` (`scripts/core/root.gd`):** This is the main scene that orchestrates the game's initialization.
*   **`Workspace` (`scripts/core/workspace.gd`):** An interactive scene that provides a GUI for loading modules and running their tests. It acts as a control panel for developers.
*   **`test_runner.gd` (`scripts/test_runner.gd`):** This script, when attached to a `Node` and run, iterates through all registered logic modules (e.g., `Abilities`, `Attributes`, `TurnBasedGridTimespace`) and calls their `run_tests()` methods.
*   **Interaction:** The `Root` scene instantiates the `Workspace` and a `test_runner`. The `test_runner`'s `tests_completed` signal is connected to `Root`'s `_on_tests_completed` method. This ensures that the game world only loads if all module tests pass, promoting a "fail fast" development philosophy.

## 2. World Generation

After all module tests successfully complete, the `Root` scene proceeds to build the game world. This involves generating the procedural map and integrating it with the grid system.

```gdscript
        if not get_node_or_null("WorldRoot") and WORLD_SCENE:
                var world := WORLD_SCENE.instantiate() # Instantiates the main game world scene
                world.name = "WorldRoot"
                add_child(world)

                var gen = ProceduralMapGenerator.new() # Creates an instance of the map generator
                var params := {"width": 64, "height": 64, "seed": "demo", "terrain": "plains"}
                var logic_map := gen.generate(params) # Generates the LogicGridMap
                gen.free()  # Avoid leaking the generator instance

                # Bridge the logical grid into the TileToGridMap system.
                var bridge := T2GBridge.new() # Creates an instance of the TileToGridMap bridge
                bridge.logic = logic_map # Assigns the generated LogicGridMap
                bridge.terrain_layer_path = world.get_node("TerrainLayers/Ground").get_path() # Links to the visual terrain layer
                world.add_child(bridge)
```

*   **`WORLD_SCENE`:** This likely refers to a main game world scene (e.g., `scenes/world.tscn` or `scenes/GridDefaultMap.tscn`) that contains visual elements and other game components.
*   **`ProceduralMapGenerator` (`scripts/modules/procedural_map_generator.gd`):** This module is responsible for creating the underlying `LogicGridMap` data based on procedural generation algorithms.
    *   **`generate(params: Dictionary) -> LogicGridMap`:** This method takes a dictionary of parameters (like `width`, `height`, `seed`, `terrain`) and returns a fully generated `LogicGridMap` instance.
*   **`LogicGridMap` (from `scripts/grid/grid_map.gd`):** This is the pure data representation of the game grid, containing information about tiles, terrain, and actor positions. It's a `Resource`, meaning it can be saved and loaded.
*   **`T2GBridge` (from `addons/tile_to_gridmap/t2g_bridge.gd`):** This is a bridge script that connects the logical `LogicGridMap` data to the visual `TileToGridMap` addon. The `TileToGridMap` addon is a Godot plugin that helps convert 2D tilemap data into 3D `GridMap` visuals.
    *   **`logic` (member):** This member is set to the generated `LogicGridMap` instance.
    *   **`terrain_layer_path` (member):** This `NodePath` points to a visual terrain layer within the `WORLD_SCENE`, allowing the bridge to update the 3D visuals based on the `LogicGridMap` data.
*   **Interaction:** The `Root` scene first generates the `LogicGridMap` using `ProceduralMapGenerator.generate()`. Then, it uses the `T2GBridge` to synchronize this logical map with the game's visual `GridMap`, ensuring that the generated terrain is rendered correctly in 3D.

## 3. Runtime Service Creation

With the game grid in place, the `Root` scene then sets up the core runtime services. These services coordinate the turn logic, attribute management, and other essential gameplay systems.

```gdscript
                # Runtime services coordinate grid and turn logic for actors.
                var runtime := RuntimeServices.new() # Creates an instance of the RuntimeServices aggregator
                runtime.name = "Runtime"
                runtime.grid_map = logic_map # Assigns the generated LogicGridMap to RuntimeServices
                runtime.timespace.set_grid_map(runtime.grid_map) # Links the timespace to the grid map
                add_child(runtime)
```

*   **`RuntimeServices` (`scripts/modules/runtime_services.gd`):** This module acts as an aggregator, bringing together all the core logic modules into a single `Node`. This provides a convenient single entry point for other parts of the game to access all backend services.
    *   **`grid_map` (member):** This member of `RuntimeServices` is directly assigned the `LogicGridMap` instance generated in the previous step.
    *   **`timespace` (member):** This member is an instance of `TurnBasedGridTimespace` (aggregated within `RuntimeServices`).
    *   **`timespace.set_grid_map(runtime.grid_map)`:** This crucial call links the `TurnBasedGridTimespace` module to the `LogicGridMap`, allowing the turn manager to understand the spatial layout of the game world.
*   **Interaction:** `RuntimeServices` centralizes access to all core game logic. By assigning the `LogicGridMap` to `RuntimeServices.grid_map` and then linking it to `RuntimeServices.timespace`, the entire backend system becomes interconnected and ready for gameplay.

## 4. Actor Registration and Round Start

Finally, the core actors (player, enemies, NPCs) are instantiated, linked to the runtime services, registered with the turn management system, and the first round of the game begins.

```gdscript
                # Instantiate core actors and register them with the timespace.
                var player = PlayerActor.new("Player") # Creates a PlayerActor instance
                var enemy = EnemyActor.new("Enemy")   # Creates an EnemyActor instance
                var npc = NpcActor.new("NPC")         # Creates an NpcActor instance
                player.runtime = runtime # Assigns the RuntimeServices instance to each actor
                enemy.runtime = runtime
                npc.runtime = runtime
                add_child(player) # Adds actors to the scene tree
                add_child(enemy)
                add_child(npc)

                # Register actors with the TurnBasedGridTimespace
                runtime.timespace.add_actor(player, 10, 2, Vector2i(8, 8)) # Add player with initiative, AP, and position
                runtime.timespace.add_actor(enemy, 5, 2, Vector2i(20, 20)) # Add enemy
                runtime.timespace.add_actor(npc, 1, 2, Vector2i(32, 32))   # Add NPC
                runtime.timespace.start_round() # Initiates the first round of combat
```

*   **`PlayerActor`, `EnemyActor`, `NpcActor`:** These are likely custom actor classes that inherit from a `BaseActor` (as described in `developer_overview.md`). They represent the entities that will participate in the game.
*   **`actor.runtime = runtime`:** Each actor is given a direct reference to the `RuntimeServices` instance. This allows actors to easily access all the core game logic modules (e.g., `runtime.timespace`, `runtime.attributes`, `runtime.abilities`) without needing to search the scene tree. This is a common pattern for dependency injection.
*   **`TurnBasedGridTimespace.add_actor(actor: Object, initiative: int, action_points: int, pos: Vector2i) -> void`:** This method registers an actor with the turn management system.
    *   `actor`: The actor object to add.
    *   `initiative`: Determines the actor's turn order (higher values act first).
    *   `action_points`: The initial action points for the actor.
    *   `pos`: The actor's starting position on the grid.
*   **`TurnBasedGridTimespace.start_round() -> void`:** This method officially kicks off the turn-based combat. It resets action points for all registered actors and begins the first turn sequence.
*   **Interaction:** Actors are instantiated and then explicitly added to the `TurnBasedGridTimespace` with their initial combat parameters. The `start_round()` call then begins the game loop, where `TurnBasedGridTimespace` will manage the turns of these registered actors.

## Minimal Game Example

This simplified example demonstrates how to plug a custom actor into a scene and kick off the turn system, mirroring the flow in `root.gd` but suitable for embedding in any gameplay scene.

```gdscript
extends Node

const RuntimeServices := preload("res://scripts/modules/runtime_services.gd")
const MyActor := preload("res://scripts/actors/my_actor.gd") # Your custom actor class

func _ready() -> void:
        var runtime := RuntimeServices.new()
        add_child(runtime) # Add RuntimeServices to the scene tree

        var hero := MyActor.new("Hero") # Create your custom actor
        hero.runtime = runtime # Inject the runtime services
        add_child(hero) # Add your actor to the scene tree

        # Add your actor to the turn-based timespace
        runtime.timespace.add_actor(hero, 10, 2, Vector2i.ZERO) # Initiative 10, 2 AP, starts at (0,0)
        runtime.timespace.start_round() # Begin the game round
```

This example highlights the essential steps: instantiate `RuntimeServices`, create your actors, link them to `RuntimeServices`, add them to the `TurnBasedGridTimespace`, and then start the round. This pattern ensures that your custom game logic can seamlessly integrate with the core backend systems.