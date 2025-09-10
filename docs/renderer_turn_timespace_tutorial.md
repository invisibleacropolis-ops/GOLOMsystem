# Combining GridRealtimeRenderer with TurnBasedGridTimespace

This tutorial walks through wiring the realtime grid visualization with the turn manager.

## 1. Create the Scene
1. Add a `Node2D` as the root of a new scene.
2. Instance `GridRealtimeRenderer` and `TurnBasedGridTimespace` as children.
3. Set the renderer's `grid_size` and `cell_size` to match the map.

## 2. Register Actors
```
var timespace := $TurnBasedGridTimespace
var renderer := $GridRealtimeRenderer
var actor := BaseActor.new("hero", Vector2i.ZERO, Vector2i.RIGHT, Vector2i.ONE)
renderer.set_cell_color(Vector2i.ZERO, Color.BLUE)
timespace.add_actor(actor, 10, 2, Vector2i.ZERO, 0)
```

## 3. Advance Turns
Call `timespace.start_round()` then invoke `timespace.perform("move", target)` during turns.
Each tick update the renderer with positions, marks, or labels as needed.

## 4. Use GPU Labels
```
renderer.begin_labels()
renderer.push_label("Hero", actor.grid_pos)
renderer.end_labels()
```

## 5. Night Vision or Fog of War
Toggle visualization modes at runtime:
```
renderer.set_shader_mode(1) # night vision
```

This scene forms the basis for tactical prototypes combining both systems.
