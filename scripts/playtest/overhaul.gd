extends Node

signal settings_changed
var rules := PlaytestRules.new()
var session_enabled: bool = false
var result_text: String = ""
var result_team: int = -1
var local_peer_id: int = 1

func active() -> bool:
	return get_match() != null

func get_match() -> Node:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("PlaytestMatch") if scene != null else null

func team_for(id: int) -> int:
	if not session_enabled:
		return id
	return int(MultiplayerManager.players.get(id, {}).get("team_id", id))

func friendly(first: int, second: int) -> bool:
	if first <= 0 or second <= 0:
		return first == second
	return first == second or (session_enabled and team_for(first) == team_for(second))

func local_friendly(id: int) -> bool:
	var peer := multiplayer.multiplayer_peer
	if peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		local_peer_id = multiplayer.get_unique_id()
	return friendly(id, local_peer_id)

func accepts_input(id: int) -> bool:
	var match_node := get_match()
	return match_node == null or match_node.accepts_input(id)

func can_see(point: Vector2) -> bool:
	var match_node := get_match()
	return match_node == null or match_node.can_see(point)

func set_preset(value: int, limited: bool) -> void:
	if not multiplayer.is_server() or active():
		return
	if value == PlaytestRules.Preset.TEAM_OBJECTIVE and MultiplayerManager._active_transport.begins_with("eos"):
		return
	_sync_settings.rpc(clampi(value, 0, 2), limited)

@rpc("authority", "call_local", "reliable")
func _sync_settings(value: int, limited: bool) -> void:
	rules.preset = value as PlaytestRules.Preset
	rules.limited_vision = limited
	session_enabled = value != PlaytestRules.Preset.BASELINE
	settings_changed.emit()

func sync_to(id: int) -> void:
	if multiplayer.is_server():
		_sync_settings.rpc_id(id, rules.preset, rules.limited_vision)

func reset_for_legacy() -> void:
	session_enabled = false
	rules.preset = PlaytestRules.Preset.BASELINE

func spawn_position(team: int, slot: int) -> Vector2:
	return Vector2(-740.0 if team == 0 else 740.0, -120.0 if slot == 0 else 120.0)
