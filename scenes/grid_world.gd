extends Node2D

## Demonstrates wiring of GridInteractor to renderer and logic nodes.
##
## The scene expects child nodes named `GridRealtimeRenderer`, `GridLogic`,
## and `GridInteractor`. On ready it connects interaction signals to simple
## handlers that paint tiles using `GridRealtimeRenderer`.

@onready var inter: GridInteractor = $GridInteractor
@onready var vis: GridRealtimeRenderer = $GridRealtimeRenderer
@onready var logic = $GridLogic

func _ready() -> void:
    inter.grid_renderer_path = vis.get_path()
    inter.grid_logic_path = logic.get_path()
    inter.tile_clicked.connect(_on_tile_clicked)
    inter.tiles_selected.connect(_on_tiles_selected)
    inter.actor_clicked.connect(_on_actor_clicked)
    inter.actors_selected.connect(_on_actors_selected)

func _on_tile_clicked(tile: Vector2i, button: int, mods: int) -> void:
    if button == MOUSE_BUTTON_LEFT:
        vis.clear_all()
        vis.set_cell_color(tile, Color(1, 1, 0, 0.5))
        vis.set_stroke(tile, Color(1, 1, 0, 1), 0.18, 0.05)

func _on_actor_clicked(actor_id, tile: Vector2i, button: int, mods: int) -> void:
    if logic and logic.has_method("select_actor"):
        logic.select_actor(actor_id)
    vis.clear_all()
    vis.set_cell_color(tile, Color(0.2, 0.9, 1.0, 0.45))
    vis.set_stroke(tile, Color(0.2, 1.0, 0.9, 1.0), 0.16, 0.05)

func _on_tiles_selected(tiles: PackedVector2Array, additive: bool, toggle: bool) -> void:
    vis.clear_all()
    vis.set_cells_color_bulk(tiles, Color(0.0, 0.6, 1.0, 0.28))
    vis.stroke_outline_for(tiles, Color(0.2, 1.0, 0.9, 0.95), 0.14, 0.04)

func _on_actors_selected(actor_ids: Array, tiles: PackedVector2Array, additive: bool, toggle: bool) -> void:
    pass
