extends Node

var active_character_profile: CharacterProfile = null

func _ready() -> void:
    # Attempt to connect to CharacterCreator's signal if it's in the scene tree
    # This assumes CharacterCreator is a direct child of the root or a known path.
    # In a real game, consider a more robust signal connection strategy.
    var character_creator_node = get_tree().get_first_node_in_group("character_creator_group") # Assuming CharacterCreator is in this group
    if character_creator_node:
        if character_creator_node.has_signal("character_creation_finished"):
            character_creator_node.character_creation_finished.connect(_on_character_creator_finished)
            print("CharacterManager: Connected to CharacterCreator signal.")
        else:
            push_error("CharacterManager: CharacterCreator node found but does not have 'character_creation_finished' signal.")
    else:
        push_error("CharacterManager: CharacterCreator node not found in group 'character_creator_group'.")

func _on_character_creator_finished(profile: CharacterProfile) -> void:
    save_character_profile(profile)
    active_character_profile = profile
    print("CharacterManager: Received character_creation_finished signal. Character saved and set as active.")

func save_character_profile(profile: CharacterProfile) -> bool:
    var file_path = "user://saves/" + profile.character_name.to_lower().replace(" ", "_") + ".tres"
    var error = ResourceSaver.save(profile, file_path)
    if error != OK:
        push_error("CharacterManager: Failed to save character profile to ", file_path, ": ", error)
        return false
    else:
        print("CharacterManager: Character profile saved to: ", file_path)
        return true

func load_character_profile(char_name: String) -> CharacterProfile:
    var file_path = "user://saves/" + char_name.to_lower().replace(" ", "_") + ".tres"
    if FileAccess.file_exists(file_path):
        var loaded_profile = load(file_path)
        if loaded_profile is CharacterProfile:
            active_character_profile = loaded_profile
            print("CharacterManager: Successfully loaded character: ", loaded_profile.character_name)
            return loaded_profile
        else:
            push_error("CharacterManager: Loaded resource is not a CharacterProfile: ", file_path)
            return null
    else:
        push_error("CharacterManager: Character profile not found: ", file_path)
        return null

func get_all_saved_character_names() -> Array[String]:
    var names: Array[String] = []
    var dir = DirAccess.open("user://saves/")
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()
        while file_name != "":
            if not dir.current_is_dir() and file_name.ends_with(".tres"):
                var char_name = file_name.replace(".tres", "").replace("_", " ").capitalize()
                names.append(char_name)
            file_name = dir.get_next()
    return names
