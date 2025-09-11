extends Node
class_name BaseActor

## Emitted when this actor's health drops to zero.
## @param actor The defeated actor (self).
signal defeated(actor)

## Master actor template for all animate creatures.
## Provides grid placement fields, combat stats, attributes,
## and harvestable drops.

# --- grid placement ---
var grid_pos: Vector2i = Vector2i.ZERO  ## origin tile on the grid
var facing: Vector2i = Vector2i.RIGHT  ## current facing direction
var size: Vector2i = Vector2i.ONE  ## footprint in tiles
var faction: String = ""  ## allegiance identifier, e.g. "player" or "enemy"
var mesh_kind: String = "sphere"  ## procedural 3D proxy shape (e.g. "sphere", "cube")


## Initialize with optional name and grid placement.
func _init(
        _name: String = "",
        _pos: Vector2i = Vector2i.ZERO,
        _facing: Vector2i = Vector2i.RIGHT,
        _size: Vector2i = Vector2i.ONE,
        _faction: String = ""
) -> void:
        name = _name
        grid_pos = _pos
        facing = _facing
        size = _size
        faction = _faction


## Change facing direction.
func set_facing(dir: Vector2i) -> void:
        facing = dir


## Human-readable description useful for debugging.
func describe() -> String:
        return "%s[%s]@%s facing %s size %s" % [name, faction, grid_pos, facing, size]


## ASCII representation used by GridRealtimeRenderer.
func get_ascii_symbol() -> String:
        return "@"


## Override to tint actor symbol in ASCII output.
func get_ascii_color() -> Color:
        return Color.WHITE


# --- stats (resource pools and flags) ---
var HLTH: int = 10  ## health points
var CHI: int = 10  ## chi flow power points
var ACT: int = 10  ## action points
var INIT: int = 10  ## initiative value
var STS: int = 0  ## status effect flag
var CND: int = 0  ## battle condition flag
var ENV: int = 0  ## environmental condition flag
var ZOC: int = 2  ## zone of control radius

# --- attributes (environment manipulation) ---
var PWR: int = 3  ## power
var SPD: int = 3  ## speed
var FCS: int = 3  ## focus
var CAP: int = 3  ## capacity
var PER: int = 3  ## perception

# --- harvestables (drops when removed) ---
var XP: int = 0  ## experience points
var LT: int = 0  ## loot or treasure
var QST: int = 0  ## special objects/items/conditions
var SCP: int = 0  ## external script triggers


## Reduce health by `amount` and emit `defeated` when it reaches zero.
## External systems can connect to the signal to remove the actor from the
## grid or trigger death effects.
func apply_damage(amount: int) -> void:
        HLTH = max(HLTH - amount, 0)
        if HLTH == 0:
                emit_signal("defeated", self)
