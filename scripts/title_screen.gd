extends Node

@onready var _host_game_button: Button = %HostGameButton
@onready var _join_game_button: Button = %JoinGameButton
@onready var _create_lobby_button: Button = %CreateLobbyButton
@onready var _find_lobbies_button: Button = %FindLobbiesButton
@onready var _connect_button: Button = %ConnectButton
@onready var _back_button: Button = %BackButton
@onready var _lobbies_back_button: Button = %LobbiesBackButton
@onready var _refresh_button: Button = %RefreshButton

@onready var _main_panel: Panel = %MainPanel
@onready var _join_container: Container = %JoinContainer
@onready var _lobbies_container: Container = %LobbiesContainer
@onready var _lobbies_grid: GridContainer = %LobbiesGrid

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
	_create_lobby_button.pressed.connect(_on_create_lobby)
	_find_lobbies_button.pressed.connect(_on_find_lobbies)
	_connect_button.pressed.connect(_on_connect)
	_back_button.pressed.connect(_on_back)
	_lobbies_back_button.pressed.connect(_on_lobbies_back)
	_refresh_button.pressed.connect(_on_find_lobbies)
	
	_set_join_menu(false)
	_set_lobbies_menu(false)
	_name_error_label.hide()
	
	_ip_line_edit.text = ""
	_port_line_edit.text = ""

#endregion

#region Button Callbacks

# Creates a new game room
# Switches to the character select screen
func _on_host_game() -> void:
	var player_name: String = _name_line_edit.text.strip_edges()
	if not _is_valid_name(player_name):
		_name_error_label.show()
		return
	else:
		_name_error_label.hide()
	
	MultiplayerManager.create_game(player_name)

# Opens up the join menu
func _on_join_game() -> void:
	_set_join_menu(true)


func _on_create_lobby() -> void:
	var player_name: String = _name_line_edit.text.strip_edges()
	if not _is_valid_name(player_name):
		_name_error_label.show()
		return
	else:
		_name_error_label.hide()

	_set_menu_buttons_disabled(true)
	var success := await LobbyMatchmakingManager.create_lobby(player_name)
	if not success:
		_set_menu_buttons_disabled(false)
		return
	SceneManager.load_lobby_room()


func _on_find_lobbies() -> void:
	var player_name: String = _name_line_edit.text.strip_edges()
	if not _is_valid_name(player_name):
		_name_error_label.show()
		return
	else:
		_name_error_label.hide()

	_set_menu_buttons_disabled(true)
	var lobbies := await LobbyMatchmakingManager.find_lobbies(player_name)
	_set_menu_buttons_disabled(false)
	_show_lobby_results(lobbies)

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
	
	MultiplayerManager.join_game(player_name, ip, port)

# Closes the join menu
func _on_back() -> void:
	_set_join_menu(false)


func _on_lobbies_back() -> void:
	_set_lobbies_menu(false)

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


func _set_lobbies_menu(open: bool) -> void:
	_clear_lobby_results()
	_main_panel.visible = not open
	_lobbies_container.visible = open


func _set_menu_buttons_disabled(disabled: bool) -> void:
	_host_game_button.disabled = disabled
	_join_game_button.disabled = disabled
	_create_lobby_button.disabled = disabled
	_find_lobbies_button.disabled = disabled
	_connect_button.disabled = disabled
	_back_button.disabled = disabled
	_lobbies_back_button.disabled = disabled


func _show_lobby_results(lobbies: Array[HLobby]) -> void:
	_set_lobbies_menu(true)

	if lobbies.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No lobbies found"
		_lobbies_grid.add_child(empty_label)
		return

	for lobby in lobbies:
		var host_label := Label.new()
		host_label.text = LobbyMatchmakingManager.get_lobby_host_name(lobby)
		_lobbies_grid.add_child(host_label)

		var endpoint_label := Label.new()
		endpoint_label.text = LobbyMatchmakingManager.get_lobby_endpoint(lobby)
		_lobbies_grid.add_child(endpoint_label)

		var slots_label := Label.new()
		slots_label.text = "%s/%s" % [lobby.members.size(), lobby.max_members]
		_lobbies_grid.add_child(slots_label)

		var join_button := Button.new()
		join_button.text = "Join"
		join_button.pressed.connect(_on_lobby_join_pressed.bind(lobby))
		_lobbies_grid.add_child(join_button)


func _clear_lobby_results() -> void:
	for child in _lobbies_grid.get_children():
		if child.get_meta("header", false):
			continue
		child.queue_free()


func _on_lobby_join_pressed(lobby: HLobby) -> void:
	var player_name: String = _name_line_edit.text.strip_edges()
	_set_menu_buttons_disabled(true)
	var success := await LobbyMatchmakingManager.join_lobby(lobby, player_name)
	if not success:
		_set_menu_buttons_disabled(false)

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
