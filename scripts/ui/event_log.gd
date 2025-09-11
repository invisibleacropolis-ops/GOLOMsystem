extends RichTextLabel
class_name EventLogUI

## Enhanced scrolling event reporter that formats game events
## into a human-readable, styled feed.
##
## Future plan (Humanizer drivers):
## - This UI emits driver-friendly payloads to the Humanizer providers.
## - When a local LLM is available, switch provider via HUMANIZER_PROVIDER=llm
##   and implement an LLM provider that returns prose.
## - Keep this module pure UI: clickable highlights and filters will be added
##   here; narrative content remains the Humanizer's responsibility.

@export var services_path: NodePath
@onready var _services = get_node_or_null(services_path)
@export var visible_lines := 10
@export var target_font_size := 14
@export var terminal_font_families := PackedStringArray(["Terminus", "Courier New", "DejaVu Sans Mono", "Noto Sans Mono"])  ## preference order

var _rng := RandomNumberGenerator.new()
var _actor_last_pos: Dictionary = {}           ## rid -> Vector2i
var _move_aggr: Dictionary = {}                ## rid -> {actor, start, last, steps, tags: Dictionary, last_tick: float}
var _last_action: Dictionary = {}              ## rid -> {id: String, payload}
var _action_max_damage: Dictionary = {}        ## id -> int
var _humanizer
const StylePalette = preload("res://scripts/ui/style_palette.gd")
var _palette: StylePalette
var _rendered_lines: Array[String] = []
var _search_query := ""
var _search_line_idx := -1
var _log_config: Node   ## Global verbosity config (autoload)
var _gui_level: int = 1 ## Current GUI verbosity level

const MOVE_FLUSH_MS := 280  ## delay to aggregate bursty move steps into one line

var entries: Array = []
var type_filter: Array = []

func _ready() -> void:
    bbcode_enabled = true
    autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    scroll_active = true
    scroll_following = true
    set_process(true)
    # Visible header to confirm on-screen rendering
    var ts := Time.get_datetime_string_from_system()
    _append_line("[center][b]Event Log[/b][/center]")
    _append_line("[color=#aaaaaa]Initialized: " + ts + "[/color]")
    _append_line("[color=#cccccc]Log online. Reporting round/turn/actions…[/color]")
    _dbg("ready")
    _rng.seed = 1
    _load_action_meta()
    var mode = OS.get_environment("HUMANIZER_PROVIDER")
    var EventHumanizer = preload("res://scripts/humanize/humanizer.gd")
    _humanizer = EventHumanizer.new(_services, mode)
    _apply_terminal_font()
    _apply_viewport_height()
    _palette = StylePalette.load_palette()
    _log_config = get_tree().get_root().get_node_or_null("/root/LogConfig")
    if _log_config:
        _gui_level = _log_config.gui_level
        _log_config.gui_level_changed.connect(func(level): _gui_level = level; _rebuild())

func _notification(what: int) -> void:
    if what == NOTIFICATION_THEME_CHANGED:
        _apply_viewport_height()

func configure_services(path: NodePath) -> void:
    services_path = path
    _services = get_node_or_null(services_path)

## Append a new event and render if it passes filters.
func append_entry(evt: Dictionary) -> void:
    _maybe_flush_before_append(evt)
    entries.append(evt)
    _dbg("append_entry t=" + String(evt.get("t","?")))
    var t = String(evt.get("t",""))
    if t == "action":
        var d: Dictionary = evt.get("data", {})
        var id = String(d.get("id",""))
        var a = evt.get("actor")
        if a is Object:
            _last_action[a.get_instance_id()] = {"id": id, "payload": d.get("payload")}
        if id == "move":
            _accumulate_move(evt)
            return  # defer printing for humanized aggregation
    if _log_config == null or _log_config.event_level(evt) <= _gui_level:
        if _passes_filter(evt):
            _append_formatted(evt)

## Replace the allowed event types. Empty == show all.
func set_type_filter(types: Array) -> void:
    type_filter = types.duplicate()
    _rebuild()

## Clear entries and UI.
func clear_log() -> void:
    entries.clear()
    type_filter.clear()
    text = ""

func _passes_filter(evt: Dictionary) -> bool:
    return type_filter.is_empty() or evt.get("t", "") in type_filter

func _append_formatted(evt: Dictionary) -> void:
    var line := _compute_line(evt)
    _append_line(line)

func _compute_line(evt: Dictionary) -> String:
    var line := ""
    if _humanizer:
        line = _humanizer.humanize_event(evt)
    if line == null or line == "":
        line = _format(evt)
    return line

