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
	

	if Input.is_action_pressed("place_magic") \
	and stats_update.current_mana >= player_preset.magics[player_preset.default_state_to_place].cost:
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
	
	var possible_states = []
	if Input.is_action_just_pressed("turn_to_heavy"):
		possible_states.append(Magic.MagicType.HEAVY)
	if Input.is_action_just_pressed("turn_to_light"):
		possible_states.append(Magic.MagicType.LIGHT)
	if Input.is_action_just_pressed("turn_to_passive"):
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
	var rolling_dir: Vector2 = (
		HexCells.map_to_local(HexCells.curr_cell)
		- HexCells.map_to_local(Magic.last_placed_cell)
	)
	if rolling_dir.is_zero_approx():
		return
	rolling_dir = rolling_dir.normalized()

	var root_hands: Array[Magic] = []
	var bursts: Array[Magic] = []
	var standard_magic: Array[Magic] = []

	for node in get_tree().get_nodes_in_group("magic"):
		if not (node is Magic):
			continue

		var magic_instance := node as Magic
		if magic_instance.player_id != player_id or magic_instance.rolling:
			continue

		if magic_instance is MagicRootHand:
			root_hands.append(magic_instance)
		elif magic_instance is MagicBurst:
			bursts.append(magic_instance)
		elif magic_instance.state in [Magic.MagicType.LIGHT, Magic.MagicType.HEAVY]:
			standard_magic.append(magic_instance)

	# Zilo's root takes priority. One press fires one prepared root.
	if not root_hands.is_empty():
		_launch_special_magic(_pick_preferred_magic(root_hands), rolling_dir)
		return

	# Zilo detonates one prepared close-range burst per press, allowing rapid
	# repeated attacks instead of all bursts disappearing simultaneously.
	if not bursts.is_empty():
		_launch_special_magic(_pick_preferred_magic(bursts), rolling_dir)
		return

	# Preserve the existing Hekaset behavior: fire all ordinary Light/Heavy magic.
	for magic_instance in standard_magic:
		var distance: float
		match magic_instance.state:
			Magic.MagicType.HEAVY:
				distance = Magic.BULLET_DISTANCE * randf_range(1.0, 2.0)
			Magic.MagicType.LIGHT:
				distance = Magic.BULLET_DISTANCE * randf_range(0.5, 1.0)
			_:
				continue

		var points := Magic.create_wiggly_path(rolling_dir, distance)
		HexCells.player_unique_instance.rpc(
			"launch_magic_in_cell",
			magic_instance.self_cell,
			points,
			player_id
		)

func _pick_preferred_magic(candidates: Array[Magic]) -> Magic:
	for magic_instance in candidates:
		if magic_instance.self_cell == Magic.last_placed_cell:
			return magic_instance
	return candidates[0]

func _launch_special_magic(magic_instance: Magic, rolling_dir: Vector2) -> void:
	# Both special subclasses only need a direction. They define their own
	# travel distance or explosion behavior inside start_rolling().
	var direction_only_path := PackedVector2Array([Vector2.ZERO, rolling_dir])
	HexCells.player_unique_instance.rpc(
		"launch_magic_in_cell",
		magic_instance.self_cell,
		direction_only_path,
		player_id
	)
