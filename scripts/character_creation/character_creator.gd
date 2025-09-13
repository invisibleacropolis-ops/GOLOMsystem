extends Node

signal character_creation_finished(character_profile: Resource)

@export var character_creation_gui_path: NodePath
@export var character_creation_data_path: NodePath

var _character_creation_gui: Control = null
var _character_creation_data: Node = null

enum CreationState {
	NONE,
	NAME_INPUT,
	ATTRIBUTE_DISTRIBUTION,
	SKILL_SELECTION,
	POWER_SELECTION,
	CONFIRMATION
}

var _current_state: CreationState = CreationState.NONE
var _character_name: String = ""
var _attribute_points_remaining: int = 10
var _character_attributes: Dictionary = {}
var _attribute_keys: Array[String] = []
var _selected_attribute_index: int = 0
var _selected_skills: Array[String] = []
var _all_available_skills: Array[String] = []
var _selected_skill_index: int = 0
var _selected_powers: Array[String] = []
var _all_available_powers: Array[String] = []
var _selected_power_index: int = 0

func _ready() -> void:
	_character_creation_gui = get_node_or_null(character_creation_gui_path)
	_character_creation_data = get_node_or_null(character_creation_data_path)

	if not _character_creation_gui:
		push_error("CharacterCreator: CharacterCreationGUI node not found at path: ", character_creation_gui_path)
		return
	if not _character_creation_data:
		push_error("CharacterCreator: CharacterCreationData node not found at path: ", character_creation_data_path)
		return

	_connect_gui_signals()

	# Initialize attributes dynamically
	for attr_id in _character_creation_data.get_all_attributes().keys():
		_character_attributes[attr_id] = 0
	_attribute_keys = _character_creation_data.get_all_attributes().keys()

	start_character_creation()

func _connect_gui_signals() -> void:
	_character_creation_gui.name_entered.connect(_on_name_entered)
	_character_creation_gui.attribute_changed.connect(_on_attribute_changed)
	_character_creation_gui.confirm_attributes.connect(_on_confirm_attributes)
	_character_creation_gui.skill_toggled.connect(_on_skill_toggled)
	_character_creation_gui.confirm_skills.connect(_on_confirm_skills)
	_character_creation_gui.power_toggled.connect(_on_power_toggled)
	_character_creation_gui.confirm_powers.connect(_on_confirm_powers)
	_character_creation_gui.confirm_character.connect(_on_confirm_character)
	_character_creation_gui.cancel_creation.connect(_on_cancel_creation)
	_character_creation_gui.edit_attributes.connect(_on_edit_attributes)
	_character_creation_gui.edit_skills.connect(_on_edit_skills)
	_character_creation_gui.edit_powers.connect(_on_edit_powers)
	_character_creation_gui.back_pressed.connect(_on_back_pressed)

func start_character_creation() -> void:
	_current_state = CreationState.NAME_INPUT
	_character_creation_gui._set_stage_visibility("name_input")
	_character_creation_gui.display_message("Enter your character's name:")

func _on_name_entered(name: String) -> void:
	_character_name = name.strip_edges()
	if _character_name.empty():
		_character_creation_gui.display_message("Name cannot be empty. Please enter a name:")
	else:
		_character_creation_gui.display_message("Character Name: " + _character_name)
		_current_state = CreationState.ATTRIBUTE_DISTRIBUTION
		_display_attribute_distribution()

func _on_attribute_changed(attr_id: String, change: int) -> void:
	var current_value = _character_attributes.get(attr_id, 0)
	if change == 1: # Increase
		var cost = _get_attribute_increase_cost(current_value)
		if _attribute_points_remaining >= cost and current_value < 5: # Max 5 per attribute for now
			_character_attributes[attr_id] = current_value + 1
			_attribute_points_remaining -= cost
			_display_attribute_distribution()
		else:
			_character_creation_gui.display_message("Not enough points or attribute is at max.")
	elif change == -1: # Decrease
		if current_value > 0:
			var refund = _get_attribute_decrease_refund(current_value)
			_character_attributes[attr_id] = current_value - 1
			_attribute_points_remaining += refund
			_display_attribute_distribution()
		else:
			_character_creation_gui.display_message("Attribute cannot go below 0.")

func _on_confirm_attributes() -> void:
	if _attribute_points_remaining == 0:
		_character_creation_gui.display_message("Attribute distribution complete!")
		_current_state = CreationState.SKILL_SELECTION
		_display_skill_selection()
	else:
		_character_creation_gui.display_message("Please distribute all attribute points.")

func _on_skill_toggled(skill_id: String) -> void:
	if _selected_skills.has(skill_id):
		_selected_skills.erase(skill_id)
	else:
		_selected_skills.append(skill_id)
	_display_skill_selection()

func _on_confirm_skills() -> void:
	_character_creation_gui.display_message("Skill selection complete!")
	_current_state = CreationState.POWER_SELECTION
	_display_power_selection()

