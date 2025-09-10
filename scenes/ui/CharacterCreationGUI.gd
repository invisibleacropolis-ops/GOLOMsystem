extends Control

# Signals to communicate with CharacterCreator
signal name_entered(character_name: String)
signal attribute_changed(attribute_id: String, value: int)
signal confirm_attributes()
signal skill_toggled(skill_id: String)
signal confirm_skills()
signal power_toggled(power_id: String)
signal confirm_powers()
signal confirm_character()
signal cancel_creation()
signal edit_attributes()
signal edit_skills()
signal edit_powers()
signal back_pressed()

# Exported NodePaths for UI elements
@export var name_input_stage_path: NodePath
@export var name_line_edit_path: NodePath
@export var confirm_name_button_path: NodePath

@export var attribute_distribution_stage_path: NodePath
@export var points_remaining_label_path: NodePath
@export var attributes_container_path: NodePath
@export var confirm_attributes_button_path: NodePath
@export var back_from_attributes_button_path: NodePath

@export var skill_selection_stage_path: NodePath
@export var skill_list_path: NodePath
@export var skill_description_label_path: NodePath
@export var confirm_skills_button_path: NodePath
@export var back_from_skills_button_path: NodePath

@export var power_selection_stage_path: NodePath
@export var power_list_path: NodePath
@export var power_description_label_path: NodePath
@export var confirm_powers_button_path: NodePath
@export var back_from_powers_button_path: NodePath

@export var confirmation_stage_path: NodePath
@export var name_summary_label_path: NodePath
@export var attributes_summary_label_path: NodePath
@export var skills_summary_label_path: NodePath
@export var powers_summary_label_path: NodePath
@export var confirm_character_button_path: NodePath
@export var cancel_character_button_path: NodePath
@export var edit_attributes_button_path: NodePath
@export var edit_skills_button_path: NodePath
@export var edit_powers_button_path: NodePath

# Internal references to UI nodes
var _name_input_stage: VBoxContainer
var _name_line_edit: LineEdit
var _confirm_name_button: Button

var _attribute_distribution_stage: VBoxContainer
var _points_remaining_label: Label
var _attributes_container: VBoxContainer
var _confirm_attributes_button: Button
var _back_from_attributes_button: Button

var _skill_selection_stage: VBoxContainer
var _skill_list: ItemList
var _skill_description_label: Label
var _confirm_skills_button: Button
var _back_from_skills_button: Button

var _power_selection_stage: VBoxContainer
var _power_list: ItemList
var _power_description_label: Label
var _confirm_powers_button: Button
var _back_from_powers_button: Button

var _confirmation_stage: VBoxContainer
var _name_summary_label: Label
var _attributes_summary_label: Label
var _skills_summary_label: Label
var _powers_summary_label: Label
var _confirm_character_button: Button
var _cancel_character_button: Button
var _edit_attributes_button: Button
var _edit_skills_button: Button
var _edit_powers_button: Button

var _current_stage_node: Control = null

func _ready() -> void:
    _get_node_references()
    _connect_signals()
    _set_stage_visibility("name_input")

func _get_node_references() -> void:
    _name_input_stage = get_node(name_input_stage_path)
    _name_line_edit = get_node(name_line_edit_path)
    _confirm_name_button = get_node(confirm_name_button_path)

    _attribute_distribution_stage = get_node(attribute_distribution_stage_path)
    _points_remaining_label = get_node(points_remaining_label_path)
    _attributes_container = get_node(attributes_container_path)
    _confirm_attributes_button = get_node(confirm_attributes_button_path)
    _back_from_attributes_button = get_node(back_from_attributes_button_path)

    _skill_selection_stage = get_node(skill_selection_stage_path)
    _skill_list = get_node(skill_list_path)
    _skill_description_label = get_node(skill_description_label_path)
    _confirm_skills_button = get_node(confirm_skills_button_path)
    _back_from_skills_button = get_node(back_from_skills_button_path)

    _power_selection_stage = get_node(power_selection_stage_path)
    _power_list = get_node(power_list_path)
    _power_description_label = get_node(power_description_label_path)
    _confirm_powers_button = get_node(confirm_powers_button_path)
    _back_from_powers_button = get_node(back_from_powers_button_path)

    _confirmation_stage = get_node(confirmation_stage_path)
    _name_summary_label = get_node(name_summary_label_path)
    _attributes_summary_label = get_node(attributes_summary_label_path)
    _skills_summary_label = get_node(skills_summary_label_path)
    _powers_summary_label = get_node(powers_summary_label_path)
    _confirm_character_button = get_node(confirm_character_button_path)
    _cancel_character_button = get_node(cancel_character_button_path)
    _edit_attributes_button = get_node(edit_attributes_button_path)
    _edit_skills_button = get_node(edit_skills_button_path)
    _edit_powers_button = get_node(edit_powers_button_path)

