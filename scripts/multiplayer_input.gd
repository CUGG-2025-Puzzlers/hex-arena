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
		var rolling_dir : Vector2 = HexCells.map_to_local(HexCells.curr_cell)-HexCells.map_to_local(Magic.last_placed_cell)
		if rolling_dir!=Vector2.ZERO:
			rolling_dir = rolling_dir.normalized()
			
			for magic_instance in get_tree().get_nodes_in_group("magic"):
				if magic_instance.player_id==player_id and magic_instance.state in [Magic.MagicType.LIGHT, Magic.MagicType.HEAVY]:
					var magic_cell : Vector2i = magic_instance.self_cell
				
					var points : PackedVector2Array = []
					match magic_instance.state:
						Magic.MagicType.HEAVY:
							points.append_array(Magic.create_wiggly_path(rolling_dir, Magic.BULLET_DISTANCE*randf_range(1,2)))
						Magic.MagicType.LIGHT:
							points.append_array(Magic.create_wiggly_path(rolling_dir, Magic.BULLET_DISTANCE*randf_range(0.5,1)))
					
					HexCells.player_unique_instance.rpc("launch_magic_in_cell", magic_cell, points, player_id)
	
	if Input.is_action_pressed("place_magic")\
	and stats_update.current_mana >= player_preset.magics[player_preset.default_state_to_place].cost:
		var global_mouse_pos : Vector2 = get_parent().get_global_mouse_position()
		HexCells.player_unique_instance.rpc_id(1, "try_place_magic_for_player", 
		global_mouse_pos, player_preset.default_state_to_place, get_parent().cell, get_parent().radius_cells, player_id)
	
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
		
		HexCells.player_unique_instance.rpc_id(1, "try_and_change_magic_for_player", pos, 
		get_parent().radius_cells, state, player_id, stats_update.current_mana)#randi()
