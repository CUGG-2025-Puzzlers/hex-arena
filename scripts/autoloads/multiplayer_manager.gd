extends Node

signal player_connected(id, info)
signal player_disconnected(id)
signal server_disconnected

enum CharacterSelectMode {
	ONLINE,
	BOT,
}

const BOT_PLAYER_ID := 999
var character_select_mode: CharacterSelectMode = CharacterSelectMode.ONLINE

# Dictionary of players using IDs as keys
var players = {}

var zilo = preload("res://scenes/characters/Zilo.tscn")
var hekaset = preload("res://scenes/characters/Hekaset.tscn")
var water_orb_a = preload("res://scenes/characters/WaterOrbA.tscn")
var water_orb_b = preload("res://scenes/characters/WaterOrbB.tscn")
var aurora = preload("res://scenes/characters/Aurora.tscn")

var bot_controller_script = preload("res://scripts/bot_controller.gd")

var _players_spawn_node
var arena_ready_peers: Dictionary = {}

# Local player info
# Set these fields using some UI before creating/joining a game
var player_info = {
	"name" : "Local Player",
	"character" : Util.Character.None,
}

#region Setup

# Port can be changed to be retrieved from some settings json
const DEFAULT_PORT = 6769
const EOS_SOCKET_NAME = "HexArenaDuel"
const SERVER_IP = "127.0.0.1"

var local_ip: String
var external_ip: String

var _active_transport := "none"
var _active_eos_socket := ""
var _active_eos_target := ""
var _connection_started_msec := 0
var _connection_trace_generation := 0

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)

	local_ip = _find_local_ipv4()


func _find_local_ipv4() -> String:
	var addresses: PackedStringArray = IP.get_local_addresses()

	for address: String in addresses:
		if not address.is_valid_ip_address():
			continue

		# Your current direct-connect UI expects IPv4.
		if address.contains(":"):
			continue

		if address.begins_with("127."):
			continue

		if address.begins_with("169.254."):
			continue

		if address == "0.0.0.0":
			continue

		return address

	return "127.0.0.1"
# Creates a game that other players can connect to
# Creates a server with at the port specified in settings
# The user who creates the server is considered the 'host'
func create_game(player_name: String):
	character_select_mode = CharacterSelectMode.ONLINE
	players.clear()
	arena_ready_peers.clear()
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

# EOS version of create_game
func create_eos_game(
	player_name: String,
	socket_name: String = EOS_SOCKET_NAME
) -> bool:
	character_select_mode = CharacterSelectMode.ONLINE
	players.clear()
	arena_ready_peers.clear()

	var local_puid := str(HAuth.product_user_id)
	print(
		"[NET][EOS][SERVER_CREATE] local_puid=", local_puid,
		" socket=", socket_name
	)

	var server_peer := EOSGMultiplayerPeer.new()

	if local_puid.is_empty():
		push_error("[NET][EOS][SERVER_CREATE] Missing Product User ID.")
		return false

	var result = server_peer.create_server(socket_name)
	print(
		"[NET][EOS][SERVER_CREATE_RESULT] code=", result,
		" name=", error_string(result),
		" status=", _connection_status_name(
			server_peer.get_connection_status()
		)
	)

	if result != OK:
		return false

	multiplayer.multiplayer_peer = server_peer
	_active_transport = "eos_server"
	_active_eos_socket = socket_name
	_active_eos_target = ""
	_connection_started_msec = Time.get_ticks_msec()

	player_info["name"] = player_name
	players[1] = player_info
	player_connected.emit(1, player_info)
	SceneManager.load_character_select()

	return true
	
# Joins a game
# Attempts to connect to the server using the specified name, ip, and port
func join_game(player_name: String, ip: String, port: int):
	character_select_mode = CharacterSelectMode.ONLINE
	players.clear()
	arena_ready_peers.clear()
	var client_peer = ENetMultiplayerPeer.new()
	var result = client_peer.create_client(ip, port)
	if result != OK:
		print("Failed to create client: %s" % result)
		return

	multiplayer.multiplayer_peer = client_peer

	player_info["name"] = player_name
	print("Attempting to connect to %s on port %d as %s" % [ip, port, player_name])
	