func _connect_signals() -> void:
    _confirm_name_button.pressed.connect(_on_confirm_name_button_pressed)
    _name_line_edit.text_submitted.connect(_on_confirm_name_button_pressed)

    _confirm_attributes_button.pressed.connect(func(): emit_signal("confirm_attributes"))
    _back_from_attributes_button.pressed.connect(func(): emit_signal("back_pressed"))

    _skill_list.item_selected.connect(_on_skill_list_item_selected)
    _skill_list.item_activated.connect(_on_skill_list_item_activated)
    _confirm_skills_button.pressed.connect(func(): emit_signal("confirm_skills"))
    _back_from_skills_button.pressed.connect(func(): emit_signal("back_pressed"))

    _power_list.item_selected.connect(_on_power_list_item_selected)
    _power_list.item_activated.connect(_on_power_list_item_activated)
    _confirm_powers_button.pressed.connect(func(): emit_signal("confirm_powers"))
    _back_from_powers_button.pressed.connect(func(): emit_signal("back_pressed"))

    _confirm_character_button.pressed.connect(func(): emit_signal("confirm_character"))
    _cancel_character_button.pressed.connect(func(): emit_signal("cancel_creation"))
    _edit_attributes_button.pressed.connect(func(): emit_signal("edit_attributes"))
    _edit_skills_button.pressed.connect(func(): emit_signal("edit_skills"))
    _edit_powers_button.pressed.connect(func(): emit_signal("edit_powers"))

func _set_stage_visibility(stage_name: String) -> void:
    var next_stage_node: Control = null
    match stage_name:
        "name_input":
            next_stage_node = _name_input_stage
        "attribute_distribution":
            next_stage_node = _attribute_distribution_stage
        "skill_selection":
            next_stage_node = _skill_selection_stage
        "power_selection":
            next_stage_node = _power_selection_stage
        "confirmation":
            next_stage_node = _confirmation_stage

    _transition_to_stage(next_stage_node)

func _transition_to_stage(next_stage_node: Control) -> void:
    if _current_stage_node == next_stage_node: # No transition needed if already on this stage
        return

    if _current_stage_node:
        var tween_out = create_tween()
        tween_out.tween_property(_current_stage_node, "modulate", Color(1, 1, 1, 0), 0.3)
        tween_out.tween_callback(func(): _current_stage_node.visible = false)
        tween_out.tween_callback(func(): _show_next_stage(next_stage_node))
    else:
        _show_next_stage(next_stage_node)

func _show_next_stage(next_stage_node: Control) -> void:
    next_stage_node.visible = true
    next_stage_node.modulate = Color(1, 1, 1, 0) # Start invisible
    var tween_in = create_tween()
    tween_in.tween_property(next_stage_node, "modulate", Color(1, 1, 1, 1), 0.3)
    _current_stage_node = next_stage_node

    if next_stage_node == _name_input_stage:
        _name_line_edit.grab_focus()

func _on_confirm_name_button_pressed() -> void:
    emit_signal("name_entered", _name_line_edit.text)

# Placeholder for attribute UI generation and interaction
func update_attribute_distribution_ui(attributes: Dictionary, points_remaining: int, attribute_keys: Array, selected_index: int) -> void:
    _points_remaining_label.text = "Points Remaining: " + str(points_remaining)
    for child in _attributes_container.get_children():
        child.queue_free() # Clear existing attribute controls

    for i in range(attribute_keys.size()):
        var attr_id = attribute_keys[i]
        var attr_value = attributes.get(attr_id, 0)

        var hbox = HBoxContainer.new()
        hbox.alignment = HBoxContainer.ALIGNMENT_CENTER
        hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

        var attr_name_label = Label.new()
        attr_name_label.text = attr_id + ":"
        attr_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        attr_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        hbox.add_child(attr_name_label)

        var decrease_button = Button.new()
        decrease_button.text = "-"
        decrease_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        decrease_button.pressed.connect(func(): emit_signal("attribute_changed", attr_id, -1))
        hbox.add_child(decrease_button)

        var attr_value_label = Label.new()
        attr_value_label.text = str(attr_value)
        attr_value_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        attr_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        attr_value_label.custom_minimum_size = Vector2(30, 0) # Ensure enough space for value
        hbox.add_child(attr_value_label)

        var increase_button = Button.new()
        increase_button.text = "+"
        increase_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
        increase_button.pressed.connect(func(): emit_signal("attribute_changed", attr_id, 1))
        hbox.add_child(increase_button)

        _attributes_container.add_child(hbox)

        if i == selected_index:
            attr_name_label.add_theme_color_override("font_color", Color.YELLOW) # Highlight selected

