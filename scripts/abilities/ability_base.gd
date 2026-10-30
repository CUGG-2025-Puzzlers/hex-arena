extends Node

class_name AbilityBase

signal cooldown_started(duration : float)
signal cooldown_updated(remaining : float, duration : float)
signal cooldown_finished
signal ability_activated
signal ability_ended

@export var cooldown_duration : float = 250.0
@export var ability_name : String = "mobility_buff"
@export var ability_icon: Texture2D = preload("res://assets/ui/icons/shift_ability.svg")
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
			if is_instance_valid(player) and _is_local() and player.is_alive and not is_active and not player.is_gameplay_input_blocked():
				Juice.cue("ready")

func try_activate() -> bool:
	if is_on_cooldown or is_active or player.is_gameplay_input_blocked():
		if _is_local() and not player.get_node("InputSynchronizer").ui_input_blocked:
			Juice.cue("denied")
		return false
	if not can_activate():
		if _is_local():
			Juice.cue("denied")
		return false
	_execute()
	Telemetry.record_ability_cast(player.player_id, ability_name)
	ability_activated.emit()
	Juice.world("ability", player.global_position, player.player_id)
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

# Optional capability hooks. Character-specific abilities override only the
# behavior they actually need; Player does not need to know their class names.
func blocks_movement() -> bool:
	return false

func blocks_gameplay_input() -> bool:
	return false

func grants_invulnerability() -> bool:
	return false

func get_aim_direction() -> Vector2:
	var mouse_pos = %InputSynchronizer.mouse_pos
	return (mouse_pos - player.global_position).normalized()

func get_aim_distance() -> float:
	var mouse_pos = player.get_global_mouse_position()
	return player.global_position.distance_to(mouse_pos)


func reset_for_respawn() -> void:
	if self is DashAbility:
		(self as DashAbility).cancel_dash()
	if self is GhostAbility:
		(self as GhostAbility)._deactivate()
	if self is TeleportAbility:
		(self as TeleportAbility)._cleanup_channel()
	if self is PrismaticStillness:
		(self as PrismaticStillness)._set_visual(false)
	is_active = false
	is_on_cooldown = false
	cooldown_remaining = 0.0
	cooldown_finished.emit()
