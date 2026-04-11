extends AbilityBase

class_name DashAbility

# these values need to be better adjusted
@export var dash_distance : float = 400.0
@export var dash_duration : float = 0.35 
@export var dash_speed_curve : float = 2.0  # decelerate

var is_dashing : bool = false
var dash_elapsed : float = 0.0
var dash_direction : Vector2 = Vector2.ZERO
var dash_start_pos : Vector2 = Vector2.ZERO

func _init() -> void:
	ability_name = "Dash"
	input_action = "dash_ability"
	cooldown_duration = 0.7

func _physics_process(delta: float) -> void:
	if is_dashing:
		dash_elapsed += delta
		var progress = dash_elapsed / dash_duration

		if progress >= 1.0:
			_end_dash()
			return
		
		# fast start then decelerate
		var speed_factor = pow(1.0 - progress, dash_speed_curve)
		var speed = (dash_distance / dash_duration) * speed_factor * 2.0
		player.velocity = dash_direction * speed
		player.move_and_slide()

func _execute() -> void:
	dash_direction = player.get_node("InputSynchronizer").direction.normalized()
	if dash_direction == Vector2.ZERO:
		dash_direction = get_aim_direction()
	dash_start_pos = player.global_position
	dash_elapsed = 0.0
	is_dashing = true
	is_active = true

func _end_dash() -> void:
	is_dashing = false
	is_active = false
	player.velocity = Vector2.ZERO
	ability_ended.emit()

# true if player is dashing
func is_controlling_movement() -> bool:
	return is_dashing
