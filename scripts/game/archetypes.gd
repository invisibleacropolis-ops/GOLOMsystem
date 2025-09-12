extends Node
class_name Archetypes

## Loads archetype definitions from JSON files and applies
## base Attributes and Loadouts to actors when they spawn.
## Intended to help designers define test actors without
## hardcoding stats into scenes.

var definitions: Dictionary = {}

## Load archetype definitions from a JSON file.
## Expected format:
## {
##   "id": {
##     "attributes": {"HLTH": 10, "PWR": 3},
##     "loadout": ["attack_basic"]
##   }
## }
func load_from_file(path: String) -> void:
    definitions.clear()
    if not FileAccess.file_exists(path):
        return
    var f = FileAccess.open(path, FileAccess.READ)
    if f:
        var txt := f.get_as_text()
        f.close()
        var data = JSON.parse_string(txt)
        if typeof(data) == TYPE_DICTIONARY:
            definitions = data

## Apply an archetype definition to an actor.
## Sets base attributes in the Attributes service and grants
## abilities through the Loadouts service.
func apply(actor: Object, id: String, attrs, loads) -> void:
    var def = definitions.get(id, null)
    if typeof(def) != TYPE_DICTIONARY:
        return
    # Apply attributes
    if attrs and def.has("attributes"):
        var adef: Dictionary = def.attributes
        for key in adef.keys():
            var value = adef[key]
            if actor.has_method("set"):
                actor.set(key, value)
            attrs.set_base(actor, key, value)
    # Apply loadout abilities
    if loads and def.has("loadout"):
        var abilities: Array = def.loadout
        for ability_id in abilities:
            loads.grant(actor, ability_id)
