extends Node
class_name BattleController

## Wires RuntimeServices, GridRealtimeRenderer, GridInteractor, and BattleHUD
## to provide basic selection, movement, and End Turn flow for the vertical slice.

@export var services_path: NodePath
@export var renderer_path: NodePath
@export var interactor_path: NodePath
@export var hud_path: NodePath
@export var hotbar_path: NodePath
@export var grid_3d_root_path: NodePath

@onready var services = get_node(services_path)
@onready var vis = get_node(renderer_path)
@onready var interactor = get_node(interactor_path)
@onready var hud = (get_node_or_null(hud_path))
@onready var hotbar = (get_node_or_null(hotbar_path))
@onready var grid3d_root: Node = (get_node_or_null(grid_3d_root_path))

var selected_actor: Object = null
var reachable: Array[Vector2i] = []
var los_targets: Array[Vector2i] = []
var attack_mode = false
var _auto_resolve := false
var _t2g_bridge: Node = null
var _gridmap3d: GridMap = null
var _actor_proxies: Dictionary = {}
var _last_positions: Dictionary = {}

func _ready() -> void:
    _assert_wiring()
    _setup_grid()
    _spawn_demo_squads()
    _connect_signals()
    # Announce battle start before the first round
    if services and services.event_bus:
        services.event_bus.push({"t": "battle_begins"})
    services.timespace.start_round()

func _assert_wiring() -> void:
    assert(services != null, "BattleController: services_path not set")
    assert(vis != null, "BattleController: renderer_path not set")
    assert(interactor != null, "BattleController: interactor_path not set")
    # HUD is optional; if provided it will be updated and can emit end turn

func _setup_grid() -> void:
    # Build a 32x32 world using MapGenerator -> TileToGridmap addon.
    var MapGen = preload("res://scripts/modules/map_generator.gd")
    var tileset: TileSet = null
    # The example TileSet depends on imported textures that may be absent
    # when the project is run headless.  Verify the import file exists
    # before attempting to load to avoid runtime errors.
    if FileAccess.file_exists("res://addons/tile_to_gridmap/example/tilemaps/terrain512_dg.png.import"):
        tileset = load("res://addons/tile_to_gridmap/example/tilemaps/example_terrain.tres")
    var meshlib: MeshLibrary = null
    # Likewise ensure the mesh library's texture has been imported.
    if FileAccess.file_exists("res://addons/tile_to_gridmap/example/gridmaps/meshes/dualgridterrain_0.png.import"):
        meshlib = load("res://addons/tile_to_gridmap/example/gridmaps/scenes/library/dg_mesh_lib.tres")

    # Map LogicGridMap terrain tags -> TileSet atlas coordinates used by T2GTerrainLayer
    var atlas := {
        "grass": Vector2i(2, 1),
        "dirt": Vector2i(3, 1),
        "hill": Vector2i(6, 1),
        "mountain": Vector2i(7, 1), # use cliff art for mountains
        "water": Vector2i(8, 1),    # watergrass tile
        "road": Vector2i(4, 1)      # tilegrass as a simple road visual
    }

    var gen = MapGen.new()
    var result: Dictionary = gen.build({
        "width": 32,
        "height": 32,
        "seed": "slice",
        "terrain": "plains",
        "tileset": tileset,
        "terrain_atlas": atlas,
        "mesh_library": meshlib,
        "tile_size": 8,
        "grid_height": 0,
    })

    # Wire runtime services to the generated logic map
    services.grid_map = result.map
    services.timespace.set_grid_map(services.grid_map)
    _t2g_bridge = result.bridge
    if result.grid_map is GridMap:
        _gridmap3d = result.grid_map

    # Attach the 3D GridMap to the world if a root is provided
    if grid3d_root == null and has_node("../World3D/Gridmaps"):
        grid3d_root = get_node("../World3D/Gridmaps")
    if grid3d_root != null and result.grid_map is GridMap:
        grid3d_root.add_child(result.grid_map)
    # Ensure 3D actors container exists
    if has_node("../World3D/Actors"):
        var aroot = get_node("../World3D/Actors")
        aroot.visible = true

    # Keep the 2D realtime renderer for overlays and ASCII
    if vis.has_method("set_grid_map"):
        vis.set_grid_map(services.grid_map)
    if vis.has_method("set_grid_size"):
        vis.set_grid_size(services.grid_map.width, services.grid_map.height)
    # Optional: load ASCII terrain symbol map for textual view
    if vis.has_method("set_terrain_symbol_map") and FileAccess.file_exists("res://data/ascii_terrain.json"):
        var f = FileAccess.open("res://data/ascii_terrain.json", FileAccess.READ)
        if f:
            var txt = f.get_as_text()
            f.close()
            var data = JSON.parse_string(txt)
            if typeof(data) == TYPE_DICTIONARY:
                vis.set_terrain_symbol_map(data)
    interactor.grid_renderer_path = vis.get_path()

    _assign_cover_from_terrain()
    _announce_map_loaded()
    # Listen for movements to update proxies
    services.timespace.action_performed.connect(_on_action_performed)

