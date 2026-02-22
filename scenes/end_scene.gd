extends Control

@onready var winner_label : Label = $VBoxContainer/WinnerLabel
@onready var play_again_btn : Button = $VBoxContainer/PlayAgainBtn

func _ready() -> void:
	MultiplayerManager.reset_character_selections()
	winner_label.text = "%s is the winner!" % SceneManager.winner_name
	play_again_btn.pressed.connect(_on_play_again_button_pressed)

func _on_play_again_button_pressed() -> void:
	SceneManager.load_character_select()
