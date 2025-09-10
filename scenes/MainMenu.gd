extends Control

@export var character_creator_scene: PackedScene

func _ready() -> void:
    _display_main_menu()

func _display_main_menu() -> void:
    # Clear previous messages
    get_node("../AsciiUIManager")._combat_log_messages.clear()
    get_node("../AsciiUIManager")._combat_log_messages.append("--- Main Menu ---")
    get_node("../AsciiUIManager")._combat_log_messages.append("1. New Game")
    get_node("../AsciiUIManager")._combat_log_messages.append("2. Load Game")
    get_node("../AsciiUIManager")._combat_log_messages.append("3. Exit")
    get_node("../AsciiUIManager")._update_ascii_display()
    get_node("../AsciiUIManager").start_command_input()

func _on_command_entered(command: String) -> void:
    match command:
        "1":
            _start_new_game()
        "2":
            _display_load_game_menu()
        "3":
            get_tree().quit()
        _:
            get_node("../AsciiUIManager")._combat_log_messages.append("Invalid command. Please use 1, 2, or 3.")
            get_node("../AsciiUIManager")._update_ascii_display()

func _start_new_game() -> void:
    if character_creator_scene:
        var character_creator_instance = character_creator_scene.instantiate()
        get_tree().get_root().add_child(character_creator_instance)
        # Connect the signal from the newly instantiated CharacterCreator
        if CharacterManager and character_creator_instance.has_signal("character_creation_finished"):
            character_creator_instance.character_creation_finished.connect(CharacterManager._on_character_creator_finished)
            print("MainMenu: Connected CharacterCreator signal to CharacterManager.")
        else:
            push_error("MainMenu: CharacterManager not found or CharacterCreator signal missing.")
        # Hide main menu or transition
        hide()
    else:
        push_error("MainMenu: Character Creator Scene not set in inspector.")

func _display_load_game_menu() -> void:
    get_node("../AsciiUIManager")._combat_log_messages.clear()
    get_node("../AsciiUIManager")._combat_log_messages.append("--- Load Game ---")
    var saved_names = CharacterManager.get_all_saved_character_names()
    if saved_names.empty():
        get_node("../AsciiUIManager")._combat_log_messages.append("No saved characters found.")
        get_node("../AsciiUIManager")._combat_log_messages.append("Press any key to return to Main Menu.")
        get_node("../AsciiUIManager")._update_ascii_display()
        get_node("../AsciiUIManager").start_command_input() # Wait for any input to return
        # Need a way to handle this input to go back to main menu
        # For now, just display and user has to manually go back
    else:
        for i in range(saved_names.size()):
            get_node("../AsciiUIManager")._combat_log_messages.append(str(i + 1) + ". " + saved_names[i])
        get_node("../AsciiUIManager")._combat_log_messages.append("Enter number to load, or 'back' to return.")
        get_node("../AsciiUIManager")._update_ascii_display()
        get_node("../AsciiUIManager").start_command_input()

    # This function needs more robust input handling for selection and 'back'
    # For now, it just displays the list.

func _handle_load_game_input(command: String) -> void:
    if command == "back":
        _display_main_menu()
        return

    var saved_names = CharacterManager.get_all_saved_character_names()
    if command.is_valid_int():
        var index = int(command) - 1
        if index >= 0 and index < saved_names.size():
            var selected_name = saved_names[index]
            var loaded_profile = CharacterManager.load_character_profile(selected_name)
            if loaded_profile:
                get_node("../AsciiUIManager")._combat_log_messages.append("Loaded character: " + loaded_profile.character_name)
                # Here you would transition to the game world with the loaded character
                get_node("../AsciiUIManager")._update_ascii_display()
            else:
                get_node("../AsciiUIManager")._combat_log_messages.append("Failed to load character.")
                get_node("../AsciiUIManager")._update_ascii_display()
        else:
            get_node("../AsciiUIManager")._combat_log_messages.append("Invalid selection.")
            get_node("../AsciiUIManager")._update_ascii_display()
    else:
        get_node("../AsciiUIManager")._combat_log_messages.append("Invalid input. Enter number or 'back'.")
        get_node("../AsciiUIManager")._update_ascii_display()

# This assumes the MainMenu node will receive input via a signal from AsciiUIManager
# Similar to how CharacterCreator receives input.
# You would need to connect AsciiUIManager's command_entered signal to this script's _on_command_entered
