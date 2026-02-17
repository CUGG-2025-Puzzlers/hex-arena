extends CharacterBody2D

@export var base_speed : float = 150.0
@export var animation_tree : AnimationTree
@export var animation_player : AnimationPlayer

@onready var stats: StatsComponent = $StatsComponent

var input : Vector2
var canMove : bool
var playback : AnimationNodeStateMachinePlayback
var input_direction: Vector2

func _ready() -> void:
	playback = animation_tree["parameters/playback"]


func get_stats() -> StatsComponent:
	return stats

func _physics_process(delta: float) -> void:
		
	_handle_movement(delta)
	select_animation()
	update_animation_parameters()
	#_face_mouse()

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
	
	velocity = input_direction * base_speed
	move_and_slide()
	
#func _face_mouse() -> void:
	##rotate to face mouse
	#var mouse_pos = get_global_mouse_position()
	#var angle = (mouse_pos - global_position).angle()
	#
	#if Sprite2D:
		#Sprite2D.rotation = angle
	#

	

	
	
	
	
	
	
	
	
	
