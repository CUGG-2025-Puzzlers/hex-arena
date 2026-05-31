extends Node

signal lobby_action_failed(reason: String)
signal lobby_created(lobby: HLobby)
signal lobby_joined(lobby: HLobby)
signal lobby_hidden(lobby: HLobby)

const EosCredentials = preload("res://scripts/eos/EosCredentials.gd")

const BUCKET_ID := "hex_arena_duel_v1"
const MODE := "duel"
const DEFAULT_BUILD := "dev"

const ATTR_MODE := "MODE"
const ATTR_BUILD := "BUILD"
const ATTR_HOST_IP := "HOST_IP"
const ATTR_HOST_PORT := "HOST_PORT"
const ATTR_HOST_NAME := "HOST_NAME"

var current_lobby: HLobby
var is_host := false
var _is_busy := false
var _eos_ready := false

func _ready() -> void:
	if not MultiplayerManager.player_connected.is_connected(_on_player_connected):
		MultiplayerManager.player_connected.connect(_on_player_connected)

	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)
		
func _on_player_connected(_id, _info) -> void:
	if is_host and MultiplayerManager.players.size() >= 2:
		await hide_current_lobby_from_search()
	
func _on_server_disconnected(_id, _info) -> void:
	await cleanup_lobby()
	
func _on_connection_failed(_id, _info) -> void:
	await cleanup_lobby()
	
func _ensure_eos_ready(player_name: String) -> bool:
	if _eos_ready and HAuth.product_user_id:
		return true
			
	var credentials := HCredentials.new()
	credentials.product_name = EosCredentials.PRODUCT_NAME
	credentials.product_version = EosCredentials.PRODUCT_VERSION
	credentials.product_id = EosCredentials.PRODUCT_ID
	credentials.sandbox_id = EosCredentials.SANDBOX_ID
	credentials.deployment_id = EosCredentials.DEPLOYMENT_ID
	credentials.client_id = EosCredentials.CLIENT_ID
	credentials.client_secret = EosCredentials.CLIENT_SECRET
	credentials.encryption_key = EosCredentials.ENCRYPTION_KEY
		
	var setup_success := await HPlatform.setup_eos_async(credentials)
	if not setup_success:
		return false
	
	if not HAuth.product_user_id:
		var login_success := await HAuth.login_anonymous_async(player_name)
		if not login_success:
			return false
	
	_eos_ready = true
	return true
	
func create_lobby(player_name: String) -> bool:
	if _is_busy:
		return false
	
	_is_busy = true
	is_host = false
	
	var eos_ready := await _ensure_eos_ready(player_name)
	if not eos_ready:
		_is_busy = false
		lobby_action_failed.emit("EOS setup or login failed")
		return false
		
	var create_opts := EOS.Lobby.CreateLobbyOptions.new()
	create_opts.local_user_id = HAuth.product_user_id
	create_opts.bucket_id = BUCKET_ID
	create_opts.max_lobby_members = 2
	create_opts.permission_level = EOS.Lobby.LobbyPermissionLevel.PublicAdvertised
	create_opts.presence_enabled = true
	create_opts.allow_invites = false
	create_opts.enable_rtc_room = false
	
	var lobby: HLobby = await HLobbies.create_lobby_async(create_opts)
	if not lobby:
		_is_busy = false
		lobby_action_failed.emit("Failed to create lobby")
		return false
		
	var lobby_attributes_added := await _add_lobby_attributes(lobby, player_name)
	if not lobby_attributes_added:
		await lobby.destroy_async() # Destroy lobby if failed
		_is_busy = false
		lobby_action_failed.emit("Failed to add lobby attributes")
		return false
	
	var connection_attributes_added := await _add_connection_attributes(lobby)
	if not connection_attributes_added:
		await lobby.destroy_async() # Destroy lobby if failed
		_is_busy = false
		lobby_action_failed.emit("Failed to add connection attributes")
		return false
	
	current_lobby = lobby
	is_host = true
	lobby_created.emit(lobby)
	
	_is_busy = false
	return true

func _add_lobby_attributes(lobby: HLobby, player_name: String) -> bool:
	var clean_name := player_name.strip_edges()
	
	if not lobby or not lobby.is_valid() or clean_name.is_empty():
		return false
	
	lobby.add_attribute(ATTR_HOST_NAME, player_name)
	lobby.add_attribute(ATTR_MODE, MODE)
	lobby.add_attribute(ATTR_BUILD, DEFAULT_BUILD)
	
	var result := await lobby.update_async()
	return result

# Change later to relevant build
func _get_build() -> String:
	return DEFAULT_BUILD

func _get_host_ip() -> String:
	if _is_usable_host_ip(MultiplayerManager.external_ip):
		return MultiplayerManager.external_ip
	
	if _is_usable_host_ip(MultiplayerManager.local_ip):
		return MultiplayerManager.local_ip
	
	for ip in IP.get_local_addresses():
		if _is_usable_host_ip(ip):
			return ip
	return ""

# Check if host ip can be used
func _is_usable_host_ip(ip: String) -> bool:
	if ip.is_empty() or not ip.is_valid_ip_address() or ip == "0.0.0.0" or ip.begins_with("169.254.") or ip.contains(":"):
		return false
	return true
	
