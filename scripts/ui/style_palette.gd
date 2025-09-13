extends RefCounted
class_name StylePalette

var colors := {
    "faction": {
        "player": "#66ccff",
        "enemy": "#ff6666",
        "npc": "#66ffcc",
        "default": "#dddddd"
    },
    "ability": "#c8a2ff",
    "item": "#ffbf00",
    "status": "#ffd166",
    "section": "#e0e0ff"
}

static func load_palette(path: String = "res://data/style_palette.json"):
    var p = preload("res://scripts/ui/style_palette.gd").new()
    if FileAccess.file_exists(path):
        var f = FileAccess.open(path, FileAccess.READ)
        if f:
            var txt = f.get_as_text(); f.close()
            var data = JSON.parse_string(txt)
            if typeof(data) == TYPE_DICTIONARY:
                p.colors = data
    return p

func faction_color(fac: String) -> String:
    var fset = colors.get("faction", {})
    if typeof(fset) == TYPE_DICTIONARY and fset.has(fac):
        return String(fset[fac])
    if typeof(fset) == TYPE_DICTIONARY and fset.has("default"):
        return String(fset.default)
    return "#dddddd"

func get_color(key: String, fallback: String) -> String:
    var v = colors.get(key, null)
    if v == null:
        return fallback
    return String(v)
