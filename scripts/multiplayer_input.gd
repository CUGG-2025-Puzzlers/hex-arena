class_name MultiplayerInput
extends Node

var direction: Vector2
var ability: Util.Ability
var mouse_pos: Vector2

var camera_offset: Vector2

func _ready() -> void:
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		set_process(false)
		set_physics_process(false)
	
	var camera = get_viewport().get_camera_2d()
	camera_offset = camera.position - camera.get_viewport_rect().size / 2
	
	direction = Input.get_vector("left", "right", "up", "down")
	mouse_pos = get_viewport().get_mouse_position() + camera_offset

func _physics_process(delta: float) -> void:
	direction = Input.get_vector("left", "right", "up", "down")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_pos = event.global_position + camera_offset
	
	if get_multiplayer_authority() != multiplayer.get_unique_id():
		return
		
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