func _assign_cover_from_terrain() -> void:
    for x in range(services.grid_map.width):
        for y in range(services.grid_map.height):
            var p = Vector2i(x, y)
            var tags: Array = services.grid_map.tile_tags.get(p, [])
            if tags.has("water"):
                services.grid_map.set_movement_cost(p, INF)
            if tags.has("mountain"):
                services.grid_map.set_los_blocker(p, true)
                for d in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]:
                    var t = p + d
                    if services.grid_map.is_in_bounds(t):
                        services.grid_map.set_cover(t, "half")

func _announce_map_loaded() -> void:
    if services == null or services.event_bus == null or services.grid_map == null:
        return
    var counts: Dictionary = {}
    for x in range(services.grid_map.width):
        for y in range(services.grid_map.height):
            var tags: Array = services.grid_map.tile_tags.get(Vector2i(x,y), [])
            for tag in tags:
                var t := String(tag)
                counts[t] = int(counts.get(t, 0)) + 1
    var dom := ""
    var dom_n := -1
    for k in counts.keys():
        var n: int = int(counts[k])
        if n > dom_n:
            dom_n = n; dom = String(k)
    services.event_bus.push({
        "t": "map_loaded",
        "data": {
            "width": services.grid_map.width,
            "height": services.grid_map.height,
            "tag": dom
        }
    })

func _spawn_demo_squads() -> void:
    # Default world state: 1 Player, 1 Enemy, 1 NPC.
    # Use class defaults; only placement/faction are specified.
    var Player = preload("res://scripts/actors/player_actor.gd")
    var Enemy = preload("res://scripts/actors/enemy_actor.gd")
    var Npc = preload("res://scripts/actors/npc_actor.gd")

    # Choose spawn points based on current map size
    var w: int = int(services.grid_map.get("width"))
    var h: int = int(services.grid_map.get("height"))
    var p_pos := Vector2i(1, 1)
    var e_pos := Vector2i(max(2, w - 3), max(2, h - 3))
    var n_pos := Vector2i(w / 2, h / 2)

    var player = Player.new("Player", p_pos, Vector2i.RIGHT, Vector2i.ONE, "player")
    var enemy = Enemy.new("Enemy", e_pos, Vector2i.LEFT, Vector2i.ONE, "enemy")
    var npc = Npc.new("NPC", n_pos, Vector2i.RIGHT, Vector2i.ONE, "npc")

    # Provide runtime so built-in behaviors can hook turn signals
    player.runtime = services
    enemy.runtime = services
    npc.runtime = services

    # Add to scene tree and ASCII group for renderer collection
    add_child(player)
    add_child(enemy)
    add_child(npc)
    player.add_to_group("actors")
    enemy.add_to_group("actors")
    npc.add_to_group("actors")

    # Initiative/AP use class defaults (BaseActor: INIT/ACT = 10) unless overridden later
    services.timespace.add_actor(player, player.INIT, player.ACT, player.grid_pos)
    services.timespace.add_actor(enemy, enemy.INIT, enemy.ACT, enemy.grid_pos)
    services.timespace.add_actor(npc, npc.INIT, npc.ACT, npc.grid_pos)

    # Grant basic abilities for the player hotbar
    services.loadouts.grant(player, "attack_basic")
    services.loadouts.grant(player, "overwatch")
    # Proxies
    _ensure_actor_proxy(player)
    _ensure_actor_proxy(enemy)
    _ensure_actor_proxy(npc)

