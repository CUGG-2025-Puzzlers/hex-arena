
extends Control
class_name StatsUpdate


@export var OverheadHp : ProgressBar
@export var NameLabel : Label

var max_health: float
var max_mana: float 
var mana_regen_rate: float  # /second

## emits signals (put in like a hud or something) 
## to react to change in mana and hp

signal health_changed(current : float, maximum : float)
signal mana_changed(current : float, maximum : float)
signal deadgeLol


var current_health : float
var current_mana : float


func _ready() -> void:
	var player_preset: CharacterStats = get_parent().preset
	
	max_health = player_preset.max_health
	max_mana = player_preset.max_mana
	mana_regen_rate = player_preset.mana_regen_rate
	
	current_health = max_health
	current_mana = max_mana
	
	health_changed.connect(_on_overhead_hp_changed)
	_on_overhead_hp_changed.call_deferred(current_health, max_health)

func update_name(new_name: String):
	NameLabel.text = new_name

func _on_overhead_hp_changed(current: float, maximum: float) -> void:
	if not OverheadHp:
		return
		
	#print("Overhead HP update: ", current, " / ", maximum)
	OverheadHp.max_value = maximum
	OverheadHp.value = current

#==================== Health =====================
func take_damage(amount: float) -> void:
	set_health(current_health - amount)
	if current_health <= 0.0:
		deadgeLol.emit()

func heal(amount: float) -> void:
	set_health(current_health + amount)

func set_health(value: float) -> void:
	current_health = clampf(value, 0.0, max_health)
	health_changed.emit(current_health, max_health)

#==================== Mana =====================
func use_mana(amount: float) -> bool:
	if current_mana < amount:
		return false
	set_mana(current_mana - amount)
	return true

# Inert, call from outside
func _process(delta: float) -> void:
	# slowly regen mana
	if current_mana < max_mana:
		set_mana(current_mana + mana_regen_rate * delta)

func restore_mana(amount: float) -> void:
	set_mana(current_mana + amount)

func set_mana(value: float) -> void:
	current_mana = clampf(value, 0.0, max_mana)
	mana_changed.emit(current_mana, max_mana)

"""
# For testing damage, heal, mana use
func _unhandled_input(event: InputEvent) -> void:
	if %InputSynchronizer.get_multiplayer_authority() != player_id:
		return


	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_K:
			take_damage(10.0)
		elif event.keycode == KEY_L:
			heal(10.0)
		elif event.keycode == KEY_M:
			use_mana(20.0)
"""
