extends Control

@onready var winner_label: Label = %WinnerLabel
@onready var play_again_button: Button = %PlayAgainButton
@onready var main_menu_button: Button = %MainMenuButton


func _ready() -> void:
	MultiplayerManager.reset_character_selections()
	winner_label.text = "%s wins!" % SceneManager.winner_name
	play_again_button.pressed.connect(_on_play_again_pressed)
	main_menu_button.pressed.connect(_on_main_menu_pressed)
	Telemetry.track("results_viewed")


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
