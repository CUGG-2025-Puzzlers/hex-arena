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

func setup_upnp(_port: int):
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
	var _sender_is_local_client = sender_id == multiplayer.get_unique_id()
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
	print("[START_GAME] peer=", multiplayer.get_unique_id(), " is_server=", multiplayer.is_server())
	print("[START_GAME] scene=", get_tree().get_current_scene().name)

	var spawner: MultiplayerSpawner = get_tree().get_current_scene().get_node("MultiplayerSpawner")
	print("[SPAWNER CHECK] inside_tree=", spawner.is_inside_tree())
	print("[SPAWNER CHECK] has_peer=", multiplayer.has_multiplayer_peer())
	print("[SPAWNER CHECK] authority=", spawner.get_multiplayer_authority())
	print("[SPAWNER CHECK] is_authority=", spawner.is_multiplayer_authority())
	spawner.spawn_function = Callable(self, "_spawn_player_from_data")

	if not multiplayer.is_server():
		return

	for player in players:
		var spawn_position := Vector2.ZERO

		if player == 1:
			spawn_position = Vector2(200, 200)
		else:
			spawn_position = Vector2(-200, -200)

		var spawn_data := {
			"id": player,
			"name": players[player].name,
			"character": players[player].character,
			"position": spawn_position,
		}

		print("[SERVER SPAWN REQUEST] ", spawn_data)

		var player_node = spawner.spawn(spawn_data)

		if player_node != null:
			print("[SERVER SPAWNED] ", player_node.name, " path=", player_node.get_path())

			player_node.get_node("StatsComponent").deadgeLol.connect(
				_on_player_died.bind(player)
			)

func _start_tutorial():
	var character = Util.Character.Hekaset
	
	print("[START_TUTORIAL] scene=", get_tree().get_current_scene().name)

	_players_spawn_node = get_tree().get_current_scene().get_node("Players")

	# Clear old players/dummies from the tutorial scene.
	if not _players_spawn_node == null:
		for child in _players_spawn_node.get_children():
			child.queue_free()

	await get_tree().process_frame

	var tutorial_player_id := 1

	players.clear()
	players[tutorial_player_id] = {
		"name": "Hekaset",
		"character": character,
	}

	var spawn_data := {
		"id": tutorial_player_id,
		"name": "Hekaset",
		"character": character,
		"position": Vector2(0, 1450),
	}

	var player_node := _spawn_player_from_data(spawn_data) as Node2D

	# Tutorial is local-only, so add it manually.
	# Do NOT use MultiplayerSpawner.spawn() here.
	_players_spawn_node.add_child(player_node)

	await get_tree().process_frame

	_setup_tutorial_camera_and_hud(player_node)

	var stats = player_node.get_node_or_null("StatsComponent")
	
	if stats != null:
		stats.deadgeLol.connect(_on_tutorial_player_died)

func _on_tutorial_player_died() -> void:
	print("[TUTORIAL] player died")
	# Later: restart tutorial step, show prompt, reload tutorial, etc.

func _spawn_player_from_data(data: Dictionary) -> Node:
	print("[SPAWN FUNCTION] peer=", multiplayer.get_unique_id(), " data=", data)

	var player_node: Node2D

	if Util.Character.keys()[data["character"]] == "Hekaset":
		player_node = hekaset.instantiate()
	else:
		player_node = player_scene.instantiate()

	player_node.player_id = data["id"]
	player_node.name = str(data["id"])
	player_node.position = data["position"]
	player_node.set_player_name(data["name"])
	player_node.add_to_group("player")

	# Server owns the actual player state.
	player_node.set_multiplayer_authority(1)

	# The owning client controls its input synchronizer.
	var input_sync = player_node.get_node_or_null("InputSynchronizer")
	if input_sync != null:
		input_sync.set_multiplayer_authority(data["id"])
	else:
		push_warning("Missing InputSynchronizer on spawned player: " + str(player_node.name))

	return player_node

func _setup_tutorial_camera_and_hud(player_node: Node2D) -> void:
	var current_scene = get_tree().get_current_scene()

	player_node.z_index = 1

	var camera := current_scene.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.reparent(player_node)
		camera.position = Vector2.ZERO
		camera.make_current()

	var hud = current_scene.get_node_or_null("HUD")
	if hud != null:
		if not hud.is_node_ready():
			await hud.ready
		hud.connect_to_player(player_node)
