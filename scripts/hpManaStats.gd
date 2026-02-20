## emits signals (put in like a hud or something) 
## to react to change in mana and hp
class_name StatsComponent
extends Node

signal health_changed(current : float, maximum : float)
signal mana_changed(current : float, maximum : float)
signal deadgeLol

@export var max_health: float = 100.0
@export var max_mana: float = 100.0
@export var mana_regen_rate: float = 0.8  # /second

var current_health : float
var current_mana : float

func _ready() -> void:
	current_health = max_health
	current_mana = max_mana
	health_changed.emit(current_health, max_health)
	mana_changed.emit(current_mana, max_mana)
	
#########Health
func take_damage(amount: float) -> void:
	set_health(current_health - amount)
	if current_health <= 0.0:
		deadgeLol.emit()

func heal(amount: float) -> void:
	set_health(current_health + amount)

func set_health(value: float) -> void:
	current_health = clampf(value, 0.0, max_health)
	health_changed.emit(current_health, max_health)

##########Mana
func use_mana(amount: float) -> bool:
	if current_mana < amount:
		return false
	set_mana(current_mana - amount)
	return true
	
func _process(delta: float) -> void:
	# slowly regen mana
	if current_mana < max_mana:
		set_mana(current_mana + mana_regen_rate * delta)

func restore_mana(amount: float) -> void:
	set_mana(current_mana + amount)

func set_mana(value: float) -> void:
	current_mana = clampf(value, 0.0, max_mana)
	mana_changed.emit(current_mana, max_mana)