func _connect_signals() -> void:
    services.timespace.turn_started.connect(_on_turn_started)
    services.timespace.ap_changed.connect(_on_ap_changed)
    services.timespace.turn_ended.connect(_on_turn_ended)
    services.timespace.battle_over.connect(_on_battle_over)
    interactor.tile_clicked.connect(_on_tile_clicked)
    if hud and hud.has_signal("end_turn_requested"):
        hud.end_turn_requested.connect(_on_end_turn_pressed)
    if hotbar and hotbar.has_method("set_attack_handler"):
        hotbar.set_attack_handler(Callable(self, "_enter_attack_mode"))

func _on_turn_started(actor: Object) -> void:
    selected_actor = actor
    attack_mode = false
    _update_hud()
    _paint_board()
    _update_hotbar()
    if interactor and interactor.has_method("set_path_preview_actor"):
        interactor.set_path_preview_actor(actor)
    # Enable auto-resolution when no players remain; otherwise
    # non-player factions still act autonomously.
    _auto_resolve = not _any_players_alive()
    var faction = String(actor.get("faction"))
    if faction != "player" or _auto_resolve:
        _take_auto_turn(actor)

func _on_turn_ended(actor: Object) -> void:
    _clear_selection()

func _on_ap_changed(actor: Object, _old: int, _new: int) -> void:
    if selected_actor == actor:
        _update_hud()
        _paint_board()
        _update_hotbar()
        if interactor and interactor.has_method("set_path_preview_actor"):
            interactor.set_path_preview_actor(actor)

func _on_battle_over(faction) -> void:
    if hud and hud.has_method("show_outcome"):
        var msg = ("Victory" if String(faction) == "enemy" else "Defeat")
        hud.show_outcome(msg)

func _on_end_turn_pressed() -> void:
    services.timespace.end_turn()

func _on_tile_clicked(tile: Vector2i, button: int, _mods: int) -> void:
    if button != MOUSE_BUTTON_LEFT:
        return
    if selected_actor == null:
        return
    var faction = String(selected_actor.get("faction"))
    if faction != "player":
        return
    # Attack if in attack mode and clicking a valid enemy target
    if attack_mode:
        var target = services.grid_map.get_actor_at(tile)
        if target and target != selected_actor:
            var t_fac = String(target.get("faction"))
            # Verify the target is hostile, highlighted as a valid LOS target, and
            # still visible from the actor's current position before executing the attack.
            if t_fac == "enemy" and _is_target(tile):
                var a_pos: Vector2i = services.grid_map.actor_positions.get(selected_actor, null)
                if a_pos != null and services.grid_map.has_line_of_sight(a_pos, tile) and services.timespace.can_perform(selected_actor, "attack", target):
                    services.timespace.perform(selected_actor, "attack", target)
                    attack_mode = false
                    _update_hud()
                    _paint_board()
                    return
    # Otherwise move along a shortest path if within AP budget (step-by-step performs)
    if _is_reachable(tile):
        _step_move_to(selected_actor, tile)
        _update_hud()
        _paint_board()
        if interactor and interactor.has_method("set_path_preview_actor"):
            interactor.set_path_preview_actor(selected_actor)

func _clear_selection() -> void:
    reachable.clear()
    if vis.has_method("clear_all"):
        vis.clear_all()
    if interactor and interactor.has_method("clear_path_preview"):
        interactor.clear_path_preview()