func _append_line(line: String) -> void:
    append_text(line + "\n")
    _rendered_lines.append(line)
    scroll_to_line(get_line_count())
    _dbg("append_line: " + line)

## Pretty printers -----------------------------------------------------------

func _format(evt: Dictionary) -> String:
    var t := String(evt.get("t", "event"))
    match t:
        "map_loaded":
            var d0: Dictionary = evt.get("data", {})
            var tag0 := String(d0.get("tag",""))
            var phrase0 := _terrain_phrase(tag0)
            if phrase0 == "": phrase0 = "the field"
            return _section_hex("You enter " + phrase0, _hex(_palette.get_color("section", "#e0ffe0")))
        "battle_begins":
            return _section_hex("— Battle begins —", _hex(_palette.get_color("section", "#e0e0ff")))
        "round_start":
            return _section_hex("— Round begins —", _hex(_palette.get_color("section", "#e0e0ff")))
        "round_end":
            return _section_hex("— Round ends —", _hex(_palette.get_color("section", "#e0e0ff")))
        "turn_start":
            return "▶ %s begins turn" % _fmt_actor(evt.get("actor"))
        "turn_end":
            return "⏹ %s ends turn" % _fmt_actor(evt.get("actor"))
        "ap":
            var a = evt.get("actor"); var d = evt.get("data", {})
            return "AP %s: [color=#cccccc]%s → %s[/color]" % [_fmt_actor(a), str(d.get("old","?")), str(d.get("new","?"))]
        "action":
            return _format_action(evt)
        "damage":
            return _format_damage(evt)
        "status_on":
            var st = String(evt.get("data", {}).get("status","?"))
            return "✨ %s gains %s" % [_fmt_actor(evt.get("actor")), _fmt_status(st)]
        "status_off":
            var st2 = String(evt.get("data", {}).get("status","?"))
            return "… %s loses %s" % [_fmt_actor(evt.get("actor")), _fmt_status(st2)]
        "reaction":
            return "⚡ %s reaction" % _fmt_actor(evt.get("actor"))
        "battle_over":
            var fac = String(evt.get("data", {}).get("faction",""))
            var text = ("Victory" if fac == "enemy" else ("Defeat" if fac != "" else "Battle Over"))
            var hex = ("#b3ffb3" if text == "Victory" else "#ff9999")
            return _section_hex(text, hex)
        _:
            return _fallback(evt)

func _format_action(evt: Dictionary) -> String:
    var a = evt.get("actor")
    var data: Dictionary = evt.get("data", {})
    var id = String(data.get("id", "?"))
    var payload = data.get("payload")
    match id:
        "move":
            # When individual moves leak through (e.g., timer flush missed), use a simple verb.
            return "➡️ %s moves to [code]%s[/code]" % [_fmt_actor(a), str(payload)]
        "attack":
            return "⚔️ %s attacks %s" % [_fmt_actor(a), _fmt_actor(payload)]
        "overwatch":
            return "👁 %s enters %s" % [_fmt_actor(a), _fmt_ability("overwatch")]
        _:
            return "⋯ %s uses %s %s" % [_fmt_actor(a), _fmt_ability(id), ("with " + str(payload) if payload != null else "")]

func _format_damage(evt: Dictionary) -> String:
    var a = evt.get("actor")
    var d: Dictionary = evt.get("data", {})
    var def = d.get("defender")
    var amt = int(d.get("amount", 0))
    var rid = (a.get_instance_id() if a is Object else -1)
    var last = _last_action.get(rid, {})
    var act_id = String(last.get("id", "attack_basic"))
    var max_dmg = int(_action_max_damage.get(act_id, max(1, amt)))
    var weapon = _weapon_name_for(a, act_id)
    if amt <= 0:
        return "🛡 %s's attack is foiled by cover around %s" % [_fmt_actor(a), _fmt_actor(def)]
    var verb = _pick(["strikes", "lashes out at", "smashes", "pierces", "cuts"], rid)
    if amt >= max_dmg:
        verb = _pick(["delivers a crushing blow to", "lands a devastating hit on", "strikes true against"], rid)
    var weapon_text = (" with %s" % _fmt_item(weapon)) if weapon != "" else ""
    return "💥 %s %s %s%s for [b]%d[/b]" % [_fmt_actor(a), verb, _fmt_actor(def), weapon_text, amt]

func _fmt_actor(node) -> String:
    if node == null:
        return "?"
    var name = "Actor"
    var fac = ""
    if node is Object:
        name = String(node.get("name")) if node.has_method("get") else str(node)
        fac = String(node.get("faction")) if node.has_method("get") else ""
    var col = _faction_color(fac)
    var rid = (node.get_instance_id() if node is Object else -1)
    return "[url=actor:%s][color=%s][b]%s[/b][/color][/url]" % [str(rid), col, name]

