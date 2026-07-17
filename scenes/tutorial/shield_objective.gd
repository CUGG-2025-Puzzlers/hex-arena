extends Node2D
class_name ShieldBlockObjective

signal completed

@export var shield_cell: Vector2i = Vector2i.ZERO
@export var enemy_light_spawn_cell: Vector2i = Vector2i(0, -4)
@export var enemy_player_id: int = 999

# Used as a fallback because the projectile may fizzle during the same physics
# frame that it reaches the Shield.
@export var hit_distance: float = 130.0

@onready var ghost_indicator: MagicGhostIndicator = (
	$"../Magic Ghost Indicator"
)

@onready var hex_cells: HexCells = (
	get_tree().current_scene.get_node("Path2D") as HexCells
)

var active: bool = false
var complete: bool = false

var target_shield: Magic = null
var incoming_light: Magic = null

var rejected_magic_instance_id: int = 0

var retry_pending: bool = false
var shot_in_progress: bool = false

var shield_health_before_shot: float = 0.0
var closest_shot_distance: float = INF


func _ready() -> void:
	set_process(false)


func activate() -> void:
	if active or complete:
		return

	print("[SHIELD BLOCK OBJECTIVE] activated")

	active = true
	retry_pending = false
	shot_in_progress = false
	rejected_magic_instance_id = 0

	target_shield = null
	incoming_light = null

	set_process(true)

	ghost_indicator.global_position = hex_cells.to_global(
		hex_cells.map_to_local(shield_cell)
	)

	ghost_indicator.show_neutral_ghost()


func _process(_delta: float) -> void:
	if not active or complete:
		return

	if target_shield == null or not is_instance_valid(target_shield):
		target_shield = null

		if incoming_light != null and not is_instance_valid(incoming_light):
			incoming_light = null
			shot_in_progress = false

		_watch_shield_cell()
		return

	if not shot_in_progress:
		return

	# The projectile damaged the Shield. This confirms that it reached it even
	# when area_entered was not observed by the tutorial script.
	if target_shield.own_health < shield_health_before_shot:
		print(
			"[SHIELD BLOCK OBJECTIVE] "
			+ "Shield took damage from the incoming Light."
		)

		_complete_objective()
		return

	if incoming_light != null and is_instance_valid(incoming_light):
		_check_incoming_light_contact()
		return

	# The projectile was removed. Determine whether it reached the Shield before
	# treating it as a miss.
	incoming_light = null
	shot_in_progress = false

	if closest_shot_distance <= hit_distance:
		print(
			"[SHIELD BLOCK OBJECTIVE] "
			+ "Incoming Light reached the Shield."
		)

		_complete_objective()
		return

	_schedule_incoming_light_retry()


func _watch_shield_cell() -> void:
	var magic := _get_player_magic_in_shield_cell()

	if magic == null:
		rejected_magic_instance_id = 0
		ghost_indicator.show_neutral_ghost()
		return

	match magic.state:
		Magic.MagicType.NEUTRAL:
			rejected_magic_instance_id = 0
			ghost_indicator.show_shield_ghost()

		Magic.MagicType.PASSIVE:
			rejected_magic_instance_id = 0
			_on_player_made_shield(magic)

		Magic.MagicType.LIGHT, Magic.MagicType.HEAVY:
			_reject_wrong_transform(magic)

		_:
			_reject_wrong_transform(magic)


func _get_player_magic_in_shield_cell() -> Magic:
	if HexCells.cell_dict.has(shield_cell):
		var cell_contents = HexCells.cell_dict[shield_cell]

		if is_instance_valid(cell_contents):
			var cell_magic := cell_contents as Magic

			if (
				cell_magic != null
				and cell_magic.player_id == multiplayer.get_unique_id()
			):
				return cell_magic

	# Fallback for the frame during which one Magic scene replaces another.
	for node in get_tree().get_nodes_in_group("magic"):
		var magic := node as Magic

		if magic == null:
			continue

		if magic.player_id != multiplayer.get_unique_id():
			continue

		if magic.self_cell != shield_cell:
			continue

		return magic

	return null


func _reject_wrong_transform(magic: Magic) -> void:
	var instance_id := magic.get_instance_id()

	if rejected_magic_instance_id == instance_id:
		return

	rejected_magic_instance_id = instance_id

	print(
		"[SHIELD BLOCK OBJECTIVE] Wrong transform: ",
		Magic.MagicType.keys()[magic.state],
		". Removing it so the player can retry."
	)

	ghost_indicator.show_neutral_ghost()
	magic.call_deferred("fizzle")


