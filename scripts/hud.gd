extends CanvasLayer

# player ref
var player: CharacterBody2D = null

@onready var hp_bar: ProgressBar = $MarginContainer/VBoxContainer/HPBar
@onready var hp_label: Label = $MarginContainer/VBoxContainer/HPBar/Label
@onready var mana_bar: ProgressBar = $MarginContainer/VBoxContainer/ManaBar
@onready var mana_label: Label = $MarginContainer/VBoxContainer/ManaBar/Label
@onready var ability_container: HBoxContainer = $MarginContainer/VBoxContainer/AbilityContainer

func _ready() -> void:
	# color this way bc easier to handle depletion
	_style_bar(hp_bar, Color(0.1, 0.8, 0.2), Color(0.15, 0.15, 0.15))
	_style_bar(mana_bar, Color(0.2, 0.4, 0.9), Color(0.15, 0.15, 0.15))

func connect_to_player(p: CharacterBody2D) -> void:
	player = p
	var stats: StatsComponent = player.get_node("StatsComponent")
	stats.health_changed.connect(_on_health_changed)
	stats.mana_changed.connect(_on_mana_changed)

func _on_health_changed(current: float, maximum: float) -> void:
	hp_bar.max_value = maximum
	hp_bar.value = current
	hp_label.text = "%d / %d" % [ceili(current), ceili(maximum)]

func _on_mana_changed(current: float, maximum: float) -> void:
	mana_bar.max_value = maximum
	mana_bar.value = current
	mana_label.text = "%d / %d" % [ceili(current), ceili(maximum)]

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