func _add_connection_attributes(lobby: HLobby) -> bool:
	if not lobby or not lobby.is_valid():
		return false
		
	var ip := _get_host_ip()
	if ip == "":
		return false
	
	lobby.add_attribute(ATTR_HOST_IP, ip)
	lobby.add_attribute(ATTR_HOST_PORT, str(MultiplayerManager.DEFAULT_PORT))
	
	var result := await lobby.update_async()
	return result

func find_lobbies(player_name: String) -> Array[HLobby]:
	if _is_busy:
		return []
	
	_is_busy = true
	
	var eos_ready := await _ensure_eos_ready(player_name)
	if not eos_ready:
		_is_busy = false
		lobby_action_failed.emit("EOS setup or login failed")
		return []
		
	var lobbies = await HLobbies.search_by_bucket_id_async(BUCKET_ID)
	if lobbies == null:
		_is_busy = false
		lobby_action_failed.emit("Lobby search failed")
		return []
		
	if lobbies.is_empty():
		_is_busy = false
		lobby_action_failed.emit("No lobbies found")
		return []
		
	var joinable_lobbies := _filter_joinable_lobbies(lobbies)
	if joinable_lobbies.is_empty():
		_is_busy = false
		lobby_action_failed.emit("No joinable lobbies found")
		return []
	
	_is_busy = false
	return joinable_lobbies
	
func _filter_joinable_lobbies(lobbies: Array) -> Array[HLobby]:
	var joinable: Array[HLobby] = []
	var build := _get_build()
	
	for lobby: HLobby in lobbies:
		if not lobby or not lobby.is_valid():
			continue
		
		if lobby.available_slots <= 0:
			continue
			
		if lobby.owner_product_user_id == HAuth.product_user_id:
			continue
		
		if not _lobby_attribute_matches(lobby, ATTR_MODE, MODE):
			continue
		
		if not _lobby_attribute_matches(lobby, ATTR_BUILD, build):
			continue

		if not _has_valid_endpoint(lobby):
			continue
		
		joinable.append(lobby)
	return joinable

func _lobby_attribute_matches(lobby: HLobby, key: String, expected: String) -> bool:
	var attr = lobby.get_attribute(key)
	return attr and str(attr.value) == expected
	
func _has_valid_endpoint(lobby: HLobby) -> bool:
	var host_ip_attr = lobby.get_attribute(ATTR_HOST_IP)
	var host_port_attr = lobby.get_attribute(ATTR_HOST_PORT)

	if not host_ip_attr or not host_port_attr:
		return false

	var host_ip := str(host_ip_attr.value)
	var host_port := str(host_port_attr.value).to_int()

	return _is_usable_host_ip(host_ip) and host_port > 0 and host_port <= 65535

func join_lobby(lobby: HLobby, player_name: String) -> bool:
	if _is_busy == true:
		return false
	
	if not lobby or not lobby.is_valid():
		return false
	
	_is_busy = true
	
	var eos_ready := await _ensure_eos_ready(player_name)
	if not eos_ready:
		_is_busy = false
		lobby_action_failed.emit("EOS setup or login failed")
		return false
	
	var host_ip_attr = lobby.get_attribute(ATTR_HOST_IP)
	var host_port_attr = lobby.get_attribute(ATTR_HOST_PORT)
	
	if not host_ip_attr or not host_port_attr:
		_is_busy = false
		lobby_action_failed.emit("Lobby is missing connection info")
		return false
	
	var host_ip := str(host_ip_attr.value)
	var host_port := str(host_port_attr.value).to_int()
	
	if not _is_usable_host_ip(host_ip) or host_port <= 0 or host_port > 65535:
		_is_busy = false
		lobby_action_failed.emit("Lobby has invalid connection info")
		return false
	
	var joined_lobby: HLobby = await HLobbies.join_async(lobby)
	if not joined_lobby:
		_is_busy = false
		lobby_action_failed.emit("Failed to join lobby")
		return false

	current_lobby = joined_lobby
	is_host = false
	lobby_joined.emit(joined_lobby)

	MultiplayerManager.join_game(player_name, host_ip, host_port)

	_is_busy = false
	return true

func cleanup_lobby() -> void:
	if not current_lobby or not current_lobby.is_valid():
		current_lobby = null
		is_host = false
		return
	
	if is_host:
		await current_lobby.destroy_async()
	else:
		await current_lobby.leave_async()
	
	current_lobby = null
	is_host = false
	
	
func hide_current_lobby_from_search() -> bool:
	if not is_host or not current_lobby or not current_lobby.is_valid():
		return false

	if current_lobby.permission_level == EOS.Lobby.LobbyPermissionLevel.InviteOnly:
		return true

	current_lobby.permission_level = EOS.Lobby.LobbyPermissionLevel.InviteOnly
	var success := await current_lobby.update_async()

	if success:
		lobby_hidden.emit(current_lobby)

	return success

func get_lobby_host_name(lobby: HLobby) -> String:
	var attr = lobby.get_attribute(ATTR_HOST_NAME)

	if attr and str(attr.value).strip_edges():
		return str(attr.value)

	return "Unknown"

func get_lobby_endpoint(lobby: HLobby) -> String:
	var host_ip_attr = lobby.get_attribute(ATTR_HOST_IP)
	var host_port_attr = lobby.get_attribute(ATTR_HOST_PORT)

	if not host_ip_attr or not host_port_attr:
		return "Unknown"

	return "%s:%s" % [host_ip_attr.value, host_port_attr.value]
