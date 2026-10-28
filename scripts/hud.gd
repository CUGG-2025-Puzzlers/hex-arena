extends CanvasLayer

const DEFAULT_Q_ICON := preload("res://assets/ui/icons/magic_q.svg")
const DEFAULT_E_ICON := preload("res://assets/ui/icons/magic_e.svg")
const DEFAULT_R_ICON := preload("res://assets/ui/icons/magic_r.svg")
const DEFAULT_SHIFT_ICON := preload("res://assets/ui/icons/shift_ability.svg")

var player: Player = null
var _ability: AbilityBase = null
var _concede_dialog: ConfirmationDialog = null

@onready var player_hp_bar: ProgressBar = %PlayerHPBar
@onready var player_hp_label: Label = %PlayerHPLabel
@onready var player_mana_bar: ProgressBar = %PlayerManaBar
@onready var player_mana_label: Label = %PlayerManaLabel
@onready var player_status_label: Label = %PlayerStatusLabel

@onready var passive_magic_icon: TextureRect = %PassiveMagicIcon
@onready var passive_magic_name: Label = %PassiveMagicName
@onready var passive_magic_cost: Label = %PassiveMagicCost
@onready var light_magic_icon: TextureRect = %LightMagicIcon
@onready var light_magic_name: Label = %LightMagicName
@onready var light_magic_cost: Label = %LightMagicCost
@onready var heavy_magic_icon: TextureRect = %HeavyMagicIcon
@onready var heavy_magic_name: Label = %HeavyMagicName
@onready var heavy_magic_cost: Label = %HeavyMagicCost

@onready var move_ability_icon: TextureRect = %MovementAbilityIcon
@onready var move_ability_name: Label = %MovementAbilityName
@onready var move_timer_label: Label = %MovementTimerLabel
@onready var move_overlay: ColorRect = %MovementCooldownOverlay


func _ready() -> void:
	_style_bar(player_hp_bar, Color(0.16, 0.78, 0.31), Color(0.03, 0.03, 0.04))
	_style_bar(player_mana_bar, Color(0.20, 0.48, 0.95), Color(0.03, 0.03, 0.04))
	move_overlay.hide()
	move_timer_label.hide()
	_create_concede_dialog()


func _process(_delta: float) -> void:
	player_status_label.text = _get_status_text(player)


func _unhandled_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed("ui_cancel")
		and Telemetry.current_match_mode != ""
		and Telemetry.current_match_mode != "tutorial"
	):
		get_viewport().set_input_as_handled()
		_concede_dialog.popup_centered()


func connect_to_player(p: Player) -> void:
	connect_to_players(p)


func connect_to_players(local_player: Player, _remote_player: Player = null) -> void:
	_disconnect_existing_signals()
	player = local_player

	if player == null or player.stats_update == null or player.preset == null:
		return

	player.stats_update.health_changed.connect(_on_player_health_changed)
	player.stats_update.mana_changed.connect(_on_player_mana_changed)
	_on_player_health_changed(
		player.stats_update.current_health,
		player.stats_update.max_health
	)
	_on_player_mana_changed(
		player.stats_update.current_mana,
		player.stats_update.max_mana
	)

	update_cost_and_button_labels(player.preset.magics)
	_connect_ability(player.get_node_or_null("Ability") as AbilityBase)


func update_cost_and_button_labels(magics: Dictionary) -> void:
	_set_magic_card(
		magics.get(Magic.MagicType.PASSIVE),
		passive_magic_icon,
		passive_magic_name,
		passive_magic_cost,
		DEFAULT_Q_ICON
	)
	_set_magic_card(
		magics.get(Magic.MagicType.LIGHT),
		light_magic_icon,
		light_magic_name,
		light_magic_cost,
		DEFAULT_E_ICON
	)
	_set_magic_card(
		magics.get(Magic.MagicType.HEAVY),
		heavy_magic_icon,
		heavy_magic_name,
		heavy_magic_cost,
		DEFAULT_R_ICON
	)


func _set_magic_card(
	magic_value: Variant,
	icon_node: TextureRect,
	name_node: Label,
	cost_node: Label,
	fallback_icon: Texture2D
) -> void:
	var magic_stats := magic_value as MagicStats
	icon_node.texture = fallback_icon

	if magic_stats == null:
		name_node.text = "Unavailable"
		cost_node.text = "—"
		icon_node.modulate = Color(1, 1, 1, 0.35)
		return

	icon_node.modulate = Color.WHITE
	if magic_stats.icon != null:
		icon_node.texture = magic_stats.icon

	name_node.text = magic_stats.magic_name
	cost_node.text = (
		magic_stats.cost_text
		if not magic_stats.cost_text.is_empty()
		else "%d mana" % roundi(magic_stats.cost)
	)


