extends Node

@onready var _host_game_button: Button = %HostGameButton
@onready var _join_game_button: Button = %JoinGameButton
@onready var _connect_button: Button = %ConnectButton
@onready var _back_button: Button = %BackButton

@onready var _main_panel: Panel = %MainPanel
@onready var _join_panel: Panel = %JoinPanel

@onready var _name_line_edit: LineEdit = %NameLineEdit
@onready var _ip_line_edit: LineEdit = %IPLineEdit
@onready var _port_line_edit: LineEdit = %PortLineEdit

@onready var _name_error_label: Label = %NameErrorLabel
@onready var _ip_error_label: Label = %IPErrorLabel
@onready var _port_error_label: Label = %PortErrorLabel

#region Setup

func _ready() -> void:
	_host_game_button.pressed.connect(_on_host_game)
	_join_game_button.pressed.connect(_on_join_game)
	_connect_button.pressed.connect(_on_connect)
	_back_button.pressed.connect(_on_back)
	
	_set_join_menu(false)
	
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
	var errors: int = 0
	
	# Get and validate player name
	var player_name: String = _name_line_edit.text.strip_edges()
	if not _is_valid_name(player_name):
		errors += 1
		_name_error_label.show()
	else:
		_name_error_label.hide()
	
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
	
	print("Attempting to connect to %s on port %s..." % [ip, port])
	MultiplayerManager.join_game(ip, port)

# Closes the join menu
func _on_back() -> void:
	_set_join_menu(false)

#endregion

# Toggles menu visibility
# Clears text and errors
func _set_join_menu(open: bool) -> void:
	_name_line_edit.text = ""
	_ip_line_edit.text = ""
	_port_line_edit.text = ""
	
	_name_error_label.hide()
	_ip_error_label.hide()
	_port_error_label.hide()
	
	_main_panel.visible = not open
	_join_panel.visible = open

# Validates the given name
# Length: 2 - 16 characters
# Characters: Uppercase and Lowercase letters only
func _is_valid_name(player_name: String) -> bool:
	if player_name.length() < 2 || player_name.length() > 16:
		print("Invalid Name Length: %d" % player_name.length())
		return false
	
	var name_regex = RegEx.create_from_string("^[a-zA-Z]{2,16}$")
	if name_regex.search(player_name):
		return true
	
	print("Invalid Name: %s does not match regex pattern %s" % [player_name, name_regex.get_pattern()])
	return false

# Validates the given port
# Range: 1 - 65535 (inclusive)
func _is_valid_port(port: int) -> bool:
	if port > 0 and port <= 65535:
		return true
	
	print("Invalid Port Number: %d" % port)
	return false
