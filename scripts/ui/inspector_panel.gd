extends Panel
class_name InspectorPanel

var _actions_cache: Dictionary = {}

@onready var _title: Label = $VBox/Title
@onready var _body: RichTextLabel = $VBox/Body
@onready var _close: Button = $VBox/Close

func _ready() -> void:
    _close.pressed.connect(close)

func open() -> void:
    visible = true

func close() -> void:
    visible = false

func show_ability(id: String) -> void:
    _ensure_actions()
    var e: Dictionary = _actions_cache.get(id, {})
    _title.text = "Ability: %s" % id.capitalize().replace("_", " ")
    var lines := []
    if e.is_empty():
        lines.append("[i]No data found.[/i]")
    else:
        if e.has("tags"): lines.append("Tags: [code]%s[/code]" % str(e.tags))
        if e.has("act_cost"): lines.append("AP Cost: [b]%d[/b]" % int(e.act_cost))
        if e.has("chi_cost"): lines.append("Chi Cost: [b]%d[/b]" % int(e.chi_cost))
        if e.has("cooldown"): lines.append("Cooldown: [b]%d[/b]" % int(e.cooldown))
        if e.has("range"): lines.append("Range: [b]%d[/b]" % int(e.range))
        if e.has("uses_los"): lines.append("Line of Sight: [b]%s[/b]" % ("Yes" if bool(e.uses_los) else "No"))
        if e.has("effects"): lines.append("Effects: [code]%s[/code]" % str(e.effects))
        if e.has("damage_amount"): lines.append("Damage: [b]%d[/b]" % int(e.damage_amount))
    _body.text = ""
    for l in lines:
        _body.append_text(l + "\n")
    open()

func show_item(name: String) -> void:
    _title.text = "Item: %s" % name
    _body.text = "[i]No item database yet.[/i]\nName: [b]%s[/b]" % name
    open()

func _ensure_actions() -> void:
    if not _actions_cache.is_empty():
        return
    var path := "res://data/actions.json"
    if not FileAccess.file_exists(path):
        return
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        return
    var txt := f.get_as_text(); f.close()
    var data = JSON.parse_string(txt)
    if typeof(data) == TYPE_DICTIONARY:
        _actions_cache = data

