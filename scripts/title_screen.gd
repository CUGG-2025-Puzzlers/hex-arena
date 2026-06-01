extends Node

@onready var _bot_match_button: Button = %BotMatchButton
@onready var _host_game_button: Button = %HostGameButton
@onready var _join_game_button: Button = %JoinGameButton
@onready var _tutorial_button: Button = %TutorialButton
@onready var _account_button: Button = %AccountButton

@onready var _connect_button: Button = %ConnectButton
@onready var _back_button: Button = %BackButton

@onready var _main_panel: Panel = %MainPanel
@onready var _join_container: Container = %JoinContainer

@onready var _ip_line_edit: LineEdit = %IPLineEdit
@onready var _port_line_edit: LineEdit = %PortLineEdit

@onready var _name_error_label: Label = %NameErrorLabel
@onready var _ip_error_label: Label = %IPErrorLabel
@onready var _port_error_label: Label = %PortErrorLabel

#region Setup

func _ready() -> void:
	_bot_match_button.pressed.connect(_on_bot_match)
	_host_game_button.pressed.connect(_on_host_game)
	_join_game_button.pressed.connect(_on_join_game)
	_tutorial_button.pressed.connect(_on_start_tutorial)
	_account_button.pressed.connect(_on_account_pressed)
	_connect_button.pressed.connect(_on_connect)
	_back_button.pressed.connect(_on_back)
	
	_set_join_menu(false)
	_name_error_label.hide()
	
	_ip_line_edit.text = ""
	_port_line_edit.text = ""

#endregion

#region Button Callbacks

func _on_bot_match() -> void:
	SceneManager.load_bot_match()

# Creates a new game room
# Switches to the character select screen
func _on_host_game() -> void:
	if not GameManager.is_valid_name(GameManager.player_name):
		_name_error_label.show()
		return
	else:
		_name_error_label.hide()
	
	MultiplayerManager.create_game(GameManager.player_name)

func _on_start_tutorial() -> void:
	SceneManager.load_tutorial()

func _on_account_pressed() -> void:
	SceneManager.load_account_page()

# Opens up the join menu
func _on_join_game() -> void:
	if not GameManager.is_valid_name(GameManager.player_name):
		_name_error_label.show()
		return
	else:
		_name_error_label.hide()
		
	_set_join_menu(true)

# Joins an existing game room
# Switches to the character select screen
func _on_connect() -> void:
	var errors: int = 0
	
	# Get and validate IP address
	var ip: String = _ip_line_edit.text.strip_edges()
	if not ip:
		ip = MultiplayerManager.SERVER_IP
	
	if not ip.is_valid_ip_address():
		errors += 1
		_ip_error_label.show()
		print("Invalid IP Address: %s" % ip)
	else:
		_ip_error_label.hide()
	
	# Get and validate port number
	var port_string: String = _port_line_edit.text.strip_edges()
	var port: int = -1
	if not port_string:
		port = MultiplayerManager.DEFAULT_PORT
	elif not port_string.is_valid_int():
		errors += 1
		_port_error_label.show()
		print("Invalid Port: %s is not an integer" % port_string)
	else:
		port = port_string.to_int()
	
	if not _is_valid_port(port):
		errors += 1
		_port_error_label.show()
	else:
		_port_error_label.hide()
	
	# Don't attempt connection is errors are present
	if errors > 0:
		print("Fix %d error(s) before connecting..." % errors)
		return
	
	MultiplayerManager.join_game(GameManager.player_name, ip, port)

# Closes the join menu
func _on_back() -> void:
	_set_join_menu(false)

#endregion

# Toggles menu visibility
# Clears text and errors
func _set_join_menu(open: bool) -> void:
	_ip_line_edit.text = ""
	_port_line_edit.text = ""
	
	_ip_error_label.hide()
	_port_error_label.hide()
	
	_main_panel.visible = not open
	_join_container.visible = open

# Validates the given port
# Range: 1 - 65535 (inclusive)
func _is_valid_port(port: int) -> bool:
	if port > 0 and port <= 65535:
		return true
	
	print("Invalid Port Number: %d" % port)
	return false
