
extends Control
class_name StatsUpdate


@export var OverheadHp: ProgressBar
@export var OverheadMana: ProgressBar
@export var NameLabel: Label

var max_health: float
var max_mana: float 
var mana_regen_rate: float  # /second

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
	mana_changed.connect(_on_overhead_mana_changed)
	_on_overhead_hp_changed.call_deferred(current_health, max_health)
	_on_overhead_mana_changed.call_deferred(current_mana, max_mana)

func update_name(new_name: String):
	NameLabel.text = new_name

func _on_overhead_hp_changed(current: float, maximum: float) -> void:
	if not OverheadHp:
		return

	OverheadHp.max_value = maximum
	OverheadHp.value = current

func _on_overhead_mana_changed(current: float, maximum: float) -> void:
	if not OverheadMana:
		return
	OverheadMana.max_value = maximum
	OverheadMana.value = current

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
