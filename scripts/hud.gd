extends CanvasLayer

const DEFAULT_Q_ICON := preload("res://assets/ui/icons/magic_q.svg")
const DEFAULT_E_ICON := preload("res://assets/ui/icons/magic_e.svg")
const DEFAULT_R_ICON := preload("res://assets/ui/icons/magic_r.svg")
const DEFAULT_SHIFT_ICON := preload("res://assets/ui/icons/shift_ability.svg")

var player: Player = null
var opponent: Player = null
var _ability: AbilityBase = null

@onready var player_name_label: Label = %PlayerNameLabel
@onready var player_hp_bar: ProgressBar = %PlayerHPBar
@onready var player_hp_label: Label = %PlayerHPLabel
@onready var player_mana_bar: ProgressBar = %PlayerManaBar
@onready var player_mana_label: Label = %PlayerManaLabel
@onready var player_status_label: Label = %PlayerStatusLabel

@onready var opponent_panel: PanelContainer = %OpponentPanel
@onready var opponent_name_label: Label = %OpponentNameLabel
@onready var opponent_hp_bar: ProgressBar = %OpponentHPBar
@onready var opponent_hp_label: Label = %OpponentHPLabel
@onready var opponent_mana_bar: ProgressBar = %OpponentManaBar
@onready var opponent_mana_label: Label = %OpponentManaLabel
@onready var opponent_status_label: Label = %OpponentStatusLabel

@onready var passive_magic_icon: TextureRect = %PassiveMagicIcon
@onready var passive_magic_key: Label = %PassiveMagicKey
@onready var passive_magic_name: Label = %PassiveMagicName
@onready var passive_magic_cost: Label = %PassiveMagicCost

@onready var light_magic_icon: TextureRect = %LightMagicIcon
@onready var light_magic_key: Label = %LightMagicKey
@onready var light_magic_name: Label = %LightMagicName
@onready var light_magic_cost: Label = %LightMagicCost

@onready var heavy_magic_icon: TextureRect = %HeavyMagicIcon
@onready var heavy_magic_key: Label = %HeavyMagicKey
@onready var heavy_magic_name: Label = %HeavyMagicName
@onready var heavy_magic_cost: Label = %HeavyMagicCost

@onready var move_ability_icon: TextureRect = %MovementAbilityIcon
@onready var move_ability_key: Label = %MovementAbilityKey
@onready var move_ability_name: Label = %MovementAbilityName
@onready var move_timer_label: Label = %MovementTimerLabel
@onready var move_overlay: ColorRect = %MovementCooldownOverlay


func _ready() -> void:
	_style_bar(player_hp_bar, Color(0.16, 0.78, 0.31), Color(0.08, 0.09, 0.12))
	_style_bar(player_mana_bar, Color(0.20, 0.48, 0.95), Color(0.08, 0.09, 0.12))
	_style_bar(opponent_hp_bar, Color(0.88, 0.28, 0.30), Color(0.08, 0.09, 0.12))
	_style_bar(opponent_mana_bar, Color(0.45, 0.35, 0.92), Color(0.08, 0.09, 0.12))
	move_overlay.hide()
	move_timer_label.hide()
	opponent_panel.hide()


func _process(_delta: float) -> void:
	player_status_label.text = _get_status_text(player)
	opponent_status_label.text = _get_status_text(opponent)


func connect_to_player(p: Player) -> void:
	var found_opponent: Player = null
	var players_node := p.get_parent()
	if players_node != null:
		for child: Node in players_node.get_children():
			if child is Player and child != p:
				found_opponent = child as Player
				break
	connect_to_players(p, found_opponent)


func connect_to_players(local_player: Player, remote_player: Player = null) -> void:
	_disconnect_existing_signals()
	player = local_player
	opponent = remote_player

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

	if opponent != null and opponent.stats_update != null:
		opponent_panel.show()
		opponent_name_label.text = opponent.display_name
		opponent.stats_update.health_changed.connect(_on_opponent_health_changed)
		opponent.stats_update.mana_changed.connect(_on_opponent_mana_changed)
		_on_opponent_health_changed(
			opponent.stats_update.current_health,
			opponent.stats_update.max_health
		)
		_on_opponent_mana_changed(
			opponent.stats_update.current_mana,
			opponent.stats_update.max_mana
		)
	else:
		opponent_panel.hide()


