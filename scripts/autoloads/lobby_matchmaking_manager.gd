extends Node

signal lobby_action_failed(reason: String)
signal lobby_created(lobby: HLobby)
signal lobby_joined(lobby: HLobby)
signal lobby_hidden(lobby: HLobby)
signal quick_match_status(message: String)

const EosCredentials = preload("res://scripts/eos/EosCredentials.gd")

const BUCKET_ID := "hex_arena_duel_v1"
const MODE := "duel"
const DEFAULT_BUILD := "dev"

const ATTR_MODE := "MODE"
const ATTR_BUILD := "BUILD"
const ATTR_HOST_IP := "HOST_IP"
const ATTR_HOST_PORT := "HOST_PORT"
const ATTR_HOST_NAME := "HOST_NAME"
const ATTR_HOST_PUID := "HOST_PUID"
const ATTR_SOCKET_NAME := "SOCKET_NAME"
const ATTR_MATCH_TYPE := "MATCH_TYPE"
const ATTR_READY := "READY"
const ATTR_CREATED_AT := "CREATED_AT"

const MATCH_CUSTOM := "custom"
const MATCH_QUICK := "quick"

var current_lobby: HLobby
var is_host := false
var _is_busy := false
var _eos_ready := false

var _quick_match_active := false
var _quick_match_attempt := 0
var _pending_join_owner := ""
var _pending_join_socket := ""


func _ready() -> void:
	if not MultiplayerManager.player_connected.is_connected(_on_player_connected):
		MultiplayerManager.player_connected.connect(_on_player_connected)

	if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
		multiplayer.connected_to_server.connect(_on_connected_to_server)

	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

	if not multiplayer.connection_failed.is_connected(_on_connection_failed):
		multiplayer.connection_failed.connect(_on_connection_failed)


func _trace(stage: String, details: Dictionary = {}) -> void:
	print(
		"[MATCHMAKING][", stage, "] ",
		JSON.stringify(details)
	)


func _on_player_connected(id, info) -> void:
	_trace(
		"PLAYER_CONNECTED",
		{
			"peer_id": id,
			"player_name": str(info.get("name", "")),
			"is_host": is_host,
			"player_count": MultiplayerManager.players.size(),
		}
	)

	if is_host and MultiplayerManager.players.size() >= 2:
		Telemetry.mark_matchmaking_connected("host")
		_quick_match_active = false
		quick_match_status.emit("Opponent connected.")
		await hide_current_lobby_from_search()


func _on_connected_to_server() -> void:
	_trace(
		"P2P_CONNECTED",
		{
			"local_puid": str(HAuth.product_user_id),
			"host_puid": _pending_join_owner,
			"socket": _pending_join_socket,
		}
	)
	Telemetry.mark_matchmaking_connected("joiner")
	_quick_match_active = false
	quick_match_status.emit("Connected to opponent.")


func _on_server_disconnected() -> void:
	_trace("SERVER_DISCONNECTED")
	_quick_match_active = false
	await cleanup_lobby()


func _on_connection_failed() -> void:
	var reason := (
		"EOS P2P connection failed. Host %s was not listening on socket %s."
		% [_pending_join_owner, _pending_join_socket]
	)

	_trace(
		"P2P_CONNECTION_FAILED",
		{
			"local_puid": str(HAuth.product_user_id),
			"host_puid": _pending_join_owner,
			"socket": _pending_join_socket,
			"quick_match": _quick_match_active,
		}
	)

	Telemetry.track(
		"matchmaking_connection_failed",
		{
			"host_puid": _pending_join_owner,
			"socket": _pending_join_socket,
		}
	)

	_quick_match_active = false
	_is_busy = false
	await cleanup_lobby()
	lobby_action_failed.emit(reason)


func _ensure_eos_ready(player_name: String) -> bool:
	_trace(
		"EOS_READY_CHECK",
		{
			"cached_ready": _eos_ready,
			"existing_puid": str(HAuth.product_user_id),
			"player_name": player_name,
		}
	)

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

	_trace("EOS_PLATFORM_SETUP_BEGIN")
	var setup_success := await HPlatform.setup_eos_async(credentials)
	_trace("EOS_PLATFORM_SETUP_END", {"success": setup_success})

	if not setup_success:
		return false

	if not HAuth.product_user_id:
		_trace("EOS_LOGIN_BEGIN")
		var login_success := await HAuth.login_anonymous_async(player_name)
		_trace(
			"EOS_LOGIN_END",
			{
				"success": login_success,
				"puid": str(HAuth.product_user_id),
			}
		)

		if not login_success:
			return false

	if not HAuth.product_user_id:
		lobby_action_failed.emit(
			"EOS login succeeded but Product User ID is missing."
		)
		return false

	var eosg_local_id := str(EOSGMultiplayerPeer.get_local_user_id())
	if eosg_local_id.is_empty():
		lobby_action_failed.emit(
			"EOSG has no local user ID after login."
		)
		return false

	_trace(
		"EOS_READY",
		{
			"hauth_puid": str(HAuth.product_user_id),
			"eosg_local_id": eosg_local_id,
			"ids_match": str(HAuth.product_user_id) == eosg_local_id,
		}
	)

	_eos_ready = true
	return true