# EOS version of join_game
func join_eos_game(
	player_name: String,
	host_product_user_id,
	socket_name: String = EOS_SOCKET_NAME
) -> bool:
	character_select_mode = CharacterSelectMode.ONLINE
	players.clear()
	arena_ready_peers.clear()

	var local_puid := str(HAuth.product_user_id)
	var host_puid := str(host_product_user_id)
	var client_peer := EOSGMultiplayerPeer.new()

	print(
		"[NET][EOS][CLIENT_CREATE] local_puid=", local_puid,
		" host_puid=", host_puid,
		" same_user=", local_puid == host_puid,
		" socket=", socket_name,
		" player_name=", player_name
	)

	var result = client_peer.create_client(
		socket_name,
		host_product_user_id
	)

	print(
		"[NET][EOS][CLIENT_CREATE_RESULT] code=", result,
		" name=", error_string(result),
		" status=", _connection_status_name(
			client_peer.get_connection_status()
		)
	)

	if result != OK:
		return false

	multiplayer.multiplayer_peer = client_peer
	player_info["name"] = player_name
	_active_transport = "eos_client"
	_active_eos_socket = socket_name
	_active_eos_target = host_puid
	_connection_started_msec = Time.get_ticks_msec()
	_connection_trace_generation += 1
	_trace_connection_status(
		client_peer,
		_connection_trace_generation
	)

	return true

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
		upnp.add_port_mapping(DEFAULT_PORT, DEFAULT_PORT, "", "UDP")
	if not map_result_tcp == UPNP.UPNP_RESULT_SUCCESS:
		upnp.add_port_mapping(DEFAULT_PORT, DEFAULT_PORT, "", "TCP")

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
	var elapsed_ms := Time.get_ticks_msec() - _connection_started_msec
	print(
		"[NET][CONNECTED] transport=", _active_transport,
		" elapsed_ms=", elapsed_ms,
		" local_peer_id=", multiplayer.get_unique_id(),
		" eos_local_puid=", str(HAuth.product_user_id),
		" eos_target_puid=", _active_eos_target,
		" socket=", _active_eos_socket
	)

	players[multiplayer.get_unique_id()] = player_info
	SceneManager.load_character_select()


func _on_connection_failed():
	var elapsed_ms := Time.get_ticks_msec() - _connection_started_msec
	var peer := multiplayer.multiplayer_peer
	var status := MultiplayerPeer.CONNECTION_DISCONNECTED

	if peer != null:
		status = peer.get_connection_status()

	if _active_transport == "eos_client":
		push_error(
			"[NET][EOS][CONNECTION_FAILED] "
			+ "elapsed_ms=" + str(elapsed_ms)
			+ " local_puid=" + str(HAuth.product_user_id)
			+ " target_puid=" + _active_eos_target
			+ " socket=" + _active_eos_socket
			+ " peer_status=" + _connection_status_name(status)
			+ ". This is EOS P2P; IP and port are not involved."
		)
	else:
		push_error(
			"[NET][CONNECTION_FAILED] transport="
			+ _active_transport
			+ " elapsed_ms=" + str(elapsed_ms)
			+ " peer_status=" + _connection_status_name(status)
		)


func _trace_connection_status(
	peer: MultiplayerPeer,
	generation: int
) -> void:
	var deadline := Time.get_ticks_msec() + 15000
	var previous_status := -1

	while (
		generation == _connection_trace_generation
		and multiplayer.multiplayer_peer == peer
		and Time.get_ticks_msec() < deadline
	):
		var status := peer.get_connection_status()

		if status != previous_status:
			print(
				"[NET][EOS][STATUS] target_puid=", _active_eos_target,
				" socket=", _active_eos_socket,
				" status=", _connection_status_name(status),
				" elapsed_ms=",
				Time.get_ticks_msec() - _connection_started_msec
			)
			previous_status = status

		if status != MultiplayerPeer.CONNECTION_CONNECTING:
			return

		await get_tree().create_timer(0.25).timeout

	print(
		"[NET][EOS][STATUS_TRACE_END] target_puid=", _active_eos_target,
		" socket=", _active_eos_socket,
		" status=", _connection_status_name(
			peer.get_connection_status()
		)
	)