func _ensure_actor_proxy(a) -> void:
    if _gridmap3d == null:
        return
    if _actor_proxies.has(a):
        return
    var color := Color(1,1,1)
    var fac := String(a.get("faction")) if a.has_method("get") else ""
    match fac:
        "player": color = Color(0.4,0.8,1)
        "enemy": color = Color(1,0.4,0.4)
        "npc": color = Color(0.4,1,0.8)
        _:
            pass
    var proxy := preload("res://scripts/integration/actor_3d_proxy.gd").new()
    proxy.setup(a, _gridmap3d, color)
    get_node("../World3D/Actors").add_child(proxy)
    _actor_proxies[a] = proxy
    _last_positions[a] = a.get("grid_pos") if a.has_method("get") else Vector2i.ZERO

func _on_action_performed(actor: Object, id: String, payload) -> void:
    if id == "move" and _actor_proxies.has(actor):
        var prev: Vector2i = _last_positions.get(actor, actor.get("grid_pos"))
        var dst: Vector2i = payload if typeof(payload) == TYPE_VECTOR2I else prev
        var delta := dst - prev
        if actor.has_method("set") and (delta.x != 0 or delta.y != 0):
            var dir := Vector2i(sign(delta.x), sign(delta.y))
            if dir != Vector2i.ZERO:
                actor.set("facing", dir)
        _last_positions[actor] = dst
        var proxy = _actor_proxies[actor]
        if proxy and proxy.has_method("update_from_actor"):
            proxy.update_from_actor()

func _paint_board() -> void:
    if not vis:
        return
    if vis.has_method("clear_all"):
        vis.clear_all()
    if selected_actor == null:
        return
    var pos = services.grid_map.actor_positions.get(selected_actor, null)
    if pos == null:
        return
    # Highlight selected actor, AP-limited reachable tiles
    reachable = _compute_reachable_ap(pos, services.timespace.get_action_points(selected_actor))
    if attack_mode:
        los_targets = _compute_los_targets(pos)
    else:
        los_targets.clear()
    if vis and vis.has_method("set_cell_color"):
        vis.set_cell_color(pos, Color(0.2, 1.0, 0.2, 0.9))
        for t in reachable:
            vis.set_cell_color(t, Color(0.2, 0.6, 1.0, 0.5))
        for tt in los_targets:
            vis.set_cell_color(tt, Color(1.0, 0.2, 0.2, 0.6))
        # Cover visualization: outline covered tiles and label type
        if services.grid_map.cover_types:
            for cpos in services.grid_map.cover_types.keys():
                var ctype: String = services.grid_map.cover_types[cpos]
                var col = (Color(1,1,0,0.8) if ctype == "half" else Color(1,0.5,0,0.9))
                if vis.has_method("set_stroke"):
                    vis.set_stroke(cpos, col, 0.12, 0.04)
    # Damage preview labels for LOS targets
    if vis.has_method("begin_labels") and vis.has_method("push_label") and vis.has_method("end_labels"):
        vis.begin_labels()
        if services.grid_map.cover_types:
            for cpos in services.grid_map.cover_types.keys():
                var ctype: String = services.grid_map.cover_types[cpos]
                vis.push_label(ctype.substr(0,1).to_upper(), cpos, Color(1,1,0), -6)
        # Overwatch status labels on all actors with STS flag set
        for a in services.grid_map.get_all_actors():
            if a and a.get("STS") != null and int(a.STS) & 1 == 1:
                var ap = services.grid_map.actor_positions.get(a, null)
                if ap != null:
                    vis.push_label("OW", ap, Color(0.8,1,1), -18)
        for tt in los_targets:
            var tgt = services.grid_map.get_actor_at(tt)
            if tgt:
                var dmg = 1
                if services.grid_map.has_method("get_cover_modifier"):
                    var pen = int(services.grid_map.get_cover_modifier(pos, tt))
                    if pen <= -40:
                        dmg = 0
                vis.push_label(str(dmg), tt, Color(1,1,1), -12)
        vis.end_labels()