func create_lobby(
	player_name: String,
	match_type: String = MATCH_CUSTOM
) -> bool:
	if _is_busy:
		_trace("CREATE_REJECTED_BUSY")
		return false

	_is_busy = true
	is_host = false

	var eos_ready := await _ensure_eos_ready(player_name)
	if not eos_ready:
		_is_busy = false
		lobby_action_failed.emit("EOS setup or login failed.")
		return false

	var socket_name := _make_socket_name()

	# Keep the lobby invisible until the P2P server exists and its attributes
	# have been committed. This prevents clients from racing a half-created host.
	var create_opts := EOS.Lobby.CreateLobbyOptions.new()
	create_opts.local_user_id = HAuth.product_user_id
	create_opts.bucket_id = BUCKET_ID
	create_opts.max_lobby_members = 2
	create_opts.permission_level = (
		EOS.Lobby.LobbyPermissionLevel.InviteOnly
	)
	create_opts.presence_enabled = true
	create_opts.allow_invites = true
	create_opts.enable_rtc_room = false

	_trace(
		"LOBBY_CREATE_BEGIN",
		{
			"local_puid": str(HAuth.product_user_id),
			"match_type": match_type,
			"socket": socket_name,
			"permission": "InviteOnly",
		}
	)

	var lobby: HLobby = await HLobbies.create_lobby_async(create_opts)
	if not lobby:
		_is_busy = false
		lobby_action_failed.emit("Failed to create lobby.")
		return false

	current_lobby = lobby
	is_host = true

	var attributes_added := await _add_lobby_attributes(
		lobby,
		player_name,
		match_type,
		socket_name,
		false
	)
	if not attributes_added:
		await lobby.destroy_async()
		current_lobby = null
		is_host = false
		_is_busy = false
		lobby_action_failed.emit("Failed to add lobby attributes.")
		return false

	_trace(
		"P2P_SERVER_BEGIN",
		{
			"local_puid": str(HAuth.product_user_id),
			"socket": socket_name,
		}
	)

	var game_created := MultiplayerManager.create_eos_game(
		player_name,
		socket_name
	)
	if not game_created:
		await lobby.destroy_async()
		current_lobby = null
		is_host = false
		_is_busy = false
		lobby_action_failed.emit("Failed to create EOS P2P server.")
		return false

	# Give EOSG at least two polls before publishing the lobby.
	await get_tree().process_frame
	await get_tree().process_frame

	lobby.add_attribute(ATTR_READY, "1")
	lobby.permission_level = (
		EOS.Lobby.LobbyPermissionLevel.PublicAdvertised
	)

	var advertised := await lobby.update_async()
	if not advertised:
		var peer := multiplayer.multiplayer_peer
		if peer != null:
			peer.close()
		multiplayer.multiplayer_peer = null
		await lobby.destroy_async()
		current_lobby = null
		is_host = false
		_is_busy = false
		lobby_action_failed.emit("Failed to advertise ready lobby.")
		return false

	_trace(
		"LOBBY_READY",
		_describe_lobby(lobby)
	)

	lobby_created.emit(lobby)
	if match_type == MATCH_QUICK:
		quick_match_status.emit("Waiting for an opponent…")

	_is_busy = false
	return true


func _add_lobby_attributes(
	lobby: HLobby,
	player_name: String,
	match_type: String,
	socket_name: String,
	ready: bool
) -> bool:
	var clean_name := player_name.strip_edges()

	if not lobby or not lobby.is_valid() or clean_name.is_empty():
		return false

	lobby.add_attribute(ATTR_HOST_NAME, clean_name)
	lobby.add_attribute(ATTR_HOST_PUID, str(HAuth.product_user_id))
	lobby.add_attribute(ATTR_MODE, MODE)
	lobby.add_attribute(ATTR_BUILD, _get_build())
	lobby.add_attribute(ATTR_SOCKET_NAME, socket_name)
	lobby.add_attribute(ATTR_MATCH_TYPE, match_type)
	lobby.add_attribute(ATTR_READY, "1" if ready else "0")
	lobby.add_attribute(
		ATTR_CREATED_AT,
		str(int(Time.get_unix_time_from_system()))
	)

	var result := await lobby.update_async()
	_trace(
		"LOBBY_ATTRIBUTES_UPDATED",
		{
			"success": result,
			"attributes": _describe_lobby(lobby),
		}
	)
	return result