func _connection_status_name(status: int) -> String:
	match status:
		MultiplayerPeer.CONNECTION_DISCONNECTED:
			return "DISCONNECTED"
		MultiplayerPeer.CONNECTION_CONNECTING:
			return "CONNECTING"
		MultiplayerPeer.CONNECTION_CONNECTED:
			return "CONNECTED"
		_:
			return "UNKNOWN_%s" % status

#endregion

func begin_bot_character_select() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	character_select_mode = CharacterSelectMode.BOT
	player_info["character"] = Util.Character.None
	players.clear()
	players[1] = {
		"name": player_info.get("name", "Player"),
		"character": Util.Character.None,
		"is_bot": false,
	}
	players[BOT_PLAYER_ID] = {
		"name": "Training Bot",
		"character": Util.Character.None,
		"is_bot": true,
	}
	Telemetry.track("bot_character_select_opened")
	SceneManager.load_character_select()


func set_bot_match_character(player_id_to_set: int, character: Util.Character) -> void:
	if character_select_mode != CharacterSelectMode.BOT:
		return
	if player_id_to_set not in [1, BOT_PLAYER_ID]:
		return
	_set_player_character(player_id_to_set, character)
	Events.select_character(character, player_id_to_set)
	Telemetry.track("character_selected", {
		"mode": "bot",
		"slot": "player" if player_id_to_set == 1 else "bot",
		"character": Util.get_character_display_name(character),
	})


func reset_character_select_mode() -> void:
	if character_select_mode == CharacterSelectMode.BOT:
		players.clear()
		player_info["character"] = Util.Character.None
	character_select_mode = CharacterSelectMode.ONLINE


# Selects the given character for this player on all clients
func select_character(character: Util.Character):
	Telemetry.track("character_selected", {
		"mode": "online",
		"character": Util.get_character_display_name(character),
	})
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

	if multiplayer.has_multiplayer_peer():
		_end_game.rpc(winner_name)
	else:
		_end_game(winner_name)

@rpc("any_peer", "call_local", "reliable")
func _end_game(winner_name: String):
	Telemetry.end_match({
		"winner_name_present": not winner_name.is_empty(),
	})
	SceneManager.load_end_scene(winner_name)

func _start_game() -> void:
	_players_spawn_node = get_tree().get_current_scene().get_node("Players")
	var local_character: Util.Character = player_info.get(
		"character", Util.Character.None
	)
	Telemetry.start_match("online_1v1", {
		"character": Util.get_character_display_name(local_character),
	})

	var spawner: MultiplayerSpawner = (
		get_tree().get_current_scene().get_node("MultiplayerSpawner")
		as MultiplayerSpawner
	)
	spawner.spawn_function = Callable(self, "_spawn_player_from_data")

	# Every peer configures its local spawner before reporting ready.
	if multiplayer.is_server():
		_mark_arena_ready(multiplayer.get_unique_id())
	else:
		_report_arena_ready.rpc_id(1)


@rpc("any_peer", "reliable")
func _report_arena_ready() -> void:
	if not multiplayer.is_server():
		return

	var sender_id := multiplayer.get_remote_sender_id()
	if not players.has(sender_id):
		return

	_mark_arena_ready(sender_id)


func _mark_arena_ready(peer_id: int) -> void:
	arena_ready_peers[peer_id] = true

	if arena_ready_peers.size() < players.size():
		return

	_spawn_players()


func _spawn_players() -> void:
	if not multiplayer.is_server():
		return

	var spawner: MultiplayerSpawner = (
		get_tree().get_current_scene().get_node("MultiplayerSpawner")
		as MultiplayerSpawner
	)

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

		var player_node := spawner.spawn(spawn_data) as Player

		if player_node != null and player_node.stats_update != null:
			player_node.stats_update.deadgeLol.connect(
				_on_player_died.bind(player)
			)

	arena_ready_peers.clear()

