# Character Creation Module Manual

`character_creator.gd` and `character_creation_data.gd` together provide the functionality for creating new player characters, including name input, attribute distribution, and selection of skills and powers.

## Responsibilities

-   **`character_creator.gd`**:
    -   Manages the flow of the character creation process through different states (name input, attribute distribution, skill selection, power selection, confirmation).
    -   Interacts with `AsciiUIManager` to display prompts, menus, and receive user input.
    -   Handles user input for each creation step.
    -   Validates input and transitions between creation states.
    -   Collects all chosen character data.
-   **`character_creation_data.gd`**:
    -   Loads and provides access to predefined skill and power data from JSON files (`skills.json`, `powers.json`).
    -   Acts as a data repository for character creation options.

## Core Concepts and API Details

The Character Creation module guides the player through the process of defining their new character, ensuring all necessary attributes, skills, and powers are selected before the character is finalized.

### Class: `CharacterCreator` (inherits from `Node`)

This is the main class orchestrating the character creation process.

#### Members

*   **`_current_state`** (`CreationState`): An enum representing the current step in the character creation flow (e.g., `NAME_INPUT`, `ATTRIBUTE_DISTRIBUTION`).
*   **`_character_name`** (`String`): Stores the name entered by the player.
*   **`_attribute_points_remaining`** (`int`): The number of points the player has left to distribute among attributes.
*   **`_character_attributes`** (`Dictionary`): Stores the chosen values for each attribute (e.g., `{"PWR": 3, "SPD": 2}`).
*   **`_selected_skills`** (`Array[String]`): A list of IDs of skills chosen by the player.
*   **`_selected_powers`** (`Array[String]`): A list of IDs of powers chosen by the player.

#### Methods

*   **`start_character_creation() -> void`**
    Initializes the character creation process, setting the initial state to name input and prompting the user.
*   **`_process_input(command: String) -> void`**
    Internal method called by `AsciiUIManager` when a command is entered. It dispatches the command to the appropriate handler based on `_current_state`.
*   **`_handle_name_input(command: String) -> void`**
    Handles input for the character name, validates it, and transitions to attribute distribution.
*   **`_display_attribute_distribution() -> void`**
    Displays the current attribute values and remaining points, prompting the user to distribute points.
*   **`_handle_attribute_distribution(command: String) -> void`**
    Handles input for attribute point allocation, allowing navigation and modification of attribute values.
*   **`_display_skill_selection() -> void`**
    Displays the list of available skills and the player's current selections.
*   **`_handle_skill_selection(command: String) -> void`**
    Handles input for skill selection, allowing toggling of skills and progression to power selection.
*   **`_display_power_selection() -> void`**
    Displays the list of available powers and the player's current selections.
*   **`_handle_power_selection(command: String) -> void`**
    Handles input for power selection, allowing toggling of powers and progression to confirmation.
*   **`_display_confirmation() -> void`**
    Displays a summary of the chosen character details and prompts for final confirmation or revision.
*   **`_handle_confirmation(command: String) -> void`**
    Handles the final confirmation, creating the character or allowing the user to return to previous steps.

### Class: `CharacterCreationData` (inherits from `Node`)

This class is responsible for loading and providing access to character creation data.

#### Members

*   **`skills_data`** (`Dictionary`): Stores all loaded skill definitions.
*   **`powers_data`** (`Dictionary`): Stores all loaded power definitions.

#### Methods

*   **`load_skills_data() -> void`**
    Loads skill definitions from `res://data/skills.json`.
*   **`load_powers_data() -> void`**
    Loads power definitions from `res://data/powers.json`.
*   **`get_skill_data(skill_id: String) -> Dictionary`**
    Retrieves the data for a specific skill by its ID.
*   **`get_all_skills() -> Dictionary`**
    Returns all loaded skill data.
*   **`get_power_data(power_id: String) -> Dictionary`**
    Retrieves the data for a specific power by its ID.
*   **`get_all_powers() -> Dictionary`**
    Returns all loaded power data.

## Usage Pattern

To initiate the character creation process, ensure `CharacterCreator` and `CharacterCreationData` are added to the scene tree (e.g., in `root.gd` for headless mode) and `CharacterCreator.start_character_creation()` is called.

```gdscript
# In root.gd (example for headless mode)
var character_creation_data_instance = preload("res://scripts/character_creation/character_creation_data.gd").new()
add_child(character_creation_data_instance)

var character_creator_instance = preload("res://scripts/character_creation/character_creator.gd").new()
character_creator_instance.ascii_ui_manager_path = _ascii_ui_manager.get_path()
character_creator_instance.character_creation_data_path = character_creation_data_instance.get_path()
add_child(character_creator_instance)

_ascii_ui_manager.command_entered.connect(character_creator_instance._on_command_entered)

character_creator_instance.start_character_creation()
```

## Integration Notes

-   **`AsciiUIManager` Dependency:** The `CharacterCreator` relies heavily on `AsciiUIManager` for all user interaction. Ensure `AsciiUIManager` is properly set up and its `command_entered` signal is connected to `CharacterCreator._on_command_entered`.
-   **Data-Driven Skills and Powers:** Skill and power definitions are externalized in `skills.json` and `powers.json`, allowing for easy modification and expansion without code changes.
-   **Character Finalization:** Upon confirmation, the `_handle_confirmation` method is the point where the finalized character data (name, attributes, selected skills, selected powers) should be used to instantiate a `PlayerActor` or save the character to a persistent storage.

## Testing

Testing for the Character Creation module would involve simulating user input sequences and verifying that:

-   The state transitions occur correctly.
-   Attribute points are distributed and validated properly.
-   Skills and powers are selected/deselected as expected.
-   The final character summary is accurate.

Example (conceptual, would require a test runner to simulate stdin):

```gdscript
# This is conceptual and would require a test harness to simulate stdin input
# and capture stdout output for verification.

var creator = CharacterCreator.new()
var ui_manager = AsciiUIManager.new() # Mock or actual instance
var data_loader = CharacterCreationData.new() # Mock or actual instance

creator.ascii_ui_manager_path = ui_manager.get_path()
creator.character_creation_data_path = data_loader.get_path()

creator.start_character_creation()

# Simulate name input
ui_manager._command_input_string = "HeroName"
creator._process_input("enter")

# Simulate attribute distribution (e.g., increase PWR by 5)
creator._process_input("d") # PWR +1
creator._process_input("d") # PWR +1
creator._process_input("d") # PWR +1
creator._process_input("d") # PWR +1
creator._process_input("d") # PWR +1
# ... distribute remaining points ...
creator._process_input("enter") # Confirm attributes

# Simulate skill selection
creator._process_input("enter") # Select first skill
creator._process_input("s") # Move to next skill
creator._process_input("enter") # Select second skill
creator._process_input("f") # Finish skills

# Simulate power selection
creator._process_input("enter") # Select first power
creator._process_input("f") # Finish powers

# Simulate confirmation
creator._process_input("y") # Confirm character

# Assertions would go here to check the final character data
# and that the game would proceed as expected.
```
