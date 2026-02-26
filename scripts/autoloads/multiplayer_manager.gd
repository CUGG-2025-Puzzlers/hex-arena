extends Node

signal player_connected(id, info)
signal player_disconnected(id)
signal server_disconnected

# Dictionary of players using IDs as keys
var players = {}

var player_scene = preload("res://scenes/player.tscn")
var hekaset = preload("res://scenes/hekaset.tscn")

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

var local_ip: String
var external_ip: String

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	
	local_ip = IP.get_local_addresses()[-1]
	
	if local_ip == "fe80:0:0:0:0:0:0:1":
		local_ip = IP.get_local_addresses()[11]

# Creates a game that other players can connect to
# Creates a server with at the port specified in settings
# The user who creates the server is considered the 'host'
func create_game(player_name: String):
	print("Setting up port forwarding...")
	
	external_ip = setup_upnp(DEFAULT_PORT)
	if external_ip:
		print("External IP is [%s]" % external_ip)
	else:
		print("Could not setup port forwarding, manual setup required.")
	
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

func setup_upnp(port: int):
	var result = ""
	var upnp = UPNP.new()
	
	var discover_result = upnp.discover()
	if discover_result != UPNP.UPNPResult.UPNP_RESULT_SUCCESS:
		print("UPNP Discovery failed")
		return result
	
	print("UPNP Discovery succeeded")
	if upnp.get_device_count() == 0:
		print("No devices found")
		return result
	
	if not upnp.get_gateway():
		print("Could not get default gateway")
		return result
		
	if not upnp.get_gateway().is_valid_gateway():
		print("Default gateway is invalid")
		return result
	
	print("Default gateway is valid")
	var map_result_udp = upnp.add_port_mapping(DEFAULT_PORT, DEFAULT_PORT, "godot_udp", "UDP", 0)
	var map_result_tcp = upnp.add_port_mapping(DEFAULT_PORT, DEFAULT_PORT, "godot_tcp", "UDP", 0)
	
	if not map_result_udp == UPNP.UPNP_RESULT_SUCCESS:
		upnp.add_port_mappping(DEFAULT_PORT, DEFAULT_PORT, "", "UDP")
	if not map_result_tcp == UPNP.UPNP_RESULT_SUCCESS:
		upnp.add_port_mappping(DEFAULT_PORT, DEFAULT_PORT, "", "TCP")
	
	print("UPNP Port Forwarding succeeded")
	return upnp.query_external_address()
	
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

# Selects the given character for this player on all clients
func select_character(character: Util.Character):
	_set_character.rpc(character)

# Sets the sending client's selected character on this client
@rpc("call_local", "any_peer", "reliable")
func _set_character(character: Util.Character):
	var sender_id = multiplayer.get_remote_sender_id()
	var sender_is_local_client = sender_id == multiplayer.get_unique_id()
	print("%s selected %s" % [MultiplayerManager.players[sender_id].name, Util.Character.keys()[character]])
	_set_player_character(sender_id, character)
	Events.select_character(character, sender_id)

# Sets a player's selected character
func _set_player_character(player_id: int, character: Util.Character):
	if not player_id in players:
		return
	
	players[player_id].character = character

# Resets all players' selected character
func reset_character_selections():
	for player_id in players:
		players[player_id].character = Util.Character.None

# Returns the other player's info from the player dictionary
# Returns null if no other player is found
func get_other_player_info():
	for player_id in players:
		if player_id != multiplayer.get_unique_id():
			return players[player_id]
	
	return null

# Prints out the players for debugging purposes
func _print_players():
	for player in players:
		if player == multiplayer.get_unique_id():
			print("*Local Client*")
		print("Name: %s\nSelected Character: %s\n" % [players[player].name, Util.Character.keys()[players[player].character]])

func _on_player_died(dead_player_id : int) -> void:
	var winner_name = ""
	
	for id in players:
		if id != dead_player_id:
			winner_name = players[id].name
			break
	_end_game.rpc(winner_name)
	
@rpc("any_peer", "call_local", "reliable")
func _end_game(winner_name: String):
	SceneManager.load_end_scene(winner_name)

func _start_game():
	_players_spawn_node = get_tree().get_current_scene().get_node("Players")
	for player in players:
		var player_node
		
		if Util.Character.keys()[players[player].character] == "Hekaset":
			player_node = hekaset.instantiate()
		else: 
			player_node = player_scene.instantiate()
		
		# change spawn positions of each player
		if player == 1:
			player_node.position.x += 200
			player_node.position.y += 200
		else:
			player_node.position.x -= 200
			player_node.position.y -= 200

		player_node.player_id = player
		player_node.name = str(player)
		player_node.set_player_name(players[player].name)
		
		_players_spawn_node.add_child(player_node, true)
		
		# connecting camera, HUD, audio to local player only
		if player == multiplayer.get_unique_id():
			# Put in front of other objects, other player
			player_node.z_index = 1
			
			# Set camera as child to follow movement
			var camera : Camera2D = get_tree().get_current_scene().get_node("Camera2D")
			camera.reparent(player_node)
			camera.position=Vector2.ZERO
			
			# Connect hud to main player
			var hud = get_tree().get_current_scene().get_node("HUD")
			if not hud.is_node_ready():
				await hud.ready
			hud.connect_to_player(player_node)
			#hud.connect_to_player.call_deferred(player_node)
			
			# Set node to be main audio listener
			player_node.get_node("AudioListener2D").current = true
		
		player_node.get_node("StatsComponent").deadgeLol.connect(_on_player_died.bind(player))
