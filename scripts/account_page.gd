extends Node

@onready var _name_line_edit: LineEdit = %NameLineEdit
@onready var _name_error_label: Label = %NameErrorLabel
@onready var _level_label: Label = %LevelLabel
@onready var _xp_label: Label = %XPLabel
@onready var _back_button: Button = %BackButton
@onready var _save_button: Button = %SaveButton

func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_save_button.pressed.connect(_on_save_pressed)
	
	_name_line_edit.text = GameManager.player_name
	_level_label.text = str(GameManager.level)
	
	var xp_needed = 5 + (GameManager.level * 5)
	_xp_label.text = "%d / %d" % [GameManager.xp, xp_needed]
	
	_name_error_label.hide()

func _on_save_pressed() -> void:
	var player_name = _name_line_edit.text.strip_edges()
	
	if not GameManager.is_valid_name(player_name):
		_name_error_label.show()
		return
		
	_name_error_label.hide()
	GameManager.player_name = player_name
	GameManager.save_data()
	print("Account saved: ", GameManager.player_name)

func _on_back_pressed() -> void:
	SceneManager.load_title_screen()
