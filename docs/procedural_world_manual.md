# Procedural World Module Manual

`procedural_world.gd` builds `LogicGridMap` instances by sampling the
`FastNoiseLiteDatasource` scripts from the `Inspiration` folder.  It returns
both the generated map and a color array suitable for `GridRealtimeRenderer`.

## Usage

```gdscript
var pw := ProceduralWorld.new()
var result := pw.generate(64, 64, 42)
var map : LogicGridMap = result.map
var colors : Array = result.colors
```

Feed `colors` into `GridRealtimeRenderer.apply_color_map()` to visualize the
biome map.

## Testing

Invoke the module's self-test:

```bash
godot4 --headless --path . --script scripts/test_runner.gd -- --module=procedural_world
```
