extends AbilityBase

class_name FlashAbility

@export var max_range : float = 200.0

func _init() -> void:
	ability_name = "Flash"
	input_action = "flash_ability"
	cooldown_duration = 1.0

func _execute() -> void:
	var direction = get_aim_direction()
	var distance = minf(get_aim_distance(), max_range)
	var player_pos = player.global_position 
	var target_pos = player_pos + direction * distance
	var world_state = player.get_world_2d().direct_space_state
	
	# flashing into walls 
	var raycast_query = PhysicsRayQueryParameters2D.create(
		player_pos,
		target_pos
	)
	
	#player unique id excluded
	raycast_query.exclude = [player.get_rid()]
	var result = world_state.intersect_ray(raycast_query)
	
	if result:
		player.global_position = result.position - direction * 8.0
	else:
		player.global_position = target_pos
	
	