func update_skill_selection_ui(all_skills: Dictionary, selected_skills: Array, selected_index: int) -> void:
    _skill_list.clear()
    var current_skill_id = ""
    if all_skills.keys().size() > 0:
        current_skill_id = all_skills.keys()[selected_index]

    for skill_id in all_skills.keys():
        var skill_data = all_skills[skill_id]
        var text = skill_data.name
        var item_index = _skill_list.add_item(text)
        _skill_list.set_item_metadata(item_index, skill_id)
        _skill_list.set_item_selectable(item_index, true)
        _skill_list.set_item_checked(item_index, selected_skills.has(skill_id))
        _skill_list.set_item_checkable(item_index, true)

        if skill_id == current_skill_id:
            _skill_list.select(item_index)
            _skill_description_label.text = "Description: " + skill_data.description
        
func _on_skill_list_item_selected(index: int) -> void:
    var skill_id = _skill_list.get_item_metadata(index)
    # This signal is for selection, not activation (toggle)
    # We update description here
    # Need reference to data, will be passed from CharacterCreator
    # For now, just update description if data is available
    var skill_data = {"description": "(Description not loaded yet)"} # Placeholder
    if skill_id:
        # In a real scenario, you'd get this from CharacterCreationData
        # For now, we'll assume CharacterCreator passes it or this GUI has access
        pass # Will be handled by CharacterCreator passing data
    _skill_description_label.text = "Description: " + skill_data.description

func _on_skill_list_item_activated(index: int) -> void:
    var skill_id = _skill_list.get_item_metadata(index)
    emit_signal("skill_toggled", skill_id)

func update_power_selection_ui(all_powers: Dictionary, selected_powers: Array, selected_index: int) -> void:
    _power_list.clear()
    var current_power_id = ""
    if all_powers.keys().size() > 0:
        current_power_id = all_powers.keys()[selected_index]

    for power_id in all_powers.keys():
        var power_data = all_powers[power_id]
        var text = power_data.name
        var item_index = _power_list.add_item(text)
        _power_list.set_item_metadata(item_index, power_id)
        _power_list.set_item_selectable(item_index, true)
        _power_list.set_item_checked(item_index, selected_powers.has(power_id))
        _power_list.set_item_checkable(item_index, true)

        if power_id == current_power_id:
            _power_list.select(item_index)
            _power_description_label.text = "Description: " + power_data.description

func _on_power_list_item_selected(index: int) -> void:
    var power_id = _power_list.get_item_metadata(index)
    # This signal is for selection, not activation (toggle)
    # We update description here
    # Need reference to data, will be passed from CharacterCreator
    # For now, just update description if data is available
    var power_data = {"description": "(Description not loaded yet)"} # Placeholder
    if power_id:
        # In a real scenario, you'd get this from CharacterCreationData
        # For now, we'll assume CharacterCreator passes it or this GUI has access
        pass # Will be handled by CharacterCreator passing data
    _power_description_label.text = "Description: " + power_data.description

func _on_power_list_item_activated(index: int) -> void:
    var power_id = _power_list.get_item_metadata(index)
    emit_signal("power_toggled", power_id)

func update_confirmation_ui(character_name: String, attributes: Dictionary, skills: Array, powers: Array, all_attributes_data: Dictionary, all_skills_data: Dictionary, all_powers_data: Dictionary) -> void:
    _name_summary_label.text = "Name: " + character_name

    var attr_summary_text = "Attributes:\n"
    for attr_id in attributes.keys():
        var attr_data = all_attributes_data.get(attr_id, {"name": attr_id})
        attr_summary_text += "  " + attr_data.name + " (" + attr_id + "): " + str(attributes[attr_id]) + "\n"
    _attributes_summary_label.text = attr_summary_text

    var skill_summary_text = "Skills:\n"
    if skills.empty():
        skill_summary_text += "  None selected\n"
    else:
        for skill_id in skills:
            var skill_data = all_skills_data.get(skill_id, {"name": skill_id})
            skill_summary_text += "  - " + skill_data.name + "\n"
    _skills_summary_label.text = skill_summary_text

    var power_summary_text = "Powers:\n"
    if powers.empty():
        power_summary_text += "  None selected\n"
    else:
        for power_id in powers:
            var power_data = all_powers_data.get(power_id, {"name": power_id})
            power_summary_text += "  - " + power_data.name + "\n"
    _powers_summary_label.text = power_summary_text

func display_message(message: String) -> void:
    # For GUI, we might display this in a temporary popup or a dedicated message label
    # For now, let's just print to console for debugging
    print("GUI Message: " + message)
