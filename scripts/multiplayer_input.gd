class_name MultiplayerInput
extends Node

var direction: Vector2
var use_ability: bool
var mouse_pos: Vector2

var player_id: int

@onready var player_preset: CharacterStats = get_parent().preset
@onready var stats_update: StatsUpdate = $"../StatsComponent"


func _ready() -> void:
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		set_process(false)
		set_physics_process(false)
		set_process_unhandled_input(false)
	else:
		player_id = multiplayer.get_unique_id()

	direction = Input.get_vector("left", "right", "up", "down")
	mouse_pos = get_parent().get_global_mouse_position()


func _physics_process(_delta: float) -> void:
	direction = Input.get_vector("left", "right", "up", "down")


func _unhandled_input(event: InputEvent) -> void:
	mouse_pos = get_parent().get_global_mouse_position()
	use_ability = event.is_action_pressed("ability")

	if Input.is_action_just_pressed("fire_magic"):
		_fire_magic()

	if (
		Input.is_action_pressed("place_magic")
		and (
			stats_update.current_mana
			>= player_preset.magics[player_preset.default_state_to_place].cost
		)
	):
		var global_mouse_pos: Vector2 = get_parent().get_global_mouse_position()
		HexCells.player_unique_instance.rpc_id(
			1,
			"try_place_magic_for_player",
			global_mouse_pos,
			player_preset.default_state_to_place,
			get_parent().cell,
			get_parent().radius_cells,
			player_id
		)

	# Character-specific commands live on optional child controllers. Characters
	# without a WaterOrbWireController keep the normal Passive transformation.
	var pressed_passive: bool = Input.is_action_just_pressed("turn_to_passive")
	var wire_controller: Node = get_parent().get_node_or_null(
		"WaterOrbWireController"
	)

	if pressed_passive and wire_controller != null:
		wire_controller.call("try_create_wire")

	var possible_states = []
	if Input.is_action_just_pressed("turn_to_heavy"):
		possible_states.append(Magic.MagicType.HEAVY)
	if Input.is_action_just_pressed("turn_to_light"):
		possible_states.append(Magic.MagicType.LIGHT)
	if pressed_passive and wire_controller == null:
		possible_states.append(Magic.MagicType.PASSIVE)
	if not possible_states.is_empty():
		var state = possible_states.pick_random()
		var pos = get_parent().get_node("CollisionShape2D").global_position

		HexCells.player_unique_instance.rpc_id(
			1,
			"try_and_change_magic_for_player",
			pos,
			get_parent().radius_cells,
			state,
			player_id,
			stats_update.current_mana
		)


func _fire_magic() -> void:
	var water_attacks: Array[Magic] = []
	var root_hands: Array[Magic] = []
	var bursts: Array[Magic] = []
	var standard_magic: Array[Magic] = []

	for node in get_tree().get_nodes_in_group("magic"):
		if not (node is Magic):
			continue

		var magic_instance: Magic = node as Magic
		if magic_instance.player_id != player_id or magic_instance.rolling:
			continue

		if magic_instance is MagicTidebladeOrb:
			if (magic_instance as MagicTidebladeOrb).can_activate_water_attack():
				water_attacks.append(magic_instance)
		elif magic_instance is MagicPressureLance:
			if (magic_instance as MagicPressureLance).can_activate_water_attack():
				water_attacks.append(magic_instance)
		elif magic_instance is MagicRootHand:
			root_hands.append(magic_instance)
		elif magic_instance is MagicBurst:
			bursts.append(magic_instance)
		elif magic_instance.state in [Magic.MagicType.LIGHT, Magic.MagicType.HEAVY]:
			standard_magic.append(magic_instance)

	if (
		water_attacks.is_empty()
		and root_hands.is_empty()
		and bursts.is_empty()
		and standard_magic.is_empty()
	):
		return

	# Match Hekaset's targeting convention exactly: the cursor chooses a shared
	# direction relative to the most recently placed magic. Every prepared
	# attack then uses that same direction, regardless of its own position.
	var rolling_dir: Vector2 = (
		HexCells.map_to_local(HexCells.curr_cell)
		- HexCells.map_to_local(Magic.last_placed_cell)
	)
	if rolling_dir.is_zero_approx():
		return
	rolling_dir = rolling_dir.normalized()

	# Every ready Tideblade and charged Pressure Lance activates together and
	# follows the shared direction selected from the last-placed magic.
	for magic_instance: Magic in water_attacks:
		_launch_special_magic(magic_instance, rolling_dir)

	# Every prepared Root Hand follows the same shared direction.
	for magic_instance: Magic in root_hands:
		_launch_special_magic(magic_instance, rolling_dir)

	# Every prepared Burst activates together. The direction is supplied for a
	# consistent launch contract even when the Burst itself is stationary.
	for magic_instance: Magic in bursts:
		_launch_special_magic(magic_instance, rolling_dir)

	# Hekaset's ordinary Light and Heavy magic already use this same direction.
	for magic_instance: Magic in standard_magic:
		var distance: float
		match magic_instance.state:
			Magic.MagicType.HEAVY:
				distance = Magic.BULLET_DISTANCE * randf_range(1.0, 2.0)
			Magic.MagicType.LIGHT:
				distance = Magic.BULLET_DISTANCE * randf_range(0.5, 1.0)
			_:
				continue

		var points: PackedVector2Array = Magic.create_wiggly_path(
			rolling_dir,
			distance
		)
		HexCells.player_unique_instance.rpc(
			"launch_magic_in_cell",
			magic_instance.self_cell,
			points,
			player_id
		)


func _launch_special_magic(magic_instance: Magic, rolling_dir: Vector2) -> void:
	# Special subclasses need only a direction. They define their own movement,
	# stationary attack, beam, or explosion behavior inside start_rolling().
	var direction_only_path := PackedVector2Array([Vector2.ZERO, rolling_dir])
	HexCells.player_unique_instance.rpc(
		"launch_magic_in_cell", magic_instance.self_cell, direction_only_path, player_id
	)
