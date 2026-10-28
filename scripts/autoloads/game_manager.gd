extends Node

const SAVE_PATH := "user://save_data.json"

const CONTROL_SCHEME_LEGACY := "legacy"
const CONTROL_SCHEME_NEW := "mouse_primary_fire"
const CAMERA_PROFILE_LEGACY := "legacy"
const CAMERA_PROFILE_LEAGUE := "league_test"
const READABILITY_STYLE_CURRENT := "current"
const READABILITY_STYLE_OUTLINE := "team_outline"

const LOCAL_OUTLINE_COLOR := Color("69DFFF")
const ENEMY_OUTLINE_COLOR := Color("FF4B55")
const OUTLINE_WORLD_WIDTH := 1.35
const TEAM_OUTLINE_SHADER := preload("res://shaders/team_outline.gdshader")
const ORIGINAL_MATERIAL_META := &"_readability_original_material"
const OUTLINE_MATERIAL_META := &"_readability_outline_material"

signal readability_style_changed(style: String)

var player_name: String = ""
var xp: int = 0
var level: int = 1

# Playtest settings intentionally live in the existing save file/autoload so
# controls and camera experiments do not need another settings subsystem.
var control_scheme: String = CONTROL_SCHEME_NEW
var camera_profile: String = CAMERA_PROFILE_LEAGUE
var camera_locked: bool = true
var readability_style: String = READABILITY_STYLE_CURRENT


func _ready() -> void:
	MultiplayerManager.server_disconnected.connect(_on_server_disconnected)
	load_data()
	_apply_control_scheme()
	print(OS.get_user_data_dir())
	print("[PLAYTEST] F6 controls; F7 camera; F8 readability style.")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	var key_event := event as InputEventKey
	var key := key_event.physical_keycode
	if key == 0:
		key = key_event.keycode

	if key == KEY_F6:
		set_control_scheme(
			CONTROL_SCHEME_LEGACY
			if control_scheme == CONTROL_SCHEME_NEW
			else CONTROL_SCHEME_NEW
		)
	elif key == KEY_F7:
		set_camera_profile(
			CAMERA_PROFILE_LEGACY
			if camera_profile == CAMERA_PROFILE_LEAGUE
			else CAMERA_PROFILE_LEAGUE
		)
	elif key == KEY_F8:
		set_readability_style(
			READABILITY_STYLE_CURRENT
			if readability_style == READABILITY_STYLE_OUTLINE
			else READABILITY_STYLE_OUTLINE
		)


func set_control_scheme(value: String) -> void:
	if value not in [CONTROL_SCHEME_LEGACY, CONTROL_SCHEME_NEW]:
		return
	control_scheme = value
	_apply_control_scheme()
	save_data()
	print("[PLAYTEST] Controls: ", control_scheme)
	Telemetry.track("playtest_setting_changed", {
		"setting": "control_scheme",
		"value": control_scheme,
	})


func set_camera_profile(value: String) -> void:
	if value not in [CAMERA_PROFILE_LEGACY, CAMERA_PROFILE_LEAGUE]:
		return
	camera_profile = value
	camera_locked = true
	save_data()
	print("[PLAYTEST] Camera: ", camera_profile)
	Telemetry.track("playtest_setting_changed", {
		"setting": "camera_profile",
		"value": camera_profile,
	})


func set_readability_style(value: String) -> void:
	if value not in [READABILITY_STYLE_CURRENT, READABILITY_STYLE_OUTLINE]:
		return
	readability_style = value
	save_data()
	readability_style_changed.emit(readability_style)
	print("[PLAYTEST] Readability: ", readability_style)
	Telemetry.track("playtest_setting_changed", {
		"setting": "readability_style",
		"value": readability_style,
	})


