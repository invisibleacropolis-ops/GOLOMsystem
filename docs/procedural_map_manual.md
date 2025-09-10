# Procedural Map Generator Manual

`procedural_map_generator.gd` builds `LogicGridMap` instances from simple noise
and string-based presets. Engineers can quickly produce deterministic grids for
prototyping without authoring tiles by hand.

## Responsibilities
- Create headless maps for tests or tools using a small parameter dictionary.
- Support repeatable layouts via a string `seed`.
- Offer coarse terrain profiles such as `plains`, `islands`, or `mountains`.

## Usage
```gdscript
var gen := ProceduralMapGenerator.new()
var params = {
    "width": 32,
    "height": 32,
    "seed": "demo",
    "terrain": "islands"
}
var map := gen.generate(params)
```
The returned `LogicGridMap` contains width, height, and per-tile tags based on
the chosen profile. Additional map post-processing can run on the resulting
resource as needed.
