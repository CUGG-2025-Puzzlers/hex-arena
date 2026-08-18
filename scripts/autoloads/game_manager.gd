extends Node

var player_name: String = ""
var xp: int = 0
var level: int = 1

const SAVE_PATH = "user://save_data.json"

func _ready() -> void:
	MultiplayerManager.server_disconnected.connect(_on_server_disconnected)
	load_data()
	print(OS.get_user_data_dir())

func save_data() -> void:
	var data = {
		"player_name": player_name,
		"xp": xp,
		"level": level
	}
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
		
func load_data() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var content = file.get_as_text()
			var data = JSON.parse_string(content)
			if data:
				player_name = data.get("player_name", "")
				xp = data.get("xp", 0)
				level = data.get("level", 1)
			file.close()

func add_xp(amount: int) -> void:
	xp += amount
	
	# Check for level ups. Formula: xp required for NEXT level = 5 + (level * 5)
	# This means going from Level 1 -> 2 requires 10 cumulative XP.
	var leveled_up = false
	while true:
		var xp_needed = 5 + (level * 5)
		if xp >= xp_needed:
			xp -= xp_needed
			level += 1
			leveled_up = true
		else:
			break
			
	if leveled_up:
		print("Leveled up to level ", level, "!")
		
	save_data()

func is_valid_name(name_to_check: String) -> bool:
	if name_to_check.length() < 2 || name_to_check.length() > 16:
		return false
	
	var name_regex = RegEx.create_from_string("^[a-zA-Z]{2,16}$")
	if name_regex.search(name_to_check):
		return true
	
	return false

#region Event Listeners

func _on_server_disconnected():
	pass

#endregion