func _on_player_made_shield(magic: Magic) -> void:
	if target_shield != null and is_instance_valid(target_shield):
		return

	print("[SHIELD BLOCK OBJECTIVE] Player made Shield.")

	target_shield = magic

	# Prevent the tutorial Shield's normal lifetime timer from removing it
	# before the incoming projectile sequence finishes.
	if target_shield is MagicShield:
		var shield := target_shield as MagicShield
		shield.expires = false

		for child in shield.get_children():
			if child is Timer:
				var timer := child as Timer
				timer.stop()

	ghost_indicator.hide_ghost()

	if not target_shield.area_entered.is_connected(
		_on_shield_area_entered
	):
		target_shield.area_entered.connect(
			_on_shield_area_entered
		)

	_spawn_incoming_light()


func _spawn_incoming_light() -> void:
	if complete or not active:
		return

	if target_shield == null or not is_instance_valid(target_shield):
		return

	if incoming_light != null and is_instance_valid(incoming_light):
		return

	retry_pending = false
	shot_in_progress = false

	print("[SHIELD BLOCK OBJECTIVE] Spawning incoming Light.")

	incoming_light = get_tree().current_scene.spawn_tutorial_magic(
		enemy_light_spawn_cell,
		Magic.MagicType.LIGHT,
		enemy_player_id
	)

	if incoming_light == null:
		push_error(
			"[SHIELD BLOCK OBJECTIVE] "
			+ "Failed to spawn incoming Light."
		)
		return

	shield_health_before_shot = target_shield.own_health
	closest_shot_distance = INF
	shot_in_progress = true

	var local_end: Vector2 = (
		target_shield.global_position
		- incoming_light.global_position
	)

	if local_end.is_zero_approx():
		push_error(
			"[SHIELD BLOCK OBJECTIVE] "
			+ "Incoming Light spawned on the Shield."
		)

		shot_in_progress = false
		incoming_light.call_deferred("fizzle")
		return

	var direction := local_end.normalized()

	var path := PackedVector2Array([
		Vector2.ZERO,
		local_end + direction * 240.0,
	])

	incoming_light.start_rolling(path)


func _check_incoming_light_contact() -> void:
	if incoming_light == null or not is_instance_valid(incoming_light):
		return

	if target_shield == null or not is_instance_valid(target_shield):
		return

	var distance := incoming_light.global_position.distance_to(
		target_shield.global_position
	)

	closest_shot_distance = min(
		closest_shot_distance,
		distance
	)

	# Primary polling check using the actual Area2D overlap.
	if target_shield.overlaps_area(incoming_light):
		print(
			"[SHIELD BLOCK OBJECTIVE] "
			+ "Incoming Light overlapped the Shield."
		)

		_complete_objective()
		return

	# Fallback for cases where the projectile fizzles before the overlap signal
	# or overlap query becomes visible to this script.
	if distance <= hit_distance:
		print(
			"[SHIELD BLOCK OBJECTIVE] "
			+ "Incoming Light reached the Shield."
		)

		_complete_objective()


func _on_shield_area_entered(area: Area2D) -> void:
	if complete or not active:
		return

	var magic := area as Magic

	if magic == null:
		return

	if incoming_light == null:
		return

	if magic != incoming_light:
		return

	if magic.state != Magic.MagicType.LIGHT:
		return

	if magic.player_id != enemy_player_id:
		return

	print(
		"[SHIELD BLOCK OBJECTIVE] "
		+ "Incoming Light was blocked by Shield."
	)

	_complete_objective()


func _schedule_incoming_light_retry() -> void:
	if retry_pending or complete or not active:
		return

	retry_pending = true

	print(
		"[SHIELD BLOCK OBJECTIVE] "
		+ "Incoming Light missed or disappeared. Retrying."
	)

	await get_tree().create_timer(0.75).timeout

	retry_pending = false

	if complete or not active:
		return

	if target_shield == null or not is_instance_valid(target_shield):
		print(
			"[SHIELD BLOCK OBJECTIVE] "
			+ "Shield disappeared before retry."
		)
		return

	_spawn_incoming_light()


func _complete_objective() -> void:
	if complete:
		return

	complete = true
	active = false
	shot_in_progress = false
	retry_pending = false

	set_process(false)

	print("[SHIELD BLOCK OBJECTIVE] complete")

	if incoming_light != null and is_instance_valid(incoming_light):
		incoming_light.call_deferred("fizzle")

	await get_tree().create_timer(0.4).timeout

	if target_shield != null and is_instance_valid(target_shield):
		target_shield.call_deferred("fizzle")

	completed.emit()
