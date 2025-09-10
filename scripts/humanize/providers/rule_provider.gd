extends HumanizerProvider

## Rule-based provider for deterministic humanized lines.
## Future: parameterize tone/style and support localization.

var _rng := RandomNumberGenerator.new()

func humanize_event(evt: Dictionary, services: Node) -> String:
    var t := String(evt.get("t",""))
    match t:
        "map_loaded":
            var d: Dictionary = evt.get("data", {})
            var tag := String(d.get("tag", ""))
            var phrase := _terrain_phrase(tag)
            if phrase == "":
                phrase = "the field"
            return _center("You enter " + phrase.replace("across ", "a ").replace("along ", "a ").replace("down ", "a ").replace("through ", "the ").replace("over ", "the "))
        "battle_begins":
            return _center("— Battle begins —")
        "round_start":
            return _center("— Round begins —")
        "round_end":
            return _center("— Round ends —")
        "turn_start":
            return "▶ %s begins turn" % _fmt_actor(evt.get("actor"))
        "turn_end":
            return "⏹ %s ends turn" % _fmt_actor(evt.get("actor"))
        "ap":
            var d: Dictionary = evt.get("data", {})
            return "AP %s: [color=#cccccc]%s → %s[/color]" % [_fmt_actor(evt.get("actor")), str(d.get("old","?")), str(d.get("new","?"))]
        "action":
            return _humanize_action(evt)
        "damage":
            return _humanize_damage(evt)
        "status_on":
            return "✨ %s gains [i]%s[/i]" % [_fmt_actor(evt.get("actor")), String(evt.get("data",{}).get("status","?"))]
        "status_off":
            return "… %s loses [i]%s[/i]" % [_fmt_actor(evt.get("actor")), String(evt.get("data",{}).get("status","?"))]
        "reaction":
            return "⚡ %s reaction" % _fmt_actor(evt.get("actor"))
        "battle_over":
            var fac = String(evt.get("data", {}).get("faction",""))
            var text = ("Victory" if fac == "enemy" else ("Defeat" if fac != "" else "Battle Over"))
            return _center(text)
        _:
            return ""

func humanize_move_summary(actor: Object, steps: int, dest: Vector2i, tags: Dictionary, services: Node) -> String:
    var verb := "moves"
    if steps <= 1:
        verb = _pick(["steps", "shifts", "edges"], actor)
    elif steps <= 3:
        verb = _pick(["hurries", "advances", "makes ground"], actor)
    elif steps <= 8:
        verb = _pick(["rushes", "dashes", "sprints"], actor)
    else:
        verb = _pick(["charges", "races", "bolts"], actor)
    var terrain := _terrain_phrase(_dominant_tag(tags))
    var loc := "to [code]%s[/code]" % str(dest)
    var tail := (" " + terrain) if terrain != "" else ""
    return "➡️ %s %s %s%s" % [_fmt_actor(actor), verb, loc, tail]

func _humanize_action(evt: Dictionary) -> String:
    var a = evt.get("actor")
    var d: Dictionary = evt.get("data", {})
    var id := String(d.get("id","?"))
    var payload = d.get("payload")
    match id:
        "move":
            return "➡️ %s moves to [code]%s[/code]" % [_fmt_actor(a), str(payload)]
        "attack":
            return "⚔️ %s attacks %s" % [_fmt_actor(a), _fmt_actor(payload)]
        "overwatch":
            return "👁 %s enters overwatch" % _fmt_actor(a)
        _:
            return "⋯ %s uses [b]%s[/b] %s" % [_fmt_actor(a), id, ("with " + str(payload) if payload != null else "")]

func _humanize_damage(evt: Dictionary) -> String:
    var a = evt.get("actor")
    var d: Dictionary = evt.get("data", {})
    var def = d.get("defender")
    var amt = int(d.get("amount", 0))
    if amt <= 0:
        return "🛡 %s's attack is foiled by cover around %s" % [_fmt_actor(a), _fmt_actor(def)]
    var verb := _pick(["strikes", "lashes out at", "smashes", "pierces", "cuts"], a)
    var weapon := _weapon_name_for(a)
    var weapon_text := (" with [i]%s[/i]" % weapon) if weapon != "" else ""
    return "💥 %s %s %s%s for [b]%d[/b]" % [_fmt_actor(a), verb, _fmt_actor(def), weapon_text, amt]

func _fmt_actor(node) -> String:
    if node == null:
        return "?"
    var name := "Actor"
    var fac := ""
    if node is Object:
        name = String(node.get("name")) if node.has_method("get") else str(node)
        fac = String(node.get("faction")) if node.has_method("get") else ""
    var col := _faction_color(fac)
    return "[color=%s][b]%s[/b][/color]" % [col, name]

func _faction_color(fac: String) -> String:
    match fac:
        "player": return "#66ccff"
        "enemy": return "#ff6666"
        "npc": return "#66ffcc"
        _: return "#dddddd"

func _dominant_tag(tags: Dictionary) -> String:
    var best := ""; var best_n := -1
    for k in tags.keys():
        var n := int(tags[k])
        if n > best_n: best_n = n; best = String(k)
    return best

func _terrain_phrase(tag: String) -> String:
    match tag:
        "grass", "tilegrass": return "across the grassy field"
        "dirt", "tiledirt": return "along the dusty path"
        "road", "paved": return "down the road"
        "water", "watergrass", "waterdirt": return "through the shallows"
        "hill": return "over the rising ground"
        "mountain", "cliff": return "over the rocky ground"
        _: return ""

func _weapon_name_for(a) -> String:
    if a and a.has_method("get"):
        var w = a.get("weapon_name")
        if w != null and String(w) != "":
            return String(w)
    return ""

func _pick(arr: Array, salt) -> String:
    _rng.seed = int((salt.get_instance_id() if salt is Object else 0)) * 1109 + Time.get_ticks_msec()
    return String(arr[_rng.randi_range(0, arr.size() - 1)])

func _center(text: String) -> String:
    return "[center]" + text + "[/center]"