func set_team_outline(item: CanvasItem, color: Color, enabled: bool) -> void:
	if item == null:
		return

	if not item.has_meta(ORIGINAL_MATERIAL_META):
		item.set_meta(ORIGINAL_MATERIAL_META, item.material)

	if not enabled:
		item.material = item.get_meta(ORIGINAL_MATERIAL_META, null)
		return

	# Do not replace authored shader/material effects. The current player and
	# persistent-magic sprites do not use one, so this keeps the test isolated.
	var original_material = item.get_meta(ORIGINAL_MATERIAL_META, null)
	if original_material != null:
		return

	var material := item.get_meta(OUTLINE_MATERIAL_META, null) as ShaderMaterial
	if material == null:
		material = ShaderMaterial.new()
		material.shader = TEAM_OUTLINE_SHADER
		item.set_meta(OUTLINE_MATERIAL_META, material)

	var node_2d := item as Node2D
	var visual_scale := 1.0
	if node_2d != null:
		var global_scale := node_2d.global_transform.get_scale().abs()
		visual_scale = maxf(minf(global_scale.x, global_scale.y), 0.03)

	material.set_shader_parameter("outline_color", color)
	material.set_shader_parameter(
		"outline_width_texels",
		clampf(OUTLINE_WORLD_WIDTH / visual_scale, 1.0, 48.0)
	)
	item.material = material


func _apply_control_scheme() -> void:
	if not InputMap.has_action("place_magic") or not InputMap.has_action("fire_magic"):
		return

	InputMap.action_erase_events("place_magic")
	InputMap.action_erase_events("fire_magic")

	var place_mouse := InputEventMouseButton.new()
	var fire_event: InputEvent

	if control_scheme == CONTROL_SCHEME_LEGACY:
		place_mouse.button_index = MOUSE_BUTTON_LEFT
		var fire_key := InputEventKey.new()
		fire_key.physical_keycode = KEY_SPACE
		fire_event = fire_key
	else:
		place_mouse.button_index = MOUSE_BUTTON_RIGHT
		var fire_mouse := InputEventMouseButton.new()
		fire_mouse.button_index = MOUSE_BUTTON_LEFT
		fire_event = fire_mouse

	InputMap.action_add_event("place_magic", place_mouse)
	InputMap.action_add_event("fire_magic", fire_event)


func save_data() -> void:
	var data := {
		"player_name": player_name,
		"xp": xp,
		"level": level,
		"control_scheme": control_scheme,
		"camera_profile": camera_profile,
		"readability_style": readability_style,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()


func load_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return

	var data = JSON.parse_string(file.get_as_text())
	file.close()
	if not data is Dictionary:
		return

	player_name = data.get("player_name", "")
	xp = int(data.get("xp", 0))
	level = int(data.get("level", 1))

	var saved_controls := str(data.get("control_scheme", CONTROL_SCHEME_NEW))
	if saved_controls in [CONTROL_SCHEME_LEGACY, CONTROL_SCHEME_NEW]:
		control_scheme = saved_controls

	var saved_camera := str(data.get("camera_profile", CAMERA_PROFILE_LEAGUE))
	if saved_camera in [CAMERA_PROFILE_LEGACY, CAMERA_PROFILE_LEAGUE]:
		camera_profile = saved_camera

	var saved_readability := str(
		data.get("readability_style", READABILITY_STYLE_CURRENT)
	)
	if saved_readability in [READABILITY_STYLE_CURRENT, READABILITY_STYLE_OUTLINE]:
		readability_style = saved_readability


func add_xp(amount: int) -> void:
	xp += amount

	var leveled_up := false
	while true:
		var xp_needed := 5 + (level * 5)
		if xp < xp_needed:
			break
		xp -= xp_needed
		level += 1
		leveled_up = true

	if leveled_up:
		print("Leveled up to level ", level, "!")

	save_data()


func is_valid_name(name_to_check: String) -> bool:
	if name_to_check.length() < 2 or name_to_check.length() > 16:
		return false

	var name_regex := RegEx.create_from_string("^[a-zA-Z]{2,16}$")
	return name_regex.search(name_to_check) != null


#region Event Listeners
func _on_server_disconnected() -> void:
	pass
#endregion