func _faction_color(fac: String) -> String:
    return _palette.faction_color(fac)

func _fmt_item(name: String) -> String:
    if name == null or name == "":
        return ""
    var c: String = _palette.get_color("item", "#ffbf00")
    return "[url=item:%s][color=%s][i]%s[/i][/color][/url]" % [name, c, name]

func _fmt_ability(id: String) -> String:
    if id == null or id == "":
        return ""
    var label := id.capitalize().replace("_", " ")
    var c: String = _palette.get_color("ability", "#c8a2ff")
    return "[url=ability:%s][color=%s][b]%s[/b][/color][/url]" % [id, c, label]

func _fmt_status(name: String) -> String:
    if name == null or name == "":
        return ""
    var c: String = _palette.get_color("status", "#ffd166")
    return "[url=status:%s][color=%s][i]%s[/i][/color][/url]" % [name, c, name]

func _section(text: String, color: Color) -> String:
    var hex = color.to_html(false)
    return "[center][color=%s]%s[/color][/center]" % ["#"+hex, text]

func _section_hex(text: String, hex: String) -> String:
    return "[center][color=%s]%s[/color][/center]" % [hex, text]

func _hex(c) -> String:
    if typeof(c) == TYPE_COLOR:
        return (c as Color).to_html(false)
    var s := String(c)
    if s.begins_with("#"):
        return s
    return "#" + s

func _fallback(evt: Dictionary) -> String:
    var t = evt.get("t","event")
    var actor = evt.get("actor", null)
    var data = evt.get("data", null)
    var parts = []
    parts.append("[i]" + str(t) + "[/i]")
    if actor:
        parts.append(_fmt_actor(actor))
    if data != null:
        parts.append("[code]" + JSON.stringify(data) + "[/code]")
    return " • ".join(parts)

# ------------------ Move aggregation / humanizer ----------------------------

func _accumulate_move(evt: Dictionary) -> void:
    var a = evt.get("actor")
    var d: Dictionary = evt.get("data", {})
    if a == null:
        return
    var rid = a.get_instance_id()
    var dest: Vector2i = d.get("payload", Vector2i.ZERO)
    var ag = _move_aggr.get(rid)
    if ag == null:
        ag = {"actor": a, "start": dest, "last": dest, "steps": 0, "tags": {}, "last_tick": Time.get_ticks_msec()}
        _move_aggr[rid] = ag
    var prev: Vector2i = ag.last
    var step = max(abs(dest.x - prev.x) + abs(dest.y - prev.y), 1)
    ag.steps += step
    ag.last = dest
    ag.last_tick = Time.get_ticks_msec()
    # Track terrain tags along the way
    var tag = _terrain_tag_at(dest)
    if tag != "":
        ag.tags[tag] = int(ag.tags.get(tag, 0)) + 1

func _maybe_flush_before_append(evt: Dictionary) -> void:
    var t = String(evt.get("t",""))
    if t == "action":
        var d: Dictionary = evt.get("data", {})
        if String(d.get("id","")) == "move":
            return  # handled by aggregator
    # For any non-move event, flush pending move for that actor (if present)
    var a = evt.get("actor")
    if a is Object:
        var rid = a.get_instance_id()
        if _move_aggr.has(rid):
            _flush_move_for(rid)

func _process(_delta: float) -> void:
    _flush_stale_moves()

func _flush_stale_moves() -> void:
    var now = Time.get_ticks_msec()
    for rid in Array(_move_aggr.keys()):
        var ag = _move_aggr[rid]
        if now - int(ag.last_tick) >= MOVE_FLUSH_MS:
            _flush_move_for(rid)

func _flush_move_for(rid) -> void:
    var ag = _move_aggr.get(rid)
    if ag == null:
        return
    var line := ""
    if _humanizer:
        line = _humanizer.humanize_move_summary(ag.actor, int(ag.steps), ag.last, ag.tags)
    if line == null or line == "":
        line = _narrate_move(ag)
    _move_aggr.erase(rid)
    _append_line(line)

