extends CanvasLayer

# player ref
var player: CharacterBody2D = null

@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/HPBar
@onready var hp_label: Label = $MarginContainer/VBoxContainer/HPBar/Label
@onready var mana_bar: ProgressBar = $MarginContainer/VBoxContainer/ManaBar
@onready var mana_label: Label = $MarginContainer/VBoxContainer/ManaBar/Label
@onready var ability_container: HBoxContainer = $MarginContainer/VBoxContainer/AbilityContainer

@onready var passive_magic_label : Label = $MarginContainer/VBoxContainer/AbilityContainer/PassiveMagic/Label
@onready var light_magic_label : Label = $MarginContainer/VBoxContainer/AbilityContainer/LightMagic/Label
@onready var heavy_magic_label : Label = $MarginContainer/VBoxContainer/AbilityContainer/HeavyMagic/Label

# movement buffs:
@onready var move_ability_name: Label = $MarginContainer/VBoxContainer/AbilityContainer/MovementBuff/VBoxContainer/AbilityName
@onready var move_timer_label: Label = $MarginContainer/VBoxContainer/AbilityContainer/MovementBuff/VBoxContainer/TimerLabel
@onready var move_overlay: ColorRect = $MarginContainer/VBoxContainer/AbilityContainer/MovementBuff/CooldownOverlay

func _ready() -> void:
	# color this way bc easier to handle depletion
	_style_bar(hp_bar, Color(0.1, 0.8, 0.2), Color(0.15, 0.15, 0.15))
	_style_bar(mana_bar, Color(0.2, 0.4, 0.9), Color(0.15, 0.15, 0.15))

func update_cost_and_button_labels(magics: Dictionary) -> void:
	var passive_button : InputEventKey = InputMap.action_get_events("turn_to_passive")[0]
	var light_button : InputEventKey = InputMap.action_get_events("turn_to_light")[0]
	var heavy_button : InputEventKey = InputMap.action_get_events("turn_to_heavy")[0]

	var passive_magic : MagicStats = magics[Magic.MagicType.PASSIVE]
	var passive_input_text := OS.get_keycode_string(passive_button.physical_keycode)
	if passive_magic.magic_name in ["Razor Current", "Flow Circuit"]:
		passive_input_text = "AUTO"
	passive_magic_label.text = "%s\n%s\n%s" % [
		passive_input_text,
		passive_magic.magic_name,
		_format_magic_cost(passive_magic)
	]
	
	var light_magic : MagicStats = magics[Magic.MagicType.LIGHT]
	light_magic_label.text = "%s\n%s\n%s" % [
		OS.get_keycode_string(light_button.physical_keycode),
		light_magic.magic_name,
		_format_magic_cost(light_magic)
	]
	
	var heavy_magic : MagicStats = magics[Magic.MagicType.HEAVY]
	heavy_magic_label.text = "%s\n%s\n%s" % [
		OS.get_keycode_string(heavy_button.physical_keycode),
		heavy_magic.magic_name,
		_format_magic_cost(heavy_magic)
	]

func _format_magic_cost(magic_stats: MagicStats) -> String:
	if not magic_stats.cost_text.is_empty():
		return magic_stats.cost_text
	return "%d Mana" % magic_stats.cost

func connect_to_player(p: Player) -> void:
	player = p
	var player_preset: CharacterStats = player.preset
	var stats_update: StatsUpdate = player.stats_update
	
	stats_update.health_changed.connect(_on_health_changed)
	stats_update.mana_changed.connect(_on_mana_changed)
	
	update_cost_and_button_labels(player_preset.magics)
	
	_on_health_changed(stats_update.current_health, stats_update.max_health)
	_on_mana_changed(stats_update.current_mana, stats_update.max_mana)
	
	# connect movement ability
	var ability: AbilityBase = player.get_node("Ability")
	move_ability_name.text = ability.ability_name
	ability.cooldown_started.connect(_on_move_cooldown_started)
	ability.cooldown_updated.connect(_on_move_cooldown_updated)
	ability.cooldown_finished.connect(_on_move_cooldown_finished)

func _on_health_changed(current: float, maximum: float) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current
	hp_label.text = "%d / %d" % [ceili(current), ceili(maximum)]

func _on_mana_changed(current: float, maximum: float) -> void:
	mana_bar.max_value = maximum
	mana_bar.value = current
	mana_label.text = "%d / %d" % [ceili(current), ceili(maximum)]

func _on_move_cooldown_started(_duration: float) -> void:
	move_overlay.visible = true
	move_timer_label.visible = true

func _on_move_cooldown_updated(remaining: float, _duration: float) -> void:
	move_timer_label.text = "%0.1f" % remaining

func _on_move_cooldown_finished() -> void:
	move_overlay.visible = false
	move_timer_label.visible = false

# handling health and mana depleation
func _style_bar(bar: ProgressBar, fill_color: Color, bg_color: Color) -> void:
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = bg_color
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("background", bg_style)
