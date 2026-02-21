class_name MultiplayerInput
extends Node

var direction: Vector2
var ability: Util.Ability
var mouse_pos: Vector2

var camera_offset: Vector2

var player_id: int

@onready var own_stats: StatsComponent = get_parent().get_node("StatsComponent")

func _ready() -> void:
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		set_process(false)
		set_physics_process(false)
		set_process_unhandled_input(false)
	else:
		player_id = multiplayer.get_unique_id()
	
	var camera = get_viewport().get_camera_2d()
	camera_offset = camera.position - camera.get_viewport_rect().size / 2
	
	direction = Input.get_vector("left", "right", "up", "down")
	mouse_pos = get_parent().get_global_mouse_position()

func _physics_process(_delta: float) -> void:
	direction = Input.get_vector("left", "right", "up", "down")

func _unhandled_input(event: InputEvent) -> void:
	mouse_pos = get_parent().get_global_mouse_position()
	
	if event.is_action_pressed("flash_ability"):
		ability = Util.Ability.Flash
	elif event.is_action_pressed("dash_ability"):
		ability = Util.Ability.Dash
	elif event.is_action_pressed("ghost_ability"):
		ability = Util.Ability.Ghost
	elif event.is_action_pressed("teleport_ability"):
		ability = Util.Ability.Teleport
	else:
		ability = Util.Ability.None
	
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
	and own_stats.current_mana>=Magic.cost[Magic.MagicType.NEUTRAL]:
		var global_mouse_pos : Vector2 = get_parent().get_global_mouse_position()
		HexCells.player_unique_instance.rpc("place_magic_in_cell", global_mouse_pos, get_parent().cell, get_parent().radius_cells, player_id, own_stats)
	
	var possible_states = []
	if Input.is_action_just_pressed("turn_pure_to_heavy")\
	and own_stats.current_mana>=Magic.cost[Magic.MagicType.HEAVY]:
		possible_states.append(Magic.MagicType.HEAVY)
	if Input.is_action_just_pressed("turn_pure_to_light")\
	and own_stats.current_mana>=Magic.cost[Magic.MagicType.LIGHT]:
		possible_states.append(Magic.MagicType.LIGHT)
	if Input.is_action_just_pressed("turn_pure_to_shield")\
	and own_stats.current_mana>=Magic.cost[Magic.MagicType.SHIELD]:
		possible_states.append(Magic.MagicType.SHIELD)
	if not possible_states.is_empty():
		var state = possible_states.pick_random()
		var pos = get_parent().get_node("CollisionShape2D").global_position
		HexCells.player_unique_instance.rpc("change_magic",pos, get_parent().radius_cells, state, player_id, own_stats, floori(own_stats.current_mana*1./Magic.cost[state]),randi())
		#HexCells.player_unique_instance.change_magic(pos, get_parent().radius_cells, state,player_id)
