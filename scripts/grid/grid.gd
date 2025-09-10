# Facade aggregating grid services for external callers.
#
# This lightweight wrapper exposes the original `LogicGridMap` API while
# also providing access to specialised helpers: pathfinding, line of sight,
# and terrain management.  Existing code can continue calling methods on
# this class directly, or reach for the nested service objects.
extends "res://scripts/grid/grid_map.gd"
class_name Grid

const Pathfinding = preload("res://scripts/grid/pathfinding.gd")
const LOS = preload("res://scripts/grid/los.gd")
const GridTerrain = preload("res://scripts/grid/terrain.gd")

## Helper objects composed with the grid instance.
var pathfinding: Pathfinding
var los: LOS
var terrain: GridTerrain

## Initialize composed helper services and ensure base class setup runs.
##
## The parent `LogicGridMap`'s `_init` populates critical fields such as
## neighbor offsets for pathfinding.  Forgetting to call it leaves those
## structures empty, breaking movement queries for multi-tile actors.
func _init() -> void:
    super._init()  # Populate neighbor offsets and other base data.
    pathfinding = Pathfinding.new(self)
    los = LOS.new(self)
    terrain = GridTerrain.new(self)
