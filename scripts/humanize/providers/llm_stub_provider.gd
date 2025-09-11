extends "res://scripts/humanize/providers/base_provider.gd"

## LLM stub provider: logs driver prompts, returns simple text.
## Replace this with a real local model integration later.

const LOG_PATH := "user://humanizer_prompts.log"

func humanize_event(evt: Dictionary, services: Node) -> String:
    var prompt := _build_prompt(evt, services)
    _append_log(prompt)
    # Deterministic, mildly embellished output for testing.
    var t := String(evt.get("t",""))
    if t == "damage":
        var a = evt.get("actor"); var d = evt.get("data", {})
        var def = d.get("defender"); var amt = int(d.get("amount",0))
        if amt > 0:
            return "💥 %s delivers a heavy blow to %s for [b]%d[/b]" % [_fmt_actor(a), _fmt_actor(def), amt]
        else:
            return "🛡 %s's strike glances off cover near %s" % [_fmt_actor(a), _fmt_actor(def)]
    if t == "action":
        var id := String(evt.get("data",{}).get("id","?"))
        if id == "move":
            return "➡️ %s advances" % _fmt_actor(evt.get("actor"))
    return ""

func humanize_move_summary(actor: Object, steps: int, dest: Vector2i, tags: Dictionary, services: Node) -> String:
    var p := {
        "type": "move_summary",
        "actor": _actor_export(actor),
        "steps": steps,
        "dest": [dest.x, dest.y],
        "tags": tags,
    }
    _append_log(p)
    var terrain := (" over %s" % String(tags.keys()[0])) if not tags.is_empty() else ""
    return "➡️ %s moves%s to [code]%s[/code]" % [_fmt_actor(actor), terrain, str(dest)]

func _build_prompt(evt: Dictionary, services: Node) -> Dictionary:
    var out := {
        "type": String(evt.get("t","event")),
        "actor": _actor_export(evt.get("actor")),
        "data": evt.get("data", {}),
    }
    return out

func _append_log(obj) -> void:
    var f = FileAccess.open(LOG_PATH, FileAccess.READ_WRITE)
    if f:
        f.seek_end()
        f.store_line(JSON.stringify(obj))
        f.close()

func _fmt_actor(node) -> String:
    if node == null: return "?"
    var name := String(node.get("name")) if node is Object and node.has_method("get") else str(node)
    return "[b]%s[/b]" % name

func _actor_export(a) -> Dictionary:
    if a == null: return {}
    return {
        "name": String(a.get("name")) if a.has_method("get") else str(a),
        "faction": String(a.get("faction")) if a.has_method("get") else "",
    }
