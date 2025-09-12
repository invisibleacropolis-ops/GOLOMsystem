# Facade aggregating grid services for external callers.
#
# This lightweight wrapper exposes the original `LogicGridMap` API while
# also providing access to specialised helpers: pathfinding, line of sight,
# and terrain management.  Existing code can continue calling methods on
# this class directly, or reach for the nested service objects.
extends "res://scripts/grid/grid_map.gd"
class_name Grid

var _PathfindingScript
var _LOSScript
var _GridTerrainScript

## Helper objects composed with the grid instance.
var pathfinding
var los
var terrain

## Initialize composed helper services and ensure base class setup runs.
##
## The parent `LogicGridMap`'s `_init` populates critical fields such as
## neighbor offsets for pathfinding.  Forgetting to call it leaves those
## structures empty, breaking movement queries for multi-tile actors.
func _init() -> void:
    super._init()  # Populate neighbor offsets and other base data.
    _PathfindingScript = ResourceLoader.load(
        "res://scripts/grid/pathfinding.gd",
        "",
        ResourceLoader.CacheMode.CACHE_MODE_IGNORE,
    )
    _LOSScript = ResourceLoader.load(
        "res://scripts/grid/los.gd",
        "",
        ResourceLoader.CacheMode.CACHE_MODE_IGNORE,
    )
    _GridTerrainScript = ResourceLoader.load(
        "res://scripts/grid/terrain.gd",
        "",
        ResourceLoader.CacheMode.CACHE_MODE_IGNORE,
    )
    pathfinding = _PathfindingScript.new(self)
    los = _LOSScript.new(self)
    terrain = _GridTerrainScript.new(self)

func _exit_tree() -> void:
    pathfinding = null
    los = null
    terrain = null
    _PathfindingScript = null
    _LOSScript = null
    _GridTerrainScript = null