func _connect_ability(ability: AbilityBase) -> void:
	_ability = ability
	move_ability_icon.texture = DEFAULT_SHIFT_ICON
	move_ability_name.text = "Ability"

	if _ability == null:
		return

	move_ability_name.text = _ability.ability_name.replace("_", " ").capitalize()
	if _ability.ability_icon != null:
		move_ability_icon.texture = _ability.ability_icon

	_ability.cooldown_started.connect(_on_move_cooldown_started)
	_ability.cooldown_updated.connect(_on_move_cooldown_updated)
	_ability.cooldown_finished.connect(_on_move_cooldown_finished)

	if _ability.is_on_cooldown:
		_on_move_cooldown_started(_ability.cooldown_duration)
		_on_move_cooldown_updated(
			_ability.cooldown_remaining,
			_ability.cooldown_duration
		)


func _disconnect_existing_signals() -> void:
	if player != null and player.stats_update != null:
		if player.stats_update.health_changed.is_connected(_on_player_health_changed):
			player.stats_update.health_changed.disconnect(_on_player_health_changed)
		if player.stats_update.mana_changed.is_connected(_on_player_mana_changed):
			player.stats_update.mana_changed.disconnect(_on_player_mana_changed)

	if _ability != null:
		if _ability.cooldown_started.is_connected(_on_move_cooldown_started):
			_ability.cooldown_started.disconnect(_on_move_cooldown_started)
		if _ability.cooldown_updated.is_connected(_on_move_cooldown_updated):
			_ability.cooldown_updated.disconnect(_on_move_cooldown_updated)
		if _ability.cooldown_finished.is_connected(_on_move_cooldown_finished):
			_ability.cooldown_finished.disconnect(_on_move_cooldown_finished)


func _on_player_health_changed(current: float, maximum: float) -> void:
	player_hp_bar.max_value = maximum
	player_hp_bar.value = current
	player_hp_label.text = "HP  %d / %d" % [ceili(current), ceili(maximum)]


func _on_player_mana_changed(current: float, maximum: float) -> void:
	player_mana_bar.max_value = maximum
	player_mana_bar.value = current
	player_mana_label.text = "MANA  %d / %d" % [ceili(current), ceili(maximum)]


func _on_move_cooldown_started(_duration: float) -> void:
	move_overlay.show()
	move_timer_label.show()


func _on_move_cooldown_updated(remaining: float, _duration: float) -> void:
	move_timer_label.text = "%0.1f" % maxf(remaining, 0.0)


func _on_move_cooldown_finished() -> void:
	move_overlay.hide()
	move_timer_label.hide()


func _get_status_text(target: Player) -> String:
	if target == null or not is_instance_valid(target):
		return ""

	var statuses: Array[String] = []
	if target.is_silenced():
		statuses.append("SILENCED")
	if target.is_rooted():
		statuses.append("ROOTED")
	if target.is_invulnerable():
		statuses.append("INVULNERABLE")
	return " • ".join(statuses)


func _style_bar(bar: ProgressBar, fill_color: Color, bg_color: Color) -> void:
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.corner_radius_top_left = 6
	fill_style.corner_radius_top_right = 6
	fill_style.corner_radius_bottom_left = 6
	fill_style.corner_radius_bottom_right = 6

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = bg_color
	bg_style.border_width_left = 2
	bg_style.border_width_top = 2
	bg_style.border_width_right = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0.01, 0.01, 0.015, 0.95)
	bg_style.corner_radius_top_left = 6
	bg_style.corner_radius_top_right = 6
	bg_style.corner_radius_bottom_left = 6
	bg_style.corner_radius_bottom_right = 6

	bar.add_theme_stylebox_override("fill", fill_style)
	bar.add_theme_stylebox_override("background", bg_style)


func _create_concede_dialog() -> void:
	_concede_dialog = ConfirmationDialog.new()
	_concede_dialog.title = "Concede"
	_concede_dialog.dialog_text = "Concede this duel?"
	_concede_dialog.ok_button_text = "CONCEDE"
	_concede_dialog.cancel_button_text = "CANCEL"
	_concede_dialog.confirmed.connect(MultiplayerManager.concede_match)
	add_child(_concede_dialog)
