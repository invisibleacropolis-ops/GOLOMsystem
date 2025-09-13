extends RichTextLabel
class_name EventFeedUI

@export var services_path: NodePath
@export var max_lines := 200

var _services

func _ready() -> void:
    bbcode_enabled = true
    autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    scroll_active = true
    scroll_following = true
    _services = get_node_or_null(services_path)
    if _services == null:
        _services = get_tree().get_root().get_node_or_null("/root/VerticalSlice/Runtime")
    var bus = null
    if _services:
        bus = _services.get("event_bus")
    if bus and bus.has_signal("event_pushed"):
        bus.event_pushed.connect(_on_event)
        _log("EventFeed: connected to EventBus")
    else:
        _log("EventFeed: EventBus not found")

func _on_event(evt: Dictionary) -> void:
    var line := _format(evt)
    if line == "":
        return
    append_text(line + "\n")
    if get_line_count() > max_lines:
        clear()
    scroll_to_line(get_line_count())
    _log("EventFeed: t=" + String(evt.get("t","?")) + " | " + line)

func _format(evt: Dictionary) -> String:
    var t := String(evt.get("t",""))
    match t:
        "map_loaded":
            var d := evt.get("data", {})
            var tag := String(d.get("tag","field"))
            return "[center]You enter the %s[/center]" % tag
        "battle_begins":
            return "[center]— Battle begins —[/center]"
        "round_start":
            return "[center]— Round begins —[/center]"
        "round_end":
            return "[center]— Round ends —[/center]"
        "turn_start":
            var a = evt.get("actor"); var name = (a.get("name") if a and a.has_method("get") else "Actor")
            return "▶ [b]%s[/b] begins turn" % String(name)
        "turn_end":
            var a2 = evt.get("actor"); var name2 = (a2.get("name") if a2 and a2.has_method("get") else "Actor")
            return "⏹ [b]%s[/b] ends turn" % String(name2)
        "ap":
            var a3 = evt.get("actor"); var d3: Dictionary = evt.get("data", {})
            var name3 = (a3.get("name") if a3 and a3.has_method("get") else "Actor")
            return "AP [b]%s[/b]: [color=#cccccc]%s → %s[/color]" % [String(name3), str(d3.get("old","?")), str(d3.get("new","?"))]
        "action":
            var a4 = evt.get("actor"); var d4: Dictionary = evt.get("data", {})
            var id := String(d4.get("id","?"))
            var p = d4.get("payload")
            var name4 = (a4.get("name") if a4 and a4.has_method("get") else "Actor")
            if id == "move":
                return "➡️ [b]%s[/b] moves to [code]%s[/code]" % [name4, str(p)]
            elif id == "attack":
                var tn = (p.get("name") if p and p.has_method("get") else str(p))
                return "⚔️ [b]%s[/b] attacks [b]%s[/b]" % [name4, String(tn)]
            elif id == "overwatch":
                return "👁 [b]%s[/b] enters overwatch" % String(name4)
            else:
                return "⋯ [b]%s[/b] uses %s" % [String(name4), id]
        "damage":
            var a5 = evt.get("actor")
            var d5: Dictionary = evt.get("data", {})
            var def = d5.get("defender")
            var amt = int(d5.get("amount", 0))
            var an = (a5.get("name") if a5 and a5.has_method("get") else "Actor")
            var dn = (def.get("name") if def and def.has_method("get") else "Actor")
            if amt <= 0:
                return "🛡 [b]%s[/b]'s attack is foiled by cover around [b]%s[/b]" % [an, dn]
            else:
                return "💥 [b]%s[/b] hits [b]%s[/b] for [b]%d[/b]" % [an, dn, amt]
        _:
            return "[i]%s[/i]" % t

func _log(msg: String) -> void:
    var dbg = get_tree().get_root().get_node_or_null("/root/WorkspaceDebugger")
    if dbg and dbg.has_method("log_info"):
        dbg.log_info("[EventFeed] " + msg)

