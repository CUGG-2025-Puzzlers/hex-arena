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

# Creates a new game room
# Switches to the character select screen
func _on_host_game() -> void:
	pass

# Opens up the join menu
func _on_join_game() -> void:
	_set_join_menu(true)

# Joins an existing game room
# Switches to the character select screen
func _on_connect() -> void:
	pass

# Closes the join menu
func _on_back() -> void:
	_set_join_menu(false)

#endregion

func _set_join_menu(open: bool) -> void:
	_ip_line_edit.text = ""
	_port_line_edit.text = ""
	
	_main_panel.visible = not open
	_join_panel.visible = open
