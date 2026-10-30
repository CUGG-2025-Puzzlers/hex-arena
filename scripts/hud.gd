extends CanvasLayer

const DEFAULT_Q_ICON := preload("res://assets/ui/icons/hud_shield.svg")
const DEFAULT_E_ICON := preload("res://assets/ui/icons/hud_arrow.svg")
const DEFAULT_R_ICON := preload("res://assets/ui/icons/hud_spikes.svg")
const DEFAULT_SHIFT_ICON := preload("res://assets/ui/icons/hud_mobility.svg")
const FEEDBACK_OVERLAY := preload("res://scripts/feedback/hud_feedback_overlay.gd")

var player: Player = null
var _ability: AbilityBase = null
var _concede_dialog: ConfirmationDialog = null
var _last_feedback_state: String = ""
var _exiting: bool = false
var _feedback_overlay: Control

const FEEDBACK_READY := Color("8be3de")
const FEEDBACK_BLOCKED := Color("ff929a")

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
@onready var move_progress: ProgressBar = %MovementCooldownBar
@onready var move_state: Label = %MovementState
@onready var mana_ring: Control = %ManaRing
@onready var mana_percent: Label = %ManaPercent
@onready var portrait: TextureRect = %PlayerPortrait
@onready var hero_name: Label = %HeroName


func _ready() -> void:
	_style_bar(player_mana_bar, Color("82e7ff"), Color(0.03, 0.05, 0.08, 0.55))
	_style_bar(move_progress, Color("f2f6ff"), Color(0, 0, 0, 0))
	move_overlay.hide()
	move_timer_label.hide()
	_create_concede_dialog()
	_ignore_hud_mouse($PlayerMargin)
	_set_key_hint(%PassiveKey, "turn_to_passive")
	_set_key_hint(%LightKey, "turn_to_light")
	_set_key_hint(%HeavyKey, "turn_to_heavy")
	_set_key_hint(%MovementKey, "ability")
	_refresh_card_feedback()
	_feedback_overlay = FEEDBACK_OVERLAY.new()
	add_child(_feedback_overlay)
	Juice.settings_visibility_changed.connect(_sync_modal_input)
	var settings := Juice.settings_button(self, Vector2.ZERO, "FX")
	settings.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	settings.position = Vector2(get_viewport().get_visible_rect().size.x - 70, 24)
	settings.tooltip_text = "Sound & effects"


func _process(_delta: float) -> void:
	if is_instance_valid(_feedback_overlay):
		_feedback_overlay.ready_rect = move_ability_icon.get_global_rect()
	var status := _get_status_text(player) if is_instance_valid(player) else ""
	player_status_label.text = status
	var feedback_state := "%s:%s:%s" % [status, _input_lock_reason(), is_instance_valid(_ability) and _ability.is_active]
	if feedback_state != _last_feedback_state:
		_last_feedback_state = feedback_state
		_refresh_card_feedback()


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

	if not is_instance_valid(player) or player.stats_update == null or player.preset == null:
		portrait.texture = null
		hero_name.text = ""
		update_cost_and_button_labels({})
		_connect_ability(null)
		_on_player_health_changed(0.0, 0.0)
		_on_player_mana_changed(0.0, 0.0)
		_refresh_card_feedback()
		return

	_update_identity()
	player.stats_update.health_changed.connect(_on_player_health_changed)
	player.stats_update.mana_changed.connect(_on_player_mana_changed)
	_on_player_health_changed(
		player.stats_update.current_health,
		player.stats_update.max_health
	)
	player_hp_bar.call("reset_trail")
	_on_player_mana_changed(
		player.stats_update.current_mana,
		player.stats_update.max_mana
	)

	update_cost_and_button_labels(player.preset.magics)
	_connect_ability(player.get_node_or_null("Ability") as AbilityBase)
	_sync_modal_input()
	_refresh_card_feedback()


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
	if _ability.ability_icon != null and _ability.ability_icon.resource_path != "res://assets/ui/icons/shift_ability.svg":
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


func _disconnect_existing_signals(reset_visuals: bool = true) -> void:
	_set_player_ui_blocked(false)
	if reset_visuals:
		_on_move_cooldown_finished()
	if is_instance_valid(player) and is_instance_valid(player.stats_update):
		if player.stats_update.health_changed.is_connected(_on_player_health_changed):
			player.stats_update.health_changed.disconnect(_on_player_health_changed)
		if player.stats_update.mana_changed.is_connected(_on_player_mana_changed):
			player.stats_update.mana_changed.disconnect(_on_player_mana_changed)

	if is_instance_valid(_ability):
		if _ability.cooldown_started.is_connected(_on_move_cooldown_started):
			_ability.cooldown_started.disconnect(_on_move_cooldown_started)
		if _ability.cooldown_updated.is_connected(_on_move_cooldown_updated):
			_ability.cooldown_updated.disconnect(_on_move_cooldown_updated)
		if _ability.cooldown_finished.is_connected(_on_move_cooldown_finished):
			_ability.cooldown_finished.disconnect(_on_move_cooldown_finished)
	_ability = null


func _on_player_health_changed(current: float, maximum: float) -> void:
	var critical := maximum > 0.0 and current / maximum <= 0.25
	player_hp_bar.set("critical", critical)
	player_hp_bar.max_value = maximum
	player_hp_bar.value = current
	player_hp_label.text = "%d" % ceili(current)
	player_hp_label.modulate = FEEDBACK_BLOCKED if critical else Color.WHITE
	%PlayerHPMaxLabel.text = "/ %d" % ceili(maximum)


