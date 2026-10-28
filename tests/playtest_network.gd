extends Node

var role: String
var port: int = 16769
var match_started: bool = false
var checked: bool = false
var generation: int = 0
var duration: float = 0.0
var round_ready: Dictionary = {}

func _ready() -> void:
	Telemetry.enabled = false
	var args := OS.get_cmdline_user_args()
	role = args[0] if not args.is_empty() else "host"
	if args.size() > 1:
		port = int(args[1])
	var peer := ENetMultiplayerPeer.new()
	if role == "host":
		assert(peer.create_server(port, 3) == OK)
		multiplayer.multiplayer_peer = peer
		Overhaul.set_preset(PlaytestRules.Preset.TEAM_OBJECTIVE, true)
		MultiplayerManager.players[1] = {"name": "Host", "character": Util.Character.Hekaset}
		MultiplayerManager.player_info = MultiplayerManager.players[1]
	else:
		# Manager's normal connection handler opens selection. The test switches
		# scenes only after four selected players are registered on the server.
		MultiplayerManager.player_info = {"name": role, "character": Util.Character.Aurora if role == "client3" else Util.Character.WaterOrbA}
		assert(peer.create_client("127.0.0.1", port) == OK)
		multiplayer.multiplayer_peer = peer
	set_process(true)
	# Remain alive through scene changes; the parent is the SceneTree root.
	get_tree().current_scene = null

func _process(delta: float) -> void:
	duration += delta
	if duration > 35:
		push_error("NETWORK TEST TIMEOUT " + role)
		get_tree().quit(1)
		return
	if role == "host" and not match_started and MultiplayerManager.players.size() == 4:
		match_started = true
		# Give registration on the other clients time to settle before loading.
		_start_later()
	if not Overhaul.active():
		return
	var match_node := Overhaul.get_match()
	if match_node.get_players().size() != 4 or match_node.phase != "active":
		return
	if checked:
		return
	checked = true
	_validate_later(match_node)

func _start_later() -> void:
	await get_tree().create_timer(0.6).timeout
	_go.rpc()

@rpc("authority", "call_local", "reliable")
func _go() -> void:
	SceneManager.load_arena()

func _validate_later(match_node: Node) -> void:
	await get_tree().create_timer(1.0).timeout
	var ids := MultiplayerManager.players.keys()
	ids.sort()
	for i in range(ids.size()):
		var player: Player = match_node.get_player(int(ids[i]))
		assert(player != null and player.team_id == i % 2)
	assert(Overhaul.rules.preset == PlaytestRules.Preset.TEAM_OBJECTIVE)
	if role == "host":
		var victim: Player = match_node.get_player(int(ids[1]))
		victim._apply_damage.rpc(999, 1)
	await get_tree().create_timer(0.5).timeout
	var dead: Player = match_node.get_player(int(ids[1]))
	assert(not dead.is_alive)
	await get_tree().create_timer(5.5).timeout
	assert(dead.is_alive)
	if role == "host":
		match_node.round_time = 31.0
		match_node.control.owner = 0
		match_node.control.percentages[0] = 42.0
		match_node.control.capture_team = 1
		match_node.control.capture_progress = 0.5
		match_node.control.capture_idle = 0.0
	await get_tree().create_timer(0.4).timeout
	assert(match_node.control.owner == 0 and match_node.scores[0] >= 42.0)
	assert(match_node.control.capture_team == 1 and match_node.control.capture_progress > 0.4)
	if role == "host":
		match_node.control.winner = 0
		match_node._tick_objective(0.01)
	await get_tree().create_timer(0.8 if role == "host" else 0.4).timeout
	assert(match_node.phase == "intermission" and match_node.round_wins[0] == 1)
	if role == "host":
		match_node._start_round.rpc()
	await get_tree().create_timer(0.4 if role == "host" else 0.9).timeout
	assert(match_node.phase == "active" and match_node.round_number == 2)
	assert(match_node.control.owner == -1 and match_node.scores[0] == 0.0)
	assert(match_node.round_wins[0] == 1)
	print("NETWORK_ROUND_OK ", role, " generation=", generation)
	generation += 1
	_round_done.rpc_id(1, generation)

@rpc("any_peer", "call_local", "reliable")
func _round_done(round_number: int) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if id == 0:
		id = 1
	round_ready[id] = round_number
	if round_ready.size() != 4:
		return
	for value in round_ready.values():
		if int(value) != round_number:
			return
	if round_number == 2:
		_complete.rpc()
	else:
		Overhaul.get_match().finish(-1, "test_round")
		await get_tree().create_timer(0.3).timeout
		_reload.rpc()

@rpc("authority", "call_local", "reliable")
func _stop_sync() -> void:
	for player in Overhaul.get_match().get_players():
		player.get_node("InputSynchronizer").replication_config = SceneReplicationConfig.new()
		player.get_node("PlayerSynchronizer").replication_config = SceneReplicationConfig.new()

@rpc("authority", "call_local", "reliable")
func _complete() -> void:
	Overhaul.get_match().phase = "ended"
	_stop_sync()
	print("NETWORK_COMPLETE ", role)
	set_process(false)
	await get_tree().create_timer(0.2 if role == "host" else 0.7).timeout
	get_tree().quit(0)

@rpc("authority", "call_local", "reliable")
func _reload() -> void:
	checked = false
	if multiplayer.is_server():
		Overhaul.get_match()._restart.rpc()
