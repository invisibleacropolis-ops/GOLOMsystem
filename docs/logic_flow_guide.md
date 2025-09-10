# Logic Flow Guide

This guide traces the startup sequence in `scripts/core/root.gd` from running workspace tests to launching the first round. It is intended to help engineers understand how the runtime pieces fit together.

## Workspace test loop
The root scene instantiates the workspace and attaches a headless test runner. The runner executes every module's `run_tests()` and reports through the workspace debugger:

```gdscript
func _ready() -> void:
        workspace = WORKSPACE_SCENE.instantiate()
        add_child(workspace)

        # TestLoop continuously exercises every logic module and
        # reports results through the Workspace debugger.
        var tester = Node.new()
        tester.set_script(TEST_LOOP)
        tester.tests_completed.connect(_on_tests_completed)
        add_child(tester)
```

## World generation
After all tests pass the root builds the world once using the procedural map generator and bridges it into the tile grid:

```gdscript
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
```

## Runtime service creation
With the grid in place the root brings up runtime services which coordinate turn logic and grid queries:

```gdscript
                # Runtime services coordinate grid and turn logic for actors.
                var runtime := RuntimeServices.new()
                runtime.name = "Runtime"
                runtime.grid_map = logic_map
                runtime.timespace.set_grid_map(runtime.grid_map)
                add_child(runtime)
```

## Actor registration and round start
Core actors are instantiated, wired to the runtime, and registered with initiative values. Finally the first round begins:

```gdscript
                # Instantiate core actors and register them with the timespace.
                var player = PlayerActor.new("Player")
                var enemy = EnemyActor.new("Enemy")
                var npc = NpcActor.new("NPC")
                player.runtime = runtime
                enemy.runtime = runtime
                npc.runtime = runtime
                add_child(player)
                add_child(enemy)
                add_child(npc)

                runtime.timespace.add_actor(player, 10, 2, Vector2i(8, 8))
                runtime.timespace.add_actor(enemy, 5, 2, Vector2i(20, 20))
                runtime.timespace.add_actor(npc, 1, 2, Vector2i(32, 32))
                runtime.timespace.start_round()
```

## Minimal game example
To plug a custom actor into a real scene and kick off the turn system:

```gdscript
extends Node

const RuntimeServices := preload("res://scripts/modules/runtime_services.gd")
const MyActor := preload("res://scripts/actors/my_actor.gd")

func _ready() -> void:
        var runtime := RuntimeServices.new()
        add_child(runtime)

        var hero := MyActor.new("Hero")
        hero.runtime = runtime
        add_child(hero)

        runtime.timespace.add_actor(hero, 10, 2, Vector2i.ZERO)
        runtime.timespace.start_round()
```

This mirrors the flow in `root.gd` but can be embedded in any gameplay scene.
