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
	var ip: String = _ip_line_edit.text.strip_edges()
	var port: int = _port_line_edit.text.strip_edges().to_int()
	
	if (not ip):
		ip = MultiplayerManager.SERVER_IP
	
	if (not port):
		port = MultiplayerManager.DEFAULT_PORT
	
	if (not ip.is_valid_ip_address()):
		# show ip error
		return
	
	if (port < 1 or port > 65535):
		# show port error
		return
	
	print("Attempting to connect to %s on port %s..." % [ip, port])
	MultiplayerManager.join_game(ip, port)

# Closes the join menu
func _on_back() -> void:
	_set_join_menu(false)

#endregion

func _set_join_menu(open: bool) -> void:
	_name_line_edit.text = ""
	_ip_line_edit.text = ""
	_port_line_edit.text = ""
	
	_name_error_label.hide()
	_ip_error_label.hide()
	_port_error_label.hide()
	
	_main_panel.visible = not open
	_join_panel.visible = open

func _is_valid_name(player_name: String) -> bool:
	if player_name.length() < 2 || player_name.length() > 16:
		print("Invalid Name Length: %d" % player_name.length())
		return false
	
	var name_regex = RegEx.create_from_string("^[a-zA-Z]{2,16}$")
	if name_regex.search(player_name):
		return true
	
	print("Invalid Name: %s does not match regex pattern %s" % [player_name, name_regex.get_pattern()])
	return false

func _is_valid_port(port: int) -> bool:
	if port > 0 and port < 65535:
		return true
	
	print("Invalid port number: %d" % port)
	return false
