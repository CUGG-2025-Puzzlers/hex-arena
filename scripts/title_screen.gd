extends Node

@onready var _host_game_button: Button = %HostGameButton
@onready var _join_game_button: Button = %HostGameButton
@onready var _join_button: Button = %HostGameButton
@onready var _back_button: Button = %HostGameButton

@onready var _main_panel: Panel = %MainPanel
@onready var _join_panel: Panel = %JoinPanel

@onready var _ip_line_edit: LineEdit = %IPLineEdit
@onready var _port_line_edit: LineEdit = %PortLineEdit

#region Setup

func _ready() -> void:
	_host_game_button.pressed.connect(_on_host_game)
	_join_game_button.pressed.connect(_on_join_game)
	_join_button.pressed.connect(_on_connect)
	_back_button.pressed.connect(_on_back)
	
	_main_panel.visible = true
	_join_panel.visible = false
	
	_ip_line_edit.text = ""
	_port_line_edit.text = ""

#endregion

#region Button Callbacks

func _on_host_game():
	pass

func _on_join_game():
	pass

func _on_connect():
	pass

func _on_back():
	pass

#endregion
