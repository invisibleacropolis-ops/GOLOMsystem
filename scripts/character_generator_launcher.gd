extends Node

const CHARACTER_CREATOR_SCENE := preload("res://scripts/character_creation/character_creator.gd")
const CHARACTER_CREATION_DATA_SCENE := preload("res://scripts/character_creation/character_creation_data.gd")
const CHARACTER_CREATION_GUI_SCENE := preload("res://scenes/ui/CharacterCreationGUI.tscn")

var _character_creator_instance: Node
var _character_creation_data_instance: Node
var _character_creation_gui_instance: Control

func _ready() -> void:
    _init_character_creation()

func _init_character_creation() -> void:
    _character_creation_data_instance = CHARACTER_CREATION_DATA_SCENE.new()
    add_child(_character_creation_data_instance)

    _character_creation_gui_instance = CHARACTER_CREATION_GUI_SCENE.instantiate()
    add_child(_character_creation_gui_instance)

    _character_creator_instance = CHARACTER_CREATOR_SCENE.new()
    _character_creator_instance.character_creation_data_path = _character_creation_data_instance.get_path()
    _character_creator_instance.character_creation_gui_path = _character_creation_gui_instance.get_path()
    _character_creator_instance.character_creation_finished.connect(_on_character_creation_finished)
    add_child(_character_creator_instance)

    _character_creator_instance.start_character_creation()

func _on_character_creation_finished(character_profile: Resource) -> void:
    print("Character creation finished for: " + character_profile.character_name)
    print("Attributes: " + str(character_profile.attributes))
    print("Skills: " + str(character_profile.skills))
    print("Powers: " + str(character_profile.powers))

    # Optionally, free the nodes to clean up the scene
    _character_creation_gui_instance.queue_free()
    _character_creation_data_instance.queue_free()
    _character_creator_instance.queue_free()

    print("Character Generator session ended. You can close the window.")