func _on_player_mana_changed(current: float, maximum: float) -> void:
	player_mana_bar.max_value = maximum
	player_mana_bar.value = current
	player_mana_label.text = "%d / %d MANA" % [ceili(current), ceili(maximum)]
	var fraction := clampf(current / maxf(maximum, 0.001), 0.0, 1.0)
	mana_ring.set("fraction", fraction)
	mana_percent.text = "%d%%" % roundi(fraction * 100.0)
	_refresh_card_feedback()


func _on_move_cooldown_started(_duration: float) -> void:
	move_overlay.show()
	move_timer_label.show()
	move_progress.value = 0.0
	_refresh_card_feedback()


func _on_move_cooldown_updated(remaining: float, duration: float) -> void:
	move_timer_label.text = "%0.1f" % maxf(remaining, 0.0)
	move_progress.value = clampf(1.0 - remaining / maxf(duration, 0.001), 0.0, 1.0)


func _on_move_cooldown_finished() -> void:
	move_overlay.hide()
	move_timer_label.hide()
	move_progress.value = 1.0
	_refresh_card_feedback()


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
	_concede_dialog.visibility_changed.connect(_sync_modal_input)
	add_child(_concede_dialog)


# UI focus stays local. The simulation and other peers keep running.
func _sync_modal_input() -> void:
	_set_player_ui_blocked(Juice.settings_open or (is_instance_valid(_concede_dialog) and _concede_dialog.visible))
	_refresh_card_feedback()


func _set_player_ui_blocked(blocked: bool) -> void:
	if not is_instance_valid(player):
		return
	var input_node := player.get_node_or_null("InputSynchronizer") as MultiplayerInput
	if input_node != null and input_node.is_multiplayer_authority():
		input_node.set_ui_input_blocked(blocked)


func _exit_tree() -> void:
	_exiting = true
	_disconnect_existing_signals(false)


func _input_lock_reason() -> String:
	if not is_instance_valid(player):
		return "UNAVAILABLE"
	if not player.is_alive:
		return "RESPAWNING"
	if Juice.settings_open or (is_instance_valid(_concede_dialog) and _concede_dialog.visible):
		return "MENU OPEN"
	if player.is_silenced():
		return "SILENCED"
	if player.is_gameplay_input_blocked():
		return "LOCKED"
	return ""


func _refresh_card_feedback() -> void:
	if _exiting or not is_node_ready():
		return
	var magics: Dictionary = {}
	var mana := 0.0
	if is_instance_valid(player) and player.preset != null and player.stats_update != null:
		magics = player.preset.magics
		mana = player.stats_update.current_mana
	var lock_reason := _input_lock_reason()
	_update_magic_feedback(magics.get(Magic.MagicType.PASSIVE) as MagicStats, mana, passive_magic_icon, %PassiveState, lock_reason)
	_update_magic_feedback(magics.get(Magic.MagicType.LIGHT) as MagicStats, mana, light_magic_icon, %LightState, lock_reason)
	_update_magic_feedback(magics.get(Magic.MagicType.HEAVY) as MagicStats, mana, heavy_magic_icon, %HeavyState, lock_reason)
	var state := lock_reason
	if state.is_empty():
		if not is_instance_valid(_ability):
			state = "UNAVAILABLE"
		elif _ability.is_on_cooldown:
			state = "RECHARGING"
		elif _ability.is_active:
			state = "ACTIVE"
		else:
			state = "READY"
	move_state.text = state
	move_state.modulate = Color.WHITE if state == "RECHARGING" else (FEEDBACK_READY if state == "READY" or state == "ACTIVE" else FEEDBACK_BLOCKED)
	move_ability_icon.modulate = Color.WHITE if state == "READY" or state == "ACTIVE" else Color(1, 1, 1, 0.4)


func _update_magic_feedback(stats: MagicStats, mana: float, icon: TextureRect, label: Label, lock_reason: String) -> void:
	var state := lock_reason
	if stats == null:
		state = "UNAVAILABLE"
	elif state.is_empty() and mana < stats.cost:
		state = "LOW MANA"
	# Cost availability does not promise a valid target, wire length, or placement.
	label.text = state
	label.modulate = FEEDBACK_BLOCKED
	icon.modulate = Color.WHITE if state.is_empty() else Color(1, 1, 1, 0.4)


func _ignore_hud_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_hud_mouse(child)


func _set_key_hint(label: Label, action: StringName) -> void:
	label.text = "—"
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
			label.text = OS.get_keycode_string(code).to_upper()
			break


func _update_identity() -> void:
	var key := player.preset.resource_path.get_file().get_basename().trim_suffix("_stats").to_lower()
	var portraits := {
		"hekaset": "res://assets/textures/hekaset_icon.png",
		"zilo": "res://assets/textures/zilo_icon.png",
		"waterorba": "res://assets/textures/water_orb/water_orb_razor_icon.png",
		"waterorbb": "res://assets/textures/water_orb/water_orb_flow_icon.png",
		"aurora": "res://assets/textures/aurora/aurora_icon.png",
	}
	portrait.texture = load(portraits[key]) as Texture2D if portraits.has(key) else null
	hero_name.text = key.to_upper() if not key.is_empty() else player.display_name.to_upper()