func _make_socket_name() -> String:
	var ticks := str(Time.get_ticks_msec() % 1000000)
	var random_part := str(randi())

	# EOS socket names may contain only letters and numbers.
	# Underscores make EOSGSocket reject the name and return
	# ERR_CANT_CREATE from create_server().
	return ("HexArena%s%s" % [ticks, random_part]).left(32)


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


func _is_usable_host_ip(ip: String) -> bool:
	if (
		ip.is_empty()
		or not ip.is_valid_ip_address()
		or ip == "0.0.0.0"
		or ip.begins_with("169.254.")
		or ip.contains(":")
	):
		return false
	return true


func find_lobbies(player_name: String) -> Array[HLobby]:
	if _is_busy:
		return []

	_is_busy = true

	var eos_ready := await _ensure_eos_ready(player_name)
	if not eos_ready:
		_is_busy = false
		lobby_action_failed.emit("EOS setup or login failed.")
		return []

	var lobbies = await _search_bucket("CUSTOM_SEARCH")
	if lobbies == null:
		_is_busy = false
		lobby_action_failed.emit("Lobby search failed.")
		return []

	var joinable_lobbies := _filter_joinable_lobbies(
		lobbies,
		MATCH_CUSTOM
	)

	if joinable_lobbies.is_empty():
		_is_busy = false
		lobby_action_failed.emit("No joinable lobbies found.")
		return []

	_is_busy = false
	return joinable_lobbies


func _search_bucket(stage: String):
	_trace(
		stage + "_BEGIN",
		{
			"bucket": BUCKET_ID,
			"local_puid": str(HAuth.product_user_id),
		}
	)

	var lobbies = await HLobbies.search_by_bucket_id_async(BUCKET_ID)

	if lobbies == null:
		_trace(stage + "_END", {"result": "null"})
		return null

	_trace(
		stage + "_END",
		{
			"count": lobbies.size(),
			"lobbies": _describe_lobbies(lobbies),
		}
	)
	return lobbies


func _filter_joinable_lobbies(
	lobbies: Array,
	required_match_type: String = MATCH_CUSTOM
) -> Array[HLobby]:
	var joinable: Array[HLobby] = []
	var build := _get_build()

	for lobby: HLobby in lobbies:
		var reason := _get_lobby_rejection_reason(
			lobby,
			required_match_type,
			build
		)

		if not reason.is_empty():
			_trace(
				"LOBBY_REJECTED",
				{
					"reason": reason,
					"lobby": _describe_lobby(lobby),
				}
			)
			continue

		_trace("LOBBY_ACCEPTED", _describe_lobby(lobby))
		joinable.append(lobby)

	return joinable


func _get_lobby_rejection_reason(
	lobby: HLobby,
	required_match_type: String,
	build: String
) -> String:
	if not lobby or not lobby.is_valid():
		return "invalid_lobby"

	if lobby.available_slots <= 0:
		return "full"

	var owner := str(lobby.owner_product_user_id)
	if owner.is_empty():
		return "missing_owner"

	if owner == str(HAuth.product_user_id):
		return "owned_by_local_user"

	if not _lobby_attribute_matches(lobby, ATTR_MODE, MODE):
		return "mode_mismatch"

	if not _lobby_attribute_matches(lobby, ATTR_BUILD, build):
		return "build_mismatch"

	if not _lobby_attribute_matches(
		lobby,
		ATTR_MATCH_TYPE,
		required_match_type
	):
		return "match_type_mismatch"

	if not _lobby_attribute_matches(lobby, ATTR_READY, "1"):
		return "host_not_ready_or_old_build"

	var socket_name := _get_lobby_attribute_string(
		lobby,
		ATTR_SOCKET_NAME
	)
	if socket_name.is_empty():
		return "missing_socket"

	var advertised_host := _get_lobby_attribute_string(
		lobby,
		ATTR_HOST_PUID
	)
	if advertised_host.is_empty():
		return "missing_host_puid"

	if advertised_host != owner:
		return "owner_host_puid_mismatch"

	return ""


