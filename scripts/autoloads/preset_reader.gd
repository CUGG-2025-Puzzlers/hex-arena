extends Node
#class_name PresetReader

func _ready() -> void:
	
	var magic_preset_dict = load_json_dict("res://presets/magic_data.json")
	if magic_preset_dict.is_empty():
		push_error("Failed to open Magic Presets")
	else:
		read_magic_presets(magic_preset_dict)

func read_magic_presets(dict: Dictionary):
	var magic_type_names : Array = Magic.MagicType.keys()
	
	var MagicType_preset : Array = dict["MagicType"]
	var cost_preset : Dictionary = dict["cost"]
	var health_preset : Dictionary = dict["health"]
	var damage_preset : Dictionary = dict["damage"]
	var speed_preset : Dictionary = dict["speed"]
	var collision_preset : Dictionary = dict["collide_w_own"]
	
	for type in magic_type_names:
		if not MagicType_preset.has(type):
			push_error(type, " not found in JSON")
			continue
		
		var enum_val = Magic.MagicType.get(type)
		
		Magic.cost_dict[enum_val] = cost_preset[type]
		Magic.health_dict[enum_val] = health_preset[type]
		Magic.damage_dict[enum_val] = damage_preset[type]
		Magic.speed_dict[enum_val] = speed_preset[type]
		Magic.collide_w_own_dict[enum_val] = collision_preset[type]

func load_json_dict(file_path: String) -> Dictionary:
	var json_as_text = FileAccess.get_file_as_string(file_path)
	var data = JSON.parse_string(json_as_text)
	if data is Dictionary:
		return data
	return {}
