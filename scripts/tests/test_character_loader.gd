extends Node

@export var character_name_to_load: String = ""

func _ready() -> void:
    if not character_name_to_load.empty():
        load_character_profile(character_name_to_load)

func load_character_profile(char_name: String) -> void:
    var file_path = "user://saves/" + char_name.to_lower().replace(" ", "_") + ".tres"
    if FileAccess.file_exists(file_path):
        var loaded_profile = load(file_path)
        if loaded_profile is CharacterProfile:
            print("Successfully loaded character: ", loaded_profile.character_name)
            print("Attributes: ", loaded_profile.attributes)
            print("Skills: ", loaded_profile.skills)
            print("Powers: ", loaded_profile.powers)
        else:
            push_error("Loaded resource is not a CharacterProfile: ", file_path)
    else:
        push_error("Character profile not found: ", file_path)