func _lobby_attribute_matches(
	lobby: HLobby,
	key: String,
	expected: String
) -> bool:
	var attr = lobby.get_attribute(key)
	return attr and str(attr.value) == expected


func _get_lobby_attribute_string(
	lobby: HLobby,
	key: String
) -> String:
	if not lobby or not lobby.is_valid():
		return ""

	var attr = lobby.get_attribute(key)
	if not attr:
		return ""

	return str(attr.value)


func quick_match(player_name: String) -> bool:
	if _is_busy:
		_trace("QUICK_MATCH_REJECTED_BUSY")
		return false

	_quick_match_attempt += 1
	_quick_match_active = true
	_is_busy = true

	_trace(
		"QUICK_MATCH_BEGIN",
		{
			"attempt": _quick_match_attempt,
			"player_name": player_name,
		}
	)

	var eos_ready := await _ensure_eos_ready(player_name)
	if not eos_ready:
		_is_busy = false
		_quick_match_active = false
		lobby_action_failed.emit("EOS setup or login failed.")
		return false

	var lobbies = await _search_bucket("QUICK_SEARCH_1")
	var joinable: Array[HLobby] = []

	if lobbies != null:
		joinable = _filter_joinable_lobbies(
			lobbies,
			MATCH_QUICK
		)

	# The EOSG sample also searches twice with a random delay before hosting.
	# This reduces the chance that two players entering simultaneously both host.
	if joinable.is_empty():
		var retry_delay := randf_range(0.25, 1.25)
		quick_match_status.emit(
			"No opponent found. Rechecking in %.2f seconds…"
			% retry_delay
		)
		_trace(
			"QUICK_MATCH_RECHECK_DELAY",
			{"seconds": retry_delay}
		)
		_is_busy = false
		await get_tree().create_timer(retry_delay).timeout
		_is_busy = true

		lobbies = await _search_bucket("QUICK_SEARCH_2")
		if lobbies != null:
			joinable = _filter_joinable_lobbies(
				lobbies,
				MATCH_QUICK
			)

	_is_busy = false

	if not joinable.is_empty():
		var selected := joinable[0]
		quick_match_status.emit("Opponent found. Connecting…")
		Telemetry.track("matchmaking_match_found")
		_trace(
			"QUICK_MATCH_JOIN_SELECTED",
			_describe_lobby(selected)
		)
		return await join_lobby(selected, player_name)

	quick_match_status.emit("Creating a match. Waiting for an opponent…")
	Telemetry.track("matchmaking_host_created")
	_trace("QUICK_MATCH_HOSTING")
	return await create_lobby(player_name, MATCH_QUICK)


func join_lobby(lobby: HLobby, player_name: String) -> bool:
	if _is_busy:
		return false

	if not lobby or not lobby.is_valid():
		lobby_action_failed.emit("Selected lobby is invalid.")
		return false

	_is_busy = true

	var eos_ready := await _ensure_eos_ready(player_name)
	if not eos_ready:
		_is_busy = false
		lobby_action_failed.emit("EOS setup or login failed.")
		return false

	var host_product_user_id = lobby.owner_product_user_id
	var socket_name := _get_lobby_attribute_string(
		lobby,
		ATTR_SOCKET_NAME
	)

	if not host_product_user_id:
		_is_busy = false
		lobby_action_failed.emit("Lobby is missing host user ID.")
		return false

	if socket_name.is_empty():
		_is_busy = false
		lobby_action_failed.emit("Lobby is missing EOS socket name.")
		return false

	_pending_join_owner = str(host_product_user_id)
	_pending_join_socket = socket_name

	_trace(
		"LOBBY_JOIN_BEGIN",
		{
			"local_puid": str(HAuth.product_user_id),
			"host_puid": _pending_join_owner,
			"socket": _pending_join_socket,
			"lobby": _describe_lobby(lobby),
		}
	)

	var joined_lobby: HLobby = await HLobbies.join_async(lobby)
	if not joined_lobby:
		_is_busy = false
		lobby_action_failed.emit("Failed to join EOS lobby.")
		return false

	current_lobby = joined_lobby
	is_host = false

	_trace(
		"LOBBY_JOINED_STARTING_P2P",
		_describe_lobby(joined_lobby)
	)

	var game_joined := MultiplayerManager.join_eos_game(
		player_name,
		host_product_user_id,
		socket_name
	)
	if not game_joined:
		await joined_lobby.leave_async()
		current_lobby = null
		_is_busy = false
		is_host = false
		lobby_action_failed.emit("Failed to create EOS P2P client.")
		return false

	lobby_joined.emit(joined_lobby)
	_is_busy = false
	return true


