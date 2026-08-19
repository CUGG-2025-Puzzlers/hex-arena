extends Control

@onready var winner_label: Label = %WinnerLabel
@onready var local_character_label: Label = %LocalCharacterLabel
@onready var opponent_character_label: Label = %OpponentCharacterLabel
@onready var stats_grid: GridContainer = %StatsGrid
@onready var match_time_label: Label = %MatchTimeLabel
@onready var stats_panel: Control = %StatsPanel
@onready var play_again_button: Button = %PlayAgainButton
@onready var main_menu_button: Button = %MainMenuButton

const DISPLAY_STATS := [
	["damage_dealt", "DAMAGE DEALT"],
	["damage_taken", "DAMAGE TAKEN"],
	["healing_done", "HEALING"],
	["magic_transformed", "MAGIC TRANSFORMED"],
	["mana_spent", "MANA SPENT"],
	["magic_placed", "MAGIC PLACED"],
	["magic_fired", "MAGIC FIRED"],
]


func _ready() -> void:
	MultiplayerManager.reset_character_selections()
	winner_label.text = "%s wins!" % SceneManager.winner_name
	play_again_button.pressed.connect(_on_play_again_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	_populate_match_stats()
	Telemetry.track("results_viewed")


func _populate_match_stats() -> void:
	var report := Telemetry.last_match_report
	var local: Dictionary = report.get("local", {})
	var opponent: Dictionary = report.get("opponent", {})
	if local.is_empty() or opponent.is_empty():
		stats_panel.hide()
		return

	local_character_label.text = str(local.get("character", "YOU")).to_upper()
	opponent_character_label.text = str(opponent.get("character", "OPPONENT")).to_upper()

	for row in DISPLAY_STATS:
		_add_stat_value(local.get(row[0], 0))
		_add_stat_name(row[1])
		_add_stat_value(opponent.get(row[0], 0))

	var seconds := int(round(float(report.get("match_duration_seconds", 0.0))))
	match_time_label.text = "MATCH TIME  %d:%02d" % [floori(seconds / 60.0), seconds % 60]


func _add_stat_value(value: Variant) -> void:
	var label := Label.new()
	label.theme_type_variation = &"HeadingLabel"
	label.custom_minimum_size = Vector2(210, 26)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = str(roundi(float(value)))
	stats_grid.add_child(label)


func _add_stat_name(text_value: String) -> void:
	var label := Label.new()
	label.theme_type_variation = &"MutedLabel"
	label.custom_minimum_size = Vector2(210, 26)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = text_value
	stats_grid.add_child(label)


func _on_play_again_pressed() -> void:
	Telemetry.track("play_again_selected")
	SceneManager.load_character_select()


func _on_main_menu_pressed() -> void:
	Telemetry.track("main_menu_selected_from_results")
	await LobbyMatchmakingManager.cleanup_lobby()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	MultiplayerManager.players.clear()
	MultiplayerManager.reset_character_select_mode()
	SceneManager.load_title_screen()
