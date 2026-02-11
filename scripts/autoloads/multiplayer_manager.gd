extends Node

#region Setup

# Port can be changed to be retrieved from some settings json
const DEFAULT_PORT = 6769
const SERVER_IP = "127.0.0.1"

# Creates a game that other players can connect to
# Creates a server with at the port specified in settings
# The user who creates the server is considered the 'host'
func create_game():
	print("Creating new game as host")
	
	var server_peer = ENetMultiplayerPeer.new()
	server_peer.create_server(DEFAULT_PORT)
	multiplayer.multiplayer_peer = server_peer
	
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

# Joins a game on the local network
# Connects to the local server using the specified port
func join_local_game():
	print("Joining game")

#endregion

#region Event Listeners

func _on_peer_connected(id: int):
	print("Player %s joined!" % id)

func _on_peer_disconnected(id: int):
	print("Player %s left..." % id)

#endregion
