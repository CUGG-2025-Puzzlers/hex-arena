extends AbilityBase

class_name GhostAbility

@export var duration : float = 5.0
@export var speed_multiplier: float = 2.0
@export var ramp_up_time: float = 0.5  # till full speed

var elapsed : float = 0.0
var current_multiplier: float = 1.0

func _init() -> void:
	ability_name = "Ghost"
	input_action = "ghost_ability"
	cooldown_duration = 15.0

func _process(delta: float) -> void:
	super._process(delta)

	if is_active:
		elapsed += delta
		
		# take value of e/r_u_t and force it to stay in range {0,1}
		var ramping_effect = clampf(elapsed / ramp_up_time, 0.0, 1.0)
		# ramp speed gradually from 1 to s_m
		current_multiplier = lerpf(1.0, speed_multiplier, ramping_effect)
		# ^ solved infinitely increasing speed
		
		if elapsed >= duration:
			_deactivate()

func _execute() -> void:
	is_active = true
	elapsed = 0.0
	current_multiplier = 1.0
	
	_set_ghost_visual(true)
	ability_activated.emit()

func _deactivate() -> void:
	is_active = false
	current_multiplier = 1.0
	
	_set_ghost_visual(false)
	ability_ended.emit()
	
	
func get_speed_multiplier() -> float:
	return current_multiplier if is_active else 1.0
	
func _set_ghost_visual(ghosted: bool) -> void:
	# tinting sprite to show actrive ghost
	var sprite = player.get_node_or_null("Sprite2D")
	if sprite:
		if ghosted:
			sprite.modulate = Color(0.171, 0.612, 0.803, 0.6)
		else:
			sprite.modulate = Color.WHITE
