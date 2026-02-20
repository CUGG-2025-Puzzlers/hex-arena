extends CharacterBody2D

@export var base_speed : float = 150.0
@export var animation_tree : AnimationTree
@export var animation_player : AnimationPlayer

@onready var _input: MultiplayerInput = %InputSynchronizer

@onready var stats : StatsComponent = $StatsComponent
@onready var flash_ability : FlashAbility = $FlashAbility
@onready var dash_ability: DashAbility = $DashAbility
@onready var ghost_ability : GhostAbility = $GhostAbility
@onready var teleport_ability : TeleportAbility = $TeleportAbility

var do_ability : String
var input : Vector2
var canMove : bool
var playback : AnimationNodeStateMachinePlayback

var player_id: int:
	set(value):
		player_id = value
		%InputSynchronizer.set_multiplayer_authority(value)

func _ready() -> void:
	playback = animation_tree["parameters/playback"]
	#player gets reference of ability
	for child in get_children():
		if child is AbilityBase:
			child.player = self
	# collision with environment is layer 1 and ignore other players
	set_collision_layer_value(2, true)   # player on layer 2
	set_collision_mask_value(2, false)   # player cant collide with layer 2

func _physics_process(delta: float) -> void:
	#no movement if dashing
	if dash_ability.is_controlling_movement():
		return
		
	if teleport_ability.is_channeling:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	_handle_movement(delta)
	select_animation()
	update_animation_parameters()

func select_animation():
	if _input.direction == Vector2.ZERO:
		playback.travel("Stop")
	else:
		playback.travel("Walk")

func update_animation_parameters():
	if _input.direction == Vector2.ZERO:
		return
		
	animation_tree["parameters/Walk/blend_position"] = _input.direction
	animation_tree["parameters/Stop/blend_position"] = _input.direction

func _handle_movement(_delta: float) -> void:	
	# ghost speed multiplier when active
	var speed = base_speed * ghost_ability.get_speed_multiplier()
	
	if do_ability != "":
		match do_ability:
			"flash_ability":
				flash_ability.try_activate()
			"dash_ability":
				dash_ability.try_activate()
			"ghost_ability":
				ghost_ability.try_activate()
			"teleport_ability":
				teleport_ability.try_activate()
		do_ability = ""

	velocity = _input.direction * speed
	move_and_slide()

func get_stats() -> StatsComponent:
	return stats
	
func is_channeling() -> bool:
	return teleport_ability.is_channeling
	
func is_dashing() -> bool:
	return dash_ability.is_dashing

	

	
	
	
	
	
	
	
	
	
