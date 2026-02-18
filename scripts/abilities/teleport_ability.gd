extends AbilityBase

class_name TeleportAbility

@export var channel_time : float = 1.0

var is_channeling: bool = false
var channel_elapsed: float = 0.0
var target_position: Vector2 = Vector2.ZERO

func _init() -> void:
	ability_name = "Teleport"
	input_action = "teleport_ability"
	cooldown_duration = 1.0
	
func _process(delta: float) -> void:
	super._process(delta)

	if is_channeling:
		channel_elapsed += delta

		if channel_elapsed >= channel_time:
			_complete_teleport()

func can_activate() -> bool:
	return not is_channeling

func _execute() -> void:
	var aim_dir = get_aim_direction()
	var aim_dist = get_aim_distance()
	target_position = player.global_position + aim_dir * aim_dist

	is_channeling = true
	is_active = true
	channel_elapsed = 0.0

	is_on_cooldown = false


func _complete_teleport() -> void:
	var world_state = player.get_world_2d().direct_space_state

	# avoid teleport into walls
	var raycast_query = PhysicsRayQueryParameters2D.create(
		player.global_position,
		target_position
	)
	
	#player unique id excluded
	raycast_query.exclude = [player.get_rid()]
	var result = world_state.intersect_ray(raycast_query)

	if result:
		player.global_position = result.position - (target_position - player.global_position).normalized() * 8.0
	else:
		player.global_position = target_position

	is_channeling = false
	is_active = false
	ability_ended.emit()
	_start_cooldown()
