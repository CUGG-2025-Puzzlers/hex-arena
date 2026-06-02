extends Node2D
class_name ShieldBlockObjective

signal completed

@export var shield_cell: Vector2i = Vector2i(0, 0)
@export var enemy_light_spawn_cell: Vector2i = Vector2i(0, -4)
@export var enemy_player_id := 999

@onready var ghost_indicator: MagicGhostIndicator = $"../Magic Ghost Indicator"
@onready var hex_cells: HexCells = get_tree().current_scene.get_node("Path2D") as HexCells

var active := false
var complete := false

var target_shield: Magic = null
var incoming_light: Magic = null
var watched_magic: Array[Magic] = []


func _ready() -> void:
	set_process(false)


func activate() -> void:
	if active or complete:
		return

	print("[SHIELD BLOCK OBJECTIVE] activated")
	active = true
	set_process(true)
	
	ghost_indicator.global_position = hex_cells.to_global(hex_cells.map_to_local(shield_cell))
	ghost_indicator.show_neutral_ghost()

func _process(_delta: float) -> void:
	if not active or complete:
		return

	if target_shield != null and is_instance_valid(target_shield):
		return

	_watch_for_player_shield()


func _watch_for_player_shield() -> void:
	for node in get_tree().get_nodes_in_group("magic"):
		var magic := node as Magic
		if magic == null:
			continue

		if magic.player_id != multiplayer.get_unique_id():
			continue

		if magic.self_cell != shield_cell:
			continue

		_watch_magic(magic)

		if magic.state == Magic.MagicType.NEUTRAL:
			ghost_indicator.show_shield_ghost()
		elif magic.state == Magic.MagicType.SHIELD:
			_on_player_made_shield(magic)
		


func _watch_magic(magic: Magic) -> void:
	if magic in watched_magic:
		return

	watched_magic.append(magic)
	magic.state_changed.connect(_on_magic_state_changed)


func _on_magic_state_changed(
	magic: Magic,
	_old_state: Magic.MagicType,
	new_state: Magic.MagicType
) -> void:
	if not active or complete:
		return

	if magic.player_id != multiplayer.get_unique_id():
		return

	if magic.self_cell != shield_cell:
		return

	if new_state == Magic.MagicType.SHIELD:
		_on_player_made_shield(magic)
		return

	if new_state == Magic.MagicType.LIGHT or new_state == Magic.MagicType.HEAVY:
		print("[SHIELD BLOCK OBJECTIVE] Wrong transform. Resetting magic so player can retry.")
		magic.call_deferred("fizzle")


func _on_player_made_shield(magic: Magic) -> void:
	if target_shield != null and is_instance_valid(target_shield):
		return

	print("[SHIELD BLOCK OBJECTIVE] Player made Shield.")

	target_shield = magic
	target_shield.health = 999999

	ghost_indicator.hide_ghost()

	if not target_shield.area_entered.is_connected(_on_shield_area_entered):
		target_shield.area_entered.connect(_on_shield_area_entered)

	_spawn_incoming_light()
	
func _spawn_incoming_light() -> void:
	if complete:
		return

	print("[SHIELD BLOCK OBJECTIVE] Spawning incoming Light.")

	incoming_light = get_tree().current_scene.spawn_tutorial_magic(
		enemy_light_spawn_cell,
		Magic.MagicType.LIGHT,
		enemy_player_id
	)

	if incoming_light == null:
		push_error("[SHIELD BLOCK OBJECTIVE] Failed to spawn incoming Light.")
		return

	incoming_light.fizzling.connect(_on_incoming_light_fizzled)

	var local_end := target_shield.global_position - incoming_light.global_position
	var dir := local_end.normalized()

	var path := PackedVector2Array([
		Vector2.ZERO,
		local_end + dir * 240.0
	])

	incoming_light.start_rolling(path)


func _on_shield_area_entered(area: Area2D) -> void:
	if complete:
		return

	var magic := area as Magic
	if magic == null:
		return

	if magic != incoming_light:
		return

	if magic.state != Magic.MagicType.LIGHT:
		return

	if magic.player_id != enemy_player_id:
		return

	print("[SHIELD BLOCK OBJECTIVE] Incoming Light was blocked by Shield.")
	_complete_objective()


func _on_incoming_light_fizzled() -> void:
	if complete:
		return

	if not active:
		return

	print("[SHIELD BLOCK OBJECTIVE] Incoming Light missed/fizzled. Retrying.")

	await get_tree().create_timer(0.75).timeout

	if complete:
		return

	if target_shield != null and is_instance_valid(target_shield):
		_spawn_incoming_light()


func _complete_objective() -> void:
	if complete:
		return

	complete = true
	active = false
	set_process(false)

	if incoming_light != null and is_instance_valid(incoming_light):
		incoming_light.call_deferred("fizzle")

	await get_tree().create_timer(0.4).timeout

	if target_shield != null and is_instance_valid(target_shield):
		target_shield.call_deferred("fizzle")

	print("[SHIELD BLOCK OBJECTIVE] complete")
	completed.emit()