func _narrate_move(ag: Dictionary) -> String:
    var actor = ag.actor
    var steps: int = int(ag.steps)
    var dest: Vector2i = ag.last
    var tag := _dominant_tag(ag.tags)
    var terrain := _terrain_phrase(tag)
    var verb := "moves"
    if steps <= 1:
        verb = _pick(["steps", "shifts", "edges"], actor.get_instance_id())
    elif steps <= 3:
        verb = _pick(["hurries", "advances", "makes ground"], actor.get_instance_id())
    elif steps <= 8:
        verb = _pick(["rushes", "dashes", "sprints"], actor.get_instance_id())
    else:
        verb = _pick(["charges", "races", "bolts"], actor.get_instance_id())
    var loc := "to [code]%s[/code]" % str(dest)
    var tail := (" " + terrain) if terrain != "" else ""
    return "➡️ %s %s %s%s" % [_fmt_actor(actor), verb, loc, tail]

func _dominant_tag(tags: Dictionary) -> String:
    var best := ""
    var best_n := -1
    for k in tags.keys():
        var n := int(tags[k])
        if n > best_n:
            best_n = n; best = String(k)
    return best

func _terrain_tag_at(p: Vector2i) -> String:
    if _services and _services.grid_map and typeof(_services.grid_map.tile_tags) == TYPE_DICTIONARY:
        var tags = _services.grid_map.tile_tags.get(p, [])
        if tags is Array and tags.size() > 0:
            return String(tags[0])
    return ""

func _terrain_phrase(tag: String) -> String:
    match tag:
        "grass", "tilegrass":
            return "across the grassy field"
        "dirt", "tiledirt":
            return "along the dusty path"
        "road", "paved":
            return "down the road"
        "water", "watergrass", "waterdirt":
            return "through the shallows"
        "hill":
            return "over the rising ground"
        "mountain", "cliff":
            return "over the rocky ground"
        _:
            return ""

func _pick(arr: Array, salt) -> String:
    _rng.seed = int(salt) * 10007 + get_line_count()
    return String(arr[_rng.randi_range(0, arr.size() - 1)])

func _load_action_meta() -> void:
    if not FileAccess.file_exists("res://data/actions.json"):
        return
    var f = FileAccess.open("res://data/actions.json", FileAccess.READ)
    if f == null:
        return
    var txt = f.get_as_text(); f.close()
    var data = JSON.parse_string(txt)
    if typeof(data) != TYPE_DICTIONARY:
        return
    for id in data.keys():
        var e = data[id]
        if typeof(e) == TYPE_DICTIONARY and e.has("damage_amount"):
            _action_max_damage[id] = int(e.damage_amount)

func _weapon_name_for(actor, act_id: String) -> String:
    if actor and actor.has_method("get"):
        var w = String(actor.get("weapon_name")) if actor.get("weapon_name") != null else ""
        if w != "":
            return w
    # Map action to a flavor name
    match act_id:
        "attack_basic":
            return "weapon"
        _:
            return ""

## Repaint from cache (apply filters).
func _rebuild() -> void:
    text = ""
    _rendered_lines.clear()
    for e in entries:
        if (_log_config == null or _log_config.event_level(e) <= _gui_level) and _passes_filter(e):
            var line = _compute_line(e)
            _append_line(line)

## Search API ----------------------------------------------------------------
func perform_search(query: String) -> bool:
    var q = String(query).strip_edges()
    if q == "":
        return false
    var ql = q.to_lower()
    if q != _search_query:
        _search_query = q
        _search_line_idx = -1
    var n = _rendered_lines.size()
    if n == 0:
        return false
    var start = _search_line_idx + 1
    for _pass in range(2):
        for i in range(start, n):
            if String(_rendered_lines[i]).to_lower().find(ql) != -1:
                _search_line_idx = i
                scroll_to_line(i + 1)
                return true
        start = 0
    return false

func _apply_terminal_font() -> void:
    var SystemFont = load("res://addons/godot/fonts/system_font.tres") if false else null  # placeholder
    var sys = SystemFont if SystemFont else SystemFontDefault()
    add_theme_font_override("normal_font", sys)
    add_theme_font_size_override("normal_font_size", target_font_size)

func SystemFontDefault() -> Font:
    var sf = SystemFont.new()
    sf.font_names = terminal_font_families
    return sf

func _apply_viewport_height() -> void:
    var f: Font = get_theme_font("normal_font")
    var size: int = get_theme_font_size("normal_font_size")
    if f == null or size <= 0:
        return
    var one = int(ceil(f.get_height(size)))
    var h = one * max(1, visible_lines)
    var parent_scroll = get_parent()
    if parent_scroll and parent_scroll is ScrollContainer:
        parent_scroll.custom_minimum_size.y = float(h)

func _dbg(msg: String) -> void:
    var dbg = get_tree().get_root().get_node_or_null("/root/WorkspaceDebugger")
    if dbg and dbg.has_method("log_info"):
        dbg.log_info("[EventLog] " + msg)
