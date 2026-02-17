extends CharacterBody2D

@export var base_speed : float = 150.0

@onready var stats : StatsComponent = $StatsComponent
@onready var flash_ability : FlashAbility = $FlashAbility

var input : Vector2
var canMove : bool

func _ready() -> void:
	#player gets reference of ability
	for child in get_children():
		if child is AbilityBase:
			child.player = self

func get_stats() -> StatsComponent:
	return stats

func _physics_process(delta: float) -> void:
	_handle_movement(delta)
	#_face_mouse()
	
func _handle_movement(_delta: float) -> void:
	var input_direction = Input.get_vector("left", "right", "up", "down")
	
	velocity = input_direction * base_speed
	move_and_slide()
	
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("flash_ability"):
		flash_ability.try_activate()
	

	

	
	
	
	
	
	
	
	
	
