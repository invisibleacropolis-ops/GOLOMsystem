extends Node

var skills_data: Dictionary = {}
var powers_data: Dictionary = {}
var attributes_data: Dictionary = {}

func _ready() -> void:
	load_skills_data()
	load_powers_data()
	load_attributes_data()

func load_skills_data() -> void:
	var file = FileAccess.open("res://data/skills.json", FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var parsed_data = JSON.parse_string(content)
		if parsed_data is Dictionary:
			skills_data = parsed_data
			for skill_id in skills_data.keys():
				var skill_data = skills_data[skill_id]
				if not (skill_data is Dictionary and skill_data.has("name") and skill_data.has("description")):
					push_error("Invalid skill data for ID: ", skill_id, ". Missing 'name' or 'description'.")
					skills_data.erase(skill_id) # Remove malformed entry
		else:
			push_error("Failed to parse skills.json: Root is not a Dictionary.")
		file.close()
	else:
		push_error("Failed to open skills.json")

func load_powers_data() -> void:
	var file = FileAccess.open("res://data/powers.json", FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var parsed_data = JSON.parse_string(content)
		if parsed_data is Dictionary:
			powers_data = parsed_data
			for power_id in powers_data.keys():
				var power_data = powers_data[power_id]
				if not (power_data is Dictionary and power_data.has("name") and power_data.has("description")):
					push_error("Invalid power data for ID: ", power_id, ". Missing 'name' or 'description'.")
					powers_data.erase(power_id) # Remove malformed entry
		else:
			push_error("Failed to parse powers.json: Root is not a Dictionary.")
		file.close()
	else:
		push_error("Failed to open powers.json")

func get_skill_data(skill_id: String) -> Dictionary:
	return skills_data.get(skill_id, {})

func get_all_skills() -> Dictionary:
	return skills_data

func get_power_data(power_id: String) -> Dictionary:
	return powers_data.get(power_id, {})

func get_all_powers() -> Dictionary:
	return powers_data

func load_attributes_data() -> void:
	var file = FileAccess.open("res://data/attributes.json", FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var parsed_data = JSON.parse_string(content)
		if parsed_data is Dictionary:
			attributes_data = parsed_data
			for attr_id in attributes_data.keys():
				var attr_data = attributes_data[attr_id]
				if not (attr_data is Dictionary and attr_data.has("name") and attr_data.has("description")):
					push_error("Invalid attribute data for ID: ", attr_id, ". Missing 'name' or 'description'.")
					attributes_data.erase(attr_id) # Remove malformed entry
		else:
			push_error("Failed to parse attributes.json: Root is not a Dictionary.")
		file.close()
	else:
		push_error("Failed to open attributes.json")

func get_attribute_data(attribute_id: String) -> Dictionary:
	return attributes_data.get(attribute_id, {})

func get_all_attributes() -> Dictionary:
	return attributes_data
