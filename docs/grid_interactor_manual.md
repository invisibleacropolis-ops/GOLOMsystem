# Grid Interactor Manual

`grid_interactor.gd` translates mouse input into tile and actor selections. It
expects a `GridRealtimeRenderer` to visualize previews and a logic node that can
report actor occupancy.

## Usage

Preload and instantiate the interactor, then wire it to your renderer and logic
nodes:

```gdscript
const GridInteractor = preload("res://scripts/grid/grid_interactor.gd")
const GridRenderer = preload("res://scripts/modules/GridRealtimeRenderer.gd")
const GridLogicScene = preload("res://scenes/GridLogic.tscn")

@onready var renderer: GridRealtimeRenderer = GridRenderer.new()
@onready var logic = GridLogicScene.instantiate()

func _ready() -> void:
    add_child(renderer)
    add_child(logic)
    var inter: GridInteractor = GridInteractor.new()
    add_child(inter)
    inter.grid_renderer_path = renderer.get_path()
    inter.grid_logic_path = logic.get_path()
    inter.tile_clicked.connect(_on_tile_clicked)
```

Implement signal handlers to highlight tiles or select actors:

```gdscript
func _on_tile_clicked(tile: Vector2i, button: int, mods: int) -> void:
    if button == MOUSE_BUTTON_LEFT:
        renderer.clear_all()
        renderer.set_cell_color(tile, Color(1, 1, 0, 0.5))
```

See `scripts/examples/grid_interactor_demo.gd` for a full example including
selection rectangles and actor highlighting.

Run `godot4 --headless --path . --script scripts/test_runner.gd` to execute
module self-tests and ensure deterministic behavior across platforms.