func update_cost_and_button_labels(magics: Dictionary) -> void:
	_set_magic_card(
		Magic.MagicType.PASSIVE,
		magics.get(Magic.MagicType.PASSIVE),
		passive_magic_icon,
		passive_magic_key,
		passive_magic_name,
		passive_magic_cost,
		"turn_to_passive",
		"Q",
		DEFAULT_Q_ICON
	)
	_set_magic_card(
		Magic.MagicType.LIGHT,
		magics.get(Magic.MagicType.LIGHT),
		light_magic_icon,
		light_magic_key,
		light_magic_name,
		light_magic_cost,
		"turn_to_light",
		"E",
		DEFAULT_E_ICON
	)
	_set_magic_card(
		Magic.MagicType.HEAVY,
		magics.get(Magic.MagicType.HEAVY),
		heavy_magic_icon,
		heavy_magic_key,
		heavy_magic_name,
		heavy_magic_cost,
		"turn_to_heavy",
		"R",
		DEFAULT_R_ICON
	)


func _set_magic_card(
	_magic_type: Magic.MagicType,
	magic_value: Variant,
	icon_node: TextureRect,
	key_node: Label,
	name_node: Label,
	cost_node: Label,
	action_name: String,
	fallback_key: String,
	fallback_icon: Texture2D
) -> void:
	var magic_stats := magic_value as MagicStats
	key_node.text = _get_action_key_text(action_name, fallback_key)
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
	cost_node.text = _format_magic_cost(magic_stats)

	if magic_stats.magic_name in ["Razor Current", "Flow Circuit"]:
		key_node.text = "AUTO"


func _format_magic_cost(magic_stats: MagicStats) -> String:
	if not magic_stats.cost_text.is_empty():
		return magic_stats.cost_text
	return "%d mana" % roundi(magic_stats.cost)


func _connect_ability(ability: AbilityBase) -> void:
	_ability = ability
	move_ability_key.text = _get_action_key_text("ability", "Shift")
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

	if opponent != null and opponent.stats_update != null:
		if opponent.stats_update.health_changed.is_connected(_on_opponent_health_changed):
			opponent.stats_update.health_changed.disconnect(_on_opponent_health_changed)
		if opponent.stats_update.mana_changed.is_connected(_on_opponent_mana_changed):
			opponent.stats_update.mana_changed.disconnect(_on_opponent_mana_changed)

	if _ability != null:
		if _ability.cooldown_started.is_connected(_on_move_cooldown_started):
			_ability.cooldown_started.disconnect(_on_move_cooldown_started)
		if _ability.cooldown_updated.is_connected(_on_move_cooldown_updated):
			_ability.cooldown_updated.disconnect(_on_move_cooldown_updated)
		if _ability.cooldown_finished.is_connected(_on_move_cooldown_finished):
			_ability.cooldown_finished.disconnect(_on_move_cooldown_finished)


func _get_action_key_text(action_name: String, fallback: String) -> String:
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			var keycode := key_event.physical_keycode
			if keycode == 0:
				keycode = key_event.keycode
			var key_text := OS.get_keycode_string(keycode)
			if not key_text.is_empty():
				return key_text
	return fallback


func _on_player_health_changed(current: float, maximum: float) -> void:
	player_hp_bar.max_value = maximum
	player_hp_bar.value = current
	player_hp_label.text = "HP  %d / %d" % [ceili(current), ceili(maximum)]


func _on_player_mana_changed(current: float, maximum: float) -> void:
	player_mana_bar.max_value = maximum
	player_mana_bar.value = current
	player_mana_label.text = "MANA  %d / %d" % [ceili(current), ceili(maximum)]


func _on_opponent_health_changed(current: float, maximum: float) -> void:
	opponent_hp_bar.max_value = maximum
	opponent_hp_bar.value = current
	opponent_hp_label.text = "HP  %d / %d" % [ceili(current), ceili(maximum)]


func _on_opponent_mana_changed(current: float, maximum: float) -> void:
	opponent_mana_bar.max_value = maximum
	opponent_mana_bar.value = current
	opponent_mana_label.text = "MANA  %d / %d" % [ceili(current), ceili(maximum)]


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
	bar.add_theme_stylebox_override("fill", fill_style)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = bg_color
	bg_style.border_width_left = 2
	bg_style.border_width_top = 2
	bg_style.border_width_right = 2
	bg_style.border_width_bottom = 2
	bg_style.border_color = Color(0.75, 0.69, 0.50, 0.65)
	bg_style.corner_radius_top_left = 6
	bg_style.corner_radius_top_right = 6
	bg_style.corner_radius_bottom_left = 6
	bg_style.corner_radius_bottom_right = 6
	bar.add_theme_stylebox_override("background", bg_style)
