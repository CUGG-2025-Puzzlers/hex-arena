extends Control

@onready var _name_line_edit: LineEdit = %NameLineEdit
@onready var _name_error_label: Label = %NameErrorLabel
@onready var _level_label: Label = %LevelLabel
@onready var _xp_label: Label = %XPLabel
@onready var _status_label: Label = %StatusLabel
@onready var _back_button: Button = %BackButton
@onready var _save_button: Button = %SaveButton


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	_name_line_edit.text_submitted.connect(_on_name_submitted)

	_name_line_edit.text = GameManager.player_name
	_level_label.text = "Level %d" % GameManager.level
	var xp_needed := 5 + (GameManager.level * 5)
	_xp_label.text = "%d / %d XP" % [GameManager.xp, xp_needed]
	_name_error_label.hide()
	_status_label.text = ""
	Telemetry.track("account_viewed")


func _on_name_submitted(_new_text: String) -> void:
	_on_save_pressed()


func _on_save_pressed() -> void:
	var player_name := _name_line_edit.text.strip_edges()
	if not GameManager.is_valid_name(player_name):
		_name_error_label.show()
		_status_label.text = ""
		return

	_name_error_label.hide()
	GameManager.player_name = player_name
	MultiplayerManager.player_info["name"] = player_name
	GameManager.save_data()
	_status_label.text = "Account saved"
	Telemetry.track("account_saved")


func _on_back_pressed() -> void:
	SceneManager.load_title_screen()