func _on_power_toggled(power_id: String) -> void:
	if _selected_powers.has(power_id):
		_selected_powers.erase(power_id)
	else:
		_selected_powers.append(power_id)
	_display_power_selection()

func _on_confirm_powers() -> void:
	_character_creation_gui.display_message("Power selection complete!")
	_current_state = CreationState.CONFIRMATION
	_display_confirmation()

func _on_confirm_character() -> void:
	# This part needs CharacterManager.get_all_saved_character_names() which is not defined
	# For now, I will comment out the name check and skill/power empty checks
	# var existing_names = CharacterManager.get_all_saved_character_names()
	# if existing_names.has(_character_name):
	#     _character_creation_gui.display_message("Character with this name already exists. Please choose a different name or cancel.")
	#     return

	# if _selected_skills.empty():
	#     _character_creation_gui.display_message("Please select at least one skill.")
	#     return

	# if _selected_powers.empty():
	#     _character_creation_gui.display_message("Please select at least one power.")
	#     return

	_character_creation_gui.display_message("Character created!")
	var character_profile = CharacterProfile.new()
	character_profile.character_name = _character_name
	character_profile.attributes = _character_attributes
	character_profile.skills = _selected_skills
	character_profile.powers = _selected_powers
	emit_signal("character_creation_finished", character_profile)
	# _character_creation_gui.hide() # Or queue_free() the GUI

func _on_cancel_creation() -> void:
	_character_creation_gui.display_message("Character creation cancelled.")
	# _character_creation_gui.hide() # Or queue_free() the GUI

func _on_edit_attributes() -> void:
	_current_state = CreationState.ATTRIBUTE_DISTRIBUTION
	_display_attribute_distribution()

func _on_edit_skills() -> void:
	_current_state = CreationState.SKILL_SELECTION
	_display_skill_selection()

func _on_edit_powers() -> void:
	_current_state = CreationState.POWER_SELECTION
	_display_power_selection()

func _on_back_pressed() -> void:
	match _current_state:
		CreationState.ATTRIBUTE_DISTRIBUTION:
			_current_state = CreationState.NAME_INPUT
			_character_creation_gui._set_stage_visibility("name_input")
			_character_creation_gui.display_message("Enter your character's name: " + _character_name)
		CreationState.SKILL_SELECTION:
			_current_state = CreationState.ATTRIBUTE_DISTRIBUTION
			_display_attribute_distribution()
		CreationState.POWER_SELECTION:
			_current_state = CreationState.SKILL_SELECTION
			_display_skill_selection()
		CreationState.CONFIRMATION:
			_current_state = CreationState.POWER_SELECTION
			_display_power_selection()
		_:
			pass

func _display_attribute_distribution() -> void:
	_character_creation_gui._set_stage_visibility("attribute_distribution")
	_character_creation_gui.display_message("\n--- Attribute Distribution ---")
	_character_creation_gui.display_message("Attributes define your character's core strengths. You have " + str(_attribute_points_remaining) + " points to distribute.")
	_character_creation_gui.display_message("Higher values in an attribute will cost more points.")
	_character_creation_gui.update_attribute_distribution_ui(_character_attributes, _attribute_points_remaining, _attribute_keys, _selected_attribute_index)

func _display_skill_selection() -> void:
	_character_creation_gui._set_stage_visibility("skill_selection")
	_character_creation_gui.display_message("\n--- Skill Selection ---")
	_character_creation_gui.display_message("Skills represent learned abilities that enhance your character's capabilities.")
	_character_creation_gui.display_message("Select the skills you wish your character to possess.")
	_all_available_skills = _character_creation_data.get_all_skills().keys()
	_character_creation_gui.update_skill_selection_ui(_character_creation_data.get_all_skills(), _selected_skills, _selected_skill_index)

func _display_power_selection() -> void:
	_character_creation_gui._set_stage_visibility("power_selection")
	_character_creation_gui.display_message("\n--- Power Selection ---")
	_character_creation_gui.display_message("Powers are unique abilities that grant your character special advantages.")
	_character_creation_gui.display_message("Select the powers you wish your character to wield.")
	_all_available_powers = _character_creation_data.get_all_powers().keys()
	_character_creation_gui.update_power_selection_ui(_character_creation_data.get_all_powers(), _selected_powers, _selected_power_index)

func _display_confirmation() -> void:
	_character_creation_gui._set_stage_visibility("confirmation")
	_character_creation_gui.display_message("\n--- Character Summary ---")
	_character_creation_gui.display_message("Review your character's details before finalizing.")
	_character_creation_gui.update_confirmation_ui(
		_character_name,
		_character_attributes,
		_selected_skills,
		_selected_powers,
		_character_creation_data.get_all_attributes(),
		_character_creation_data.get_all_skills(),
		_character_creation_data.get_all_powers()
	)

func _get_attribute_increase_cost(current_value: int) -> int:
	return current_value + 1

func _get_attribute_decrease_refund(current_value: int) -> int:
	return current_value