func _compute_reachable_ap(from: Vector2i, ap: int) -> Array[Vector2i]:
    # Dijkstra expansion using movement costs, diagonal multiplier, climb and turn costs.
    var result: Array[Vector2i] = []
    if ap <= 0:
        return result
    var max_cost = float(ap)
    var diagonal = bool(services.grid_map.get("diagonal_movement"))
    var deltas = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN]
    if diagonal:
        deltas += [Vector2i(1,1), Vector2i(-1,-1), Vector2i(1,-1), Vector2i(-1,1)]
    var g: Dictionary = {from: 0.0}
    var parent: Dictionary = {}
    var open: Array[Vector2i] = [from]
    while not open.is_empty():
        var cur_idx = 0
        for i in range(1, open.size()):
            if float(g[open[i]]) < float(g[open[cur_idx]]):
                cur_idx = i
        var cur: Vector2i = open[cur_idx]
        open.remove_at(cur_idx)
        for d in deltas:
            var nxt = cur + d
            if not services.grid_map.is_in_bounds(nxt):
                continue
            if services.grid_map.is_occupied(nxt):
                continue
            var step = services.grid_map.get_movement_cost(nxt)
            if d.x != 0 and d.y != 0:
                step *= 1.4
            var hdiff = services.grid_map.get_height(nxt) - services.grid_map.get_height(cur)
            if hdiff > int(services.grid_map.get("MAX_CLIMB_HEIGHT")):
                continue
            if hdiff > 0:
                step += float(services.grid_map.get("CLIMB_COST")) * float(hdiff)
            var prev = parent.get(cur, null)
            if prev != null:
                var prev_dir = Vector2i(Vector2(cur - prev).normalized().round())
                var next_dir = Vector2i(Vector2(d).normalized().round())
                if next_dir != prev_dir:
                    step += float(services.grid_map.get("TURN_COST"))
            var ncost = float(g[cur]) + step
            if ncost - 1e-6 > max_cost:
                continue
            if g.has(nxt) and float(g[nxt]) <= ncost:
                continue
            g[nxt] = ncost
            parent[nxt] = cur
            result.append(nxt)
            open.append(nxt)
    return result

func _is_reachable(tile: Vector2i) -> bool:
    for t in reachable:
        if t == tile:
            return true
    return false

func _compute_los_targets(from_pos: Vector2i) -> Array[Vector2i]:
    """Return enemy tile positions visible from ``from_pos``.

    The filter uses ``grid_map.has_line_of_sight`` so callers receive only
    targets that can currently be attacked. This guards against stale
    previews when terrain or unit positions change between highlight and
    confirmation clicks.
    """
    var out: Array[Vector2i] = []
    for other in services.grid_map.get_all_actors():
        if other == null or other == selected_actor:
            continue
        var fac = String(other.get("faction"))
        if fac != "enemy":
            continue
        var p = services.grid_map.actor_positions.get(other, null)
        if p == null:
            continue
        if services.grid_map.has_line_of_sight(from_pos, p):
            out.append(p)
    return out

func _is_target(tile: Vector2i) -> bool:
    for t in los_targets:
        if t == tile:
            return true
    return false

func _update_hud() -> void:
    if selected_actor == null:
        return
    var name = String(selected_actor.get("name"))
    if name == "":
        name = "Actor"
    var hp = int(selected_actor.get("HLTH"))
    var ap = services.timespace.get_action_points(selected_actor)
    if hud and hud.has_method("set_status"):
        hud.set_status(name, hp, ap)
    _update_hotbar()

func _update_hotbar() -> void:
    if hotbar and hotbar.has_method("set_actor"):
        hotbar.services_path = services.get_path()
        hotbar.set_actor(selected_actor)

func _enter_attack_mode() -> void:
    attack_mode = true
    _paint_board()