func _start_bot_match():
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	var player_id := 1
	var bot_id := BOT_PLAYER_ID
	var player_character: Util.Character = players.get(
		player_id, {}
	).get("character", Util.Character.Hekaset)
	var bot_character: Util.Character = players.get(
		bot_id, {}
	).get("character", Util.Character.Hekaset)

	if player_character == Util.Character.None:
		player_character = Util.Character.Hekaset
	if bot_character == Util.Character.None:
		bot_character = Util.Character.Hekaset

	_players_spawn_node = get_tree().get_current_scene().get_node("Players")

	if _players_spawn_node != null:
		for child in _players_spawn_node.get_children():
			child.queue_free()

	await get_tree().process_frame

	players.clear()

	players[player_id] = {
		"name": player_info.get("name", "Player"),
		"character": player_character,
		"is_bot": false,
	}

	players[bot_id] = {
		"name": "Training Bot",
		"character": bot_character,
		"is_bot": true,
	}

	var player_spawn_data := {
		"id": player_id,
		"name": players[player_id].name,
		"character": player_character,
		"position": Vector2(200, 200),
		"is_bot": false,
	}

	var bot_spawn_data := {
		"id": bot_id,
		"name": players[bot_id].name,
		"character": bot_character,
		"position": Vector2(-200, -200),
		"is_bot": true,
	}

	var player_node := _spawn_player_from_data(player_spawn_data)
	var bot_node := _spawn_player_from_data(bot_spawn_data)

	_players_spawn_node.add_child(player_node)
	_players_spawn_node.add_child(bot_node)

	await get_tree().process_frame

	_setup_tutorial_camera_and_hud(player_node, bot_node)
	_setup_bot_controller(bot_node, player_node)
	Telemetry.start_match("bot", {
		"player_character": Util.get_character_display_name(player_character),
		"bot_character": Util.get_character_display_name(bot_character),
	})

	if player_node.stats_update != null:
		player_node.stats_update.deadgeLol.connect(_on_player_died.bind(player_id))

	if bot_node.stats_update != null:
		bot_node.stats_update.deadgeLol.connect(_on_player_died.bind(bot_id))

	print("[BOT MATCH] ready")

func _start_tutorial():
	var character = Util.Character.Hekaset
	Telemetry.start_match("tutorial", {
		"character": Util.get_character_display_name(character),
	})

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

	var player_node := _spawn_player_from_data(spawn_data)

	# Tutorial is local-only, so add it manually.
	# Do NOT use MultiplayerSpawner.spawn() here.
	_players_spawn_node.add_child(player_node)

	await get_tree().process_frame

	_setup_tutorial_camera_and_hud(player_node)

	if player_node.stats_update != null:
		player_node.stats_update.deadgeLol.connect(_on_tutorial_player_died)

func _on_tutorial_player_died() -> void:
	print("[TUTORIAL] player died")
	# Later: restart tutorial step, show prompt, reload tutorial, etc.

func _spawn_player_from_data(data: Dictionary) -> Player:
	print("[SPAWN FUNCTION] peer=", multiplayer.get_unique_id(), " data=", data)

	var player_node: Player
	var selected_character: Util.Character = data.get(
		"character",
		Util.Character.Zilo
	)

	match selected_character:
		Util.Character.Hekaset:
			player_node = hekaset.instantiate()
		Util.Character.WaterOrbA:
			player_node = water_orb_a.instantiate()
		Util.Character.WaterOrbB:
			player_node = water_orb_b.instantiate()
		Util.Character.Aurora:
			player_node = aurora.instantiate()
		_:
			player_node = zilo.instantiate()

	player_node.player_id = int(data["id"])
	player_node.name = str(data["id"])
	player_node.position = data.get("position", Vector2.ZERO)
	player_node.set_player_name(str(data.get("name", "Player")))
	player_node.add_to_group("player")

	# Server owns the actual player state.
	player_node.set_multiplayer_authority(1)

	# The owning client controls its input synchronizer.
	var input_sync := player_node.get_node_or_null("InputSynchronizer")
	if input_sync != null:
		if data.get("is_bot", false):
			input_sync.process_mode = Node.PROCESS_MODE_DISABLED
		else:
			input_sync.set_multiplayer_authority(int(data["id"]))

	return player_node

func _setup_bot_controller(bot_node: Player, target_player: Player) -> void:
	var bot_controller = bot_controller_script.new()

	bot_node.add_child(bot_controller)
	bot_controller.setup(bot_node, target_player, bot_node.player_id)

	print("[BOT MATCH] bot controller attached")

func _setup_tutorial_camera_and_hud(
	player_node: Player,
	opponent_node: Player = null
) -> void:
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
		if hud.has_method("connect_to_players"):
			hud.call("connect_to_players", player_node, opponent_node)
		else:
			hud.connect_to_player(player_node)
