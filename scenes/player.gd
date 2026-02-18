extends CharacterBody2D

@export var base_speed : float = 150.0
@export var animation_tree : AnimationTree
@export var animation_player : AnimationPlayer

@onready var stats : StatsComponent = $StatsComponent
@onready var flash_ability : FlashAbility = $FlashAbility
@onready var dash_ability: DashAbility = $DashAbility
@onready var ghost_ability : GhostAbility = $GhostAbility
@onready var teleport_ability : TeleportAbility = $TeleportAbility

var input : Vector2
var canMove : bool
var playback : AnimationNodeStateMachinePlayback
var input_direction: Vector2

func _ready() -> void:
	playback = animation_tree["parameters/playback"]
	#player gets reference of ability
	for child in get_children():
		if child is AbilityBase:
			child.player = self

func get_stats() -> StatsComponent:
	return stats

func _physics_process(delta: float) -> void:
	#no movement if dashing
	if dash_ability.is_controlling_movement():
		return
	
		
	_handle_movement(delta)
	select_animation()
	update_animation_parameters()

func select_animation():
	if input_direction == Vector2.ZERO:
		playback.travel("Stop")
	else:
		playback.travel("Walk")

func update_animation_parameters():
	if input_direction == Vector2.ZERO:
		return
		
	animation_tree["parameters/Walk/blend_position"] = input_direction
	animation_tree["parameters/Stop/blend_position"] = input_direction

func _handle_movement(_delta: float) -> void:
	input_direction = Input.get_vector("left", "right", "up", "down")
	
	# ghost speed multiplier when active
	var speed = base_speed * ghost_ability.get_speed_multiplier()
	
	velocity = input_direction * speed
	move_and_slide()
	
func _unhandled_input(event : InputEvent) -> void:
	if event.is_action_pressed("flash_ability"):
		flash_ability.try_activate()
	elif event.is_action_pressed("dash_ability"):
		dash_ability.try_activate()
	elif event.is_action_pressed("ghost_ability"):
		ghost_ability.try_activate()
	elif event.is_action_pressed("teleport_ability"):
		teleport_ability.try_activate()
		
func is_channeling() -> bool:
	return teleport_ability.is_channeling
	
func is_dashing() -> bool:
	return dash_ability.is_dashing

	

	
	
	
	
	
	
	
	
	
