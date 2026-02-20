class_name MultiplayerInput
extends Node

var direction: Vector2
var ability_pressed: bool

@onready var player = $".."

func _ready() -> void:
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		set_process(false)
		set_physics_process(false)
	
	direction = Input.get_vector("left", "right", "up", "down")

func _physics_process(delta: float) -> void:
	direction = Input.get_vector("left", "right", "up", "down")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("flash_ability"):
		use_mobility_skill.rpc("flash_ability")
	elif event.is_action_pressed("dash_ability"):
		use_mobility_skill.rpc("dash_ability")
	elif event.is_action_pressed("ghost_ability"):
		use_mobility_skill.rpc("ghost_ability")
	elif event.is_action_pressed("teleport_ability"):
		use_mobility_skill.rpc("teleport_ability")
		

@rpc("call_local")
func use_mobility_skill(skill):
	if multiplayer.is_server():
		player.do_ability = skill