## Move the actor toward `dst` consuming action points for each step.
##
## Path cost mirrors the reachability calculation, considering movement
## cost, diagonal and turn penalties, as well as climb effort. Movement
## stops when AP is exhausted or an intermediate step fails.
func _step_move_to(actor: Object, dst: Vector2i) -> void:
    # Follow a shortest path, performing one-tile moves while deducting AP
    var start = services.grid_map.actor_positions.get(actor, null)
    if start == null:
        return
    var path: Array[Vector2i] = services.grid_map.find_path_for_actor(actor, start, dst)
    if path.is_empty():
        return
    var ap := float(services.timespace.get_action_points(actor))
    for i in range(1, path.size()):
        if ap <= 0.0:
            break
        var step: Vector2i = path[i]
        var prev: Vector2i = path[i - 1]
        var cost: float = services.grid_map.get_movement_cost(step)
        if step.x != prev.x and step.y != prev.y:
            cost *= 1.4
        var hdiff = services.grid_map.get_height(step) - services.grid_map.get_height(prev)
        if hdiff > int(services.grid_map.get("MAX_CLIMB_HEIGHT")):
            break
        if hdiff > 0:
            cost += float(services.grid_map.get("CLIMB_COST")) * float(hdiff)
        if i >= 2:
            var prev_dir = Vector2i(Vector2(path[i-1] - path[i-2]).normalized().round())
            var next_dir = Vector2i(Vector2(step - prev).normalized().round())
            if next_dir != prev_dir:
                cost += float(services.grid_map.get("TURN_COST"))
        if cost - 1e-6 > ap:
            break
        if not services.timespace.can_perform(actor, "move", step):
            break
        if not services.timespace.perform(actor, "move", step):
            break
        ap -= cost

func _take_auto_turn(actor: Object) -> void:
    var a_pos = services.grid_map.actor_positions.get(actor, null)
    if a_pos == null:
        services.timespace.end_turn(); return
    var my_fac := String(actor.get("faction")) if actor.has_method("get") else ""
    var target = _nearest_opponent(a_pos, my_fac)
    if target == null:
        # No opponents: consider overwatch to hold ground
        if services.timespace.can_perform(actor, "overwatch", null):
            services.timespace.perform(actor, "overwatch", null)
        services.timespace.end_turn(); return
    var t_pos = services.grid_map.actor_positions.get(target, null)
    if t_pos == null:
        services.timespace.end_turn(); return
    # Simple flee heuristic at low HP
    var hp := int(actor.get("HLTH")) if actor.has_method("get") else 1
    if hp <= 1:
        var away := _step_away(a_pos, t_pos)
        if away != a_pos and services.timespace.can_perform(actor, "move", away):
            services.timespace.perform(actor, "move", away)
            services.timespace.end_turn(); return
    # Attack if LOS else step toward target; otherwise overwatch.
    if services.grid_map.has_line_of_sight(a_pos, t_pos) and services.timespace.can_perform(actor, "attack", target):
        services.timespace.perform(actor, "attack", target)
    else:
        var path: Array[Vector2i] = services.grid_map.find_path_for_actor(actor, a_pos, t_pos)
        if path.size() >= 2:
            var next_step: Vector2i = path[1]
            if services.timespace.can_perform(actor, "move", next_step):
                services.timespace.perform(actor, "move", next_step)
        elif services.timespace.can_perform(actor, "overwatch", null):
            services.timespace.perform(actor, "overwatch", null)
    services.timespace.end_turn()

func _nearest_opponent(from_pos: Vector2i, my_fac: String):
    var best = null
    var best_d = 1_000_000
    for other in services.grid_map.get_all_actors():
        if other == null:
            continue
        var fac = String(other.get("faction")) if other.has_method("get") else ""
        if fac == my_fac:
            continue
        if int(other.get("HLTH")) <= 0:
            continue
        var p = services.grid_map.actor_positions.get(other, null)
        if p == null:
            continue
        var d = services.grid_map.get_chebyshev_distance(from_pos, p)
        if d < best_d:
            best_d = d
            best = other
    return best

func _any_players_alive() -> bool:
    for a in services.grid_map.get_all_actors():
        if a and String(a.get("faction")) == "player" and int(a.get("HLTH")) > 0:
            return true
    return false

func _step_away(from_pos: Vector2i, threat_pos: Vector2i) -> Vector2i:
    var dx = sign(from_pos.x - threat_pos.x)
    var dy = sign(from_pos.y - threat_pos.y)
    var candidates = [Vector2i(from_pos.x + dx, from_pos.y), Vector2i(from_pos.x, from_pos.y + dy), Vector2i(from_pos.x + dx, from_pos.y + dy)]
    for c in candidates:
        if services.grid_map.is_in_bounds(c) and not services.grid_map.is_occupied(c):
            return c
    return from_pos
