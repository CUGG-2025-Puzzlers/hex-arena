extends Node

signal player_connected(id, info)
signal player_disconnected(id)
signal server_disconnected

# Dictionary of players using IDs as keys
var players = {}

# Local player info
# Set these fields using some UI before creating/joining a game
var player_info = { "name" : "Local Player" }

#region Setup

# Port can be changed to be retrieved from some settings json
const DEFAULT_PORT = 6769
const SERVER_IP = "127.0.0.1"

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

# Creates a game that other players can connect to
# Creates a server with at the port specified in settings
# The user who creates the server is considered the 'host'
func create_game():
	print("Creating new game as host")
	
	var server_peer = ENetMultiplayerPeer.new()
	server_peer.create_server(DEFAULT_PORT)
	multiplayer.multiplayer_peer = server_peer
	
	players[1] = player_info
	player_connected.emit(1, player_info)

# Joins a game on the local network
# Connects to the local server using the specified port
func join_local_game():
	print("Joining game")
	
	var client_peer = ENetMultiplayerPeer.new()
	client_peer.create_client(SERVER_IP, DEFAULT_PORT)
	multiplayer.multiplayer_peer = client_peer

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

#endregion
