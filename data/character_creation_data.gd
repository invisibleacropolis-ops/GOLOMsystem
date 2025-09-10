extends Resource
class_name CharacterCreationData

@export var initial_attribute_points: int = 10

func get_all_attributes() -> Dictionary:
    return {
        "strength": {"name": "Strength", "description": "Physical power"},
        "dexterity": {"name": "Dexterity", "description": "Agility and reflexes"},
        "constitution": {"name": "Constitution", "description": "Health and endurance"},
        "intelligence": {"name": "Intelligence", "description": "Mental acuity"},
        "wisdom": {"name": "Wisdom", "description": "Perception and insight"},
        "charisma": {"name": "Charisma", "description": "Force of personality"},
    }

func get_all_skills() -> Dictionary:
    return {
        "acrobatics": {"name": "Acrobatics", "description": "Graceful movement"},
        "stealth": {"name": "Stealth", "description": "Moving unseen"},
        "persuasion": {"name": "Persuasion", "description": "Influencing others"},
        "medicine": {"name": "Medicine", "description": "Healing and first aid"},
    }

func get_all_powers() -> Dictionary:
    return {
        "fireball": {"name": "Fireball", "description": "Hurl a ball of fire"},
        "heal": {"name": "Heal", "description": "Restore health"},
        "invisibility": {"name": "Invisibility", "description": "Become unseen"},
    }
