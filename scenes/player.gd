extends CharacterBody2D

@export var base_speed : float = 150.0

var input : Vector2
var canMove : bool

func _ready():
	canMove = true
	

func _physics_process(delta: float) -> void:
		
	_handle_movement(delta)
	#_face_mouse()
	
func _handle_movement(_delta: float) -> void:
	var input_direction = Input.get_vector("left", "right", "up", "down")
	
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

	

	
	
	
	
	
	
	
	
	
