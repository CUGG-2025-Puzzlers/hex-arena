extends AbilityBase

class_name TeleportAbility

@export var channel_time : float = 3.0
@export var cancelled_tp_cooldowm : float = 0.5  # 50% cooldown if cancel

var is_channeling: bool = false
var channel_elapsed: float = 0.0
var target_position: Vector2 = Vector2.ZERO
var channel_indicator: Node2D = null  # visual at target location
var channel_bar: ColorRect = null  # progress bar above player

var teleport_indicator_scene = preload("res://scenes/teleport_indicator.tscn")

func _init() -> void:
	ability_name = "Teleport"
	input_action = "teleport_ability"
	cooldown_duration = 1.0
	
func _process(delta: float) -> void:
	super._process(delta)

	if is_channeling:
		channel_elapsed += delta
		_update_channel_bar()
	
	# cancel tp if player moves
		var input_direction = Input.get_vector("left", "right", "up", "down")
		if input_direction.length() > 0.1:
			_cancel_channel()
			return

		if channel_elapsed >= channel_time:
			_complete_teleport()

func can_activate() -> bool:
	return not is_channeling

func _execute() -> void:
	var aim_dir = get_aim_direction()
	target_position = player.global_position + aim_dir * get_aim_distance()

	is_channeling = true
	is_active = true
	channel_elapsed = 0.0
	is_on_cooldown = false
	
	_spawn_channel_visuals()


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
		var dir = (target_position - player.global_position).normalized()
		player.global_position = result.position - dir * 8.0
	else:
		player.global_position = target_position

	_cleanup_channel()
	_start_cooldown()
	
func _cancel_channel() -> void:
	_cleanup_channel()
	# refund partial cooldown when calceled
	is_on_cooldown = true
	cooldown_remaining = cooldown_duration * cancelled_tp_cooldowm
	cooldown_started.emit(cooldown_duration * cancelled_tp_cooldowm)

func _cleanup_channel() -> void:
	is_channeling = false
	is_active = false
	if channel_indicator:
		channel_indicator.queue_free()
		channel_indicator = null
	if channel_bar:
		channel_bar.queue_free()
		channel_bar = null
	ability_ended.emit()

# tp visual indicator

func _spawn_channel_visuals() -> void:
	# circle at target tp position
	channel_indicator = teleport_indicator_scene.instantiate()
	channel_indicator.global_position = target_position
	player.get_parent().add_child(channel_indicator)
	
	# progress bar above player
	channel_bar = ColorRect.new()
	channel_bar.color = Color(0.3, 0.5, 1.0, 0.8)
	channel_bar.size = Vector2(0, 4)
	channel_bar.position = Vector2(-20, -95)
	player.add_child(channel_bar)

func _update_channel_bar() -> void:
	if channel_bar:
		channel_bar.size.x = 40.0 * (channel_elapsed / channel_time)
