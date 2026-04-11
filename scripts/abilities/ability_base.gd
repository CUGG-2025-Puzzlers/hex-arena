extends Node

class_name AbilityBase

signal cooldown_started(duration : float)
signal cooldown_updated(remaining : float, duration : float)
signal cooldown_finished
signal ability_activated
signal ability_ended

@export var cooldown_duration : float = 250.0
@export var ability_name : String = "mobility_buff"
@export var input_action : String = ""

var is_on_cooldown: bool = false
var cooldown_remaining: float = 0.0
var is_active: bool = false 

# player reference
var player: CharacterBody2D

func _ready() -> void:
	player = get_parent()

func _is_local() -> bool:
	return player.player_id == player.multiplayer.get_unique_id()

func _process(delta: float) -> void:
	if is_on_cooldown:
		cooldown_remaining -= delta
		cooldown_updated.emit(cooldown_remaining, cooldown_duration)
		if cooldown_remaining <= 0.0:
			is_on_cooldown = false
			cooldown_remaining = 0.0
			cooldown_finished.emit()

func try_activate() -> bool:
	if is_on_cooldown or is_active:
		return false
	if not can_activate():
		return false
	_execute()
	ability_activated.emit()
	_start_cooldown()
	return true
	
func _start_cooldown() -> void:
	is_on_cooldown = true
	cooldown_remaining = cooldown_duration
	cooldown_started.emit(cooldown_duration)

func can_activate() -> bool:
	return true

func _execute() -> void:
	pass

func get_aim_direction() -> Vector2:
	var mouse_pos = %InputSynchronizer.mouse_pos
	return (mouse_pos - player.global_position).normalized()

func get_aim_distance() -> float:
	var mouse_pos = player.get_global_mouse_position()
	return player.global_position.distance_to(mouse_pos)