func cleanup_lobby() -> void:
	# Capture lobby state before closing the multiplayer peer. The peer closing
	# can update the game's player list, but EOS lobby membership is what decides
	# whether this client is the final member.
	var lobby := current_lobby
	var lobby_valid := lobby != null and lobby.is_valid()
	var member_count := lobby.members.size() if lobby_valid else 0
	var local_is_owner := (
		lobby_valid
		and str(lobby.owner_product_user_id)
		== str(HAuth.product_user_id)
	)
	var should_destroy := (
		lobby_valid
		and member_count <= 1
		and local_is_owner
	)

	_trace(
		"LOBBY_CLEANUP_BEGIN",
		{
			"member_count": member_count,
			"local_is_owner": local_is_owner,
			"should_destroy": should_destroy,
			"lobby": _describe_lobby(lobby),
		}
	)

	var peer := multiplayer.multiplayer_peer
	if peer != null:
		peer.close()
		multiplayer.multiplayer_peer = null

	if lobby_valid:
		if should_destroy:
			var destroyed = await lobby.destroy_async()
			_trace(
				"LOBBY_DESTROYED_ON_LAST_MEMBER_EXIT",
				{"success": bool(destroyed)}
			)
		else:
			var left = await lobby.leave_async()
			_trace(
				"LOBBY_LEFT",
				{
					"success": bool(left),
					"remaining_before_leave": maxi(
						member_count - 1,
						0
					),
				}
			)

	current_lobby = null
	is_host = false
	_is_busy = false
	_quick_match_active = false
	_pending_join_owner = ""
	_pending_join_socket = ""


func hide_current_lobby_from_search() -> bool:
	if not is_host or not current_lobby or not current_lobby.is_valid():
		return false

	if (
		current_lobby.permission_level
		== EOS.Lobby.LobbyPermissionLevel.InviteOnly
	):
		return true

	current_lobby.permission_level = (
		EOS.Lobby.LobbyPermissionLevel.InviteOnly
	)
	var success := await current_lobby.update_async()

	if success:
		lobby_hidden.emit(current_lobby)

	return success


func get_lobby_host_name(lobby: HLobby) -> String:
	var attr = lobby.get_attribute(ATTR_HOST_NAME)

	if attr and str(attr.value).strip_edges():
		return "%s's Lobby" % str(attr.value)

	return "Unknown Lobby"


func get_lobby_mode_label(lobby: HLobby) -> String:
	var attr = lobby.get_attribute(ATTR_MATCH_TYPE)
	if attr and str(attr.value) == MATCH_QUICK:
		return "Quick Match"
	return "Custom Duel"


func get_lobby_endpoint(lobby: HLobby) -> String:
	if not lobby or not lobby.is_valid():
		return "Unknown"

	var host_product_user_id = lobby.owner_product_user_id
	var socket_name := _get_lobby_attribute_string(
		lobby,
		ATTR_SOCKET_NAME
	)

	if not host_product_user_id:
		return "EOS P2P"

	return "EOS P2P / %s / %s" % [
		str(host_product_user_id),
		socket_name,
	]


func _describe_lobbies(lobbies: Array) -> Array:
	var descriptions: Array = []
	for lobby in lobbies:
		descriptions.append(_describe_lobby(lobby))
	return descriptions


func _describe_lobby(lobby: HLobby) -> Dictionary:
	if not lobby or not lobby.is_valid():
		return {"valid": false}

	return {
		"valid": true,
		"object_instance_id": lobby.get_instance_id(),
		"owner_puid": str(lobby.owner_product_user_id),
		"local_puid": str(HAuth.product_user_id),
		"available_slots": lobby.available_slots,
		"member_count": lobby.members.size(),
		"max_members": lobby.max_members,
		"host_name": _get_lobby_attribute_string(
			lobby,
			ATTR_HOST_NAME
		),
		"host_puid_attr": _get_lobby_attribute_string(
			lobby,
			ATTR_HOST_PUID
		),
		"mode": _get_lobby_attribute_string(lobby, ATTR_MODE),
		"build": _get_lobby_attribute_string(lobby, ATTR_BUILD),
		"match_type": _get_lobby_attribute_string(
			lobby,
			ATTR_MATCH_TYPE
		),
		"ready": _get_lobby_attribute_string(lobby, ATTR_READY),
		"socket": _get_lobby_attribute_string(
			lobby,
			ATTR_SOCKET_NAME
		),
		"created_at": _get_lobby_attribute_string(
			lobby,
			ATTR_CREATED_AT
		),
	}
