class_name MultiplayerInput
extends Node

var direction: Vector2
var ability: Util.Ability

func _ready() -> void:
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		set_process(false)
		set_physics_process(false)
	
	direction = Input.get_vector("left", "right", "up", "down")

func _physics_process(delta: float) -> void:
	direction = Input.get_vector("left", "right", "up", "down")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("flash_ability"):
		ability = Util.Ability.Flash
	elif event.is_action_pressed("dash_ability"):
		ability = Util.Ability.Dash
	elif event.is_action_pressed("ghost_ability"):
		ability = Util.Ability.Ghost
	elif event.is_action_pressed("teleport_ability"):
		ability = Util.Ability.Teleport
	else:
		ability = Util.Ability.None
