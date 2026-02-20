extends Node

signal player_connected(id, info)
signal player_disconnected(id)
signal server_disconnected

# Dictionary of players using IDs as keys
var players = {}

var player_scene = preload("res://scenes/player.tscn")

var _players_spawn_node

# Local player info
# Set these fields using some UI before creating/joining a game
var player_info = { 
	"name" : "Local Player",
	"character" : Util.Character.None, 
}

#region Setup

# Port can be changed to be retrieved from some settings json
const DEFAULT_PORT = 6769
const SERVER_IP = "127.0.0.1"

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

# Creates a game that other players can connect to
# Creates a server with at the port specified in settings
# The user who creates the server is considered the 'host'
func create_game(player_name: String):
	print("Creating new game as host")
	
	var server_peer = ENetMultiplayerPeer.new()
	server_peer.create_server(DEFAULT_PORT, 2)
	multiplayer.multiplayer_peer = server_peer
	
	player_info["name"] = player_name
	players[1] = player_info
	player_connected.emit(1, player_info)
	
	SceneManager.load_character_select()

# Joins a game
# Attempts to connect to the server using the specified name, ip, and port
func join_game(player_name: String, ip: String, port: int):
	var client_peer = ENetMultiplayerPeer.new()
	var result = client_peer.create_client(ip, port)
	if result != OK:
		print("Failed to create client: %s" % result)
		return
	
	multiplayer.multiplayer_peer = client_peer
	
	player_info["name"] = player_name
	print("Attempting to connect to %s on port %d as %s" % [ip, port, player_name])

# Registers a player
# Adds a player to the players list
@rpc("any_peer", "reliable")
func _register_player(info):
	var id = multiplayer.get_remote_sender_id()
	players[id] = info
	player_connected.emit(id, info)

# Unregisters a player
# Removes a player from the player list
func _unregister_player(id):
	players.erase(id)
	player_disconnected.emit(id)

#endregion

#region Event Listeners

# Called on each client when a new player connects to the server
func _on_peer_connected(id: int):
	print("Player %s joined!" % id)
	
	# Register this client on the newly connected client
	_register_player.rpc_id(id, player_info)

# Called on each client when a player disconnects from the server
func _on_peer_disconnected(id: int):
	print("Player %s left..." % id)
	
	_unregister_player(id)

func _on_connected_to_server():
	print("Successfully connected to server!")
	players[multiplayer.get_unique_id()] = player_info
	SceneManager.load_character_select()

func _on_connection_failed():
	print("Failed to connect to server: Double-check IP, Port, and Firewall settings")

#endregion

# Sets a player's selected character
func set_player_character(player_id: int, character: Util.Character):
	if not player_id in players:
		return
	
	players[player_id].character = character
	_print_players()

# Prints out the players for debugging purposes
func _print_players():
	for player in players:
		if player == multiplayer.get_unique_id():
			print("*Local Client*")
		print("Name: %s\nSelected Character: %s\n" % [players[player].name, Util.Character.keys()[players[player].character]])

func _start_game():
	_players_spawn_node = get_tree().get_current_scene().get_node("Players")
	for player in players:
	
		var player_node = player_scene.instantiate()
		if player == 1:
			player_node.position.x += 200
			player_node.position.y += 200
		else:
			player_node.position.x -=200
			player_node.position.y -=200
		player_node.player_id = player
		player_node.name = str(player)
		_players_spawn_node.add_child(player_node, true)
