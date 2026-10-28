extends Node2D

const WALLS: Array[Rect2] = [
	Rect2(-450, -380, 180, 220), Rect2(270, 160, 180, 220),
	Rect2(-450, 160, 180, 220), Rect2(270, -380, 180, 220),
]
const TEAM_COLORS: Array[Color] = [Color("69dfff"), Color("ff727b")]
var walls: Array[Rect2] = []
var phase: String = "waiting"
var elapsed: float = 0.0
var scores: Array[float] = [0.0, 0.0]
var occupants: Array = []
var respawns: Dictionary = {}
var visible_cells: Dictionary = {}
var _fog_timer: float = 0.0
var _sync_timer: float = 0.0
var _log: FileAccess
var _status: Label
var _rematch_button: Button
var _leave_button: Button
var _hint: Label
var _fog: Node2D
var _last_sight: bool = false
var _last_occupants: Array = []
var _last_score: int = -1
var objective_cells: Array = []
var _spawn_ready: Dictionary = {}
var _reported_spawn_ready: bool = false

func _ready() -> void:
	z_index = 3
	walls.assign(WALLS)
	_build_walls()
	objective_cells = HexCells.get_surrounding_cells_in_radius(Vector2i.ZERO, 2)
	_build_hud()
	_fog = Node2D.new()
	_fog.z_index = 30
	add_child(_fog)
	_fog.draw.connect(_draw_fog)
	if multiplayer.is_server():
		var path := "user://overhaul-%s.jsonl" % Time.get_unix_time_from_system()
		_log = FileAccess.open(path, FileAccess.WRITE)
		log_event("settings", {"preset": Overhaul.rules.preset, "limited_vision": Overhaul.rules.limited_vision,
			"sight_radius": Overhaul.rules.sight_radius, "map": "crossroads-v1"})
	_update_vision()
	queue_redraw()

func _build_walls() -> void:
	for rect in walls:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.position = rect.get_center()
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = rect.size
		shape.shape = rectangle
		body.add_child(shape)
		add_child(body)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(520, 12)
	panel.custom_minimum_size = Vector2(880, 90)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 25)
	box.add_child(_status)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.add_theme_font_size_override("font_size", 18)
	box.add_child(_hint)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	_rematch_button = Button.new()
	_rematch_button.text = "REMATCH"
	_rematch_button.hide()
	_rematch_button.pressed.connect(func():
		if multiplayer.is_server() and MultiplayerManager.players.size() == Overhaul.rules.player_count():
			_restart.rpc())
	buttons.add_child(_rematch_button)
	_leave_button = Button.new()
	_leave_button.text = "MAIN MENU"
	_leave_button.hide()
	_leave_button.pressed.connect(_leave_match)
	buttons.add_child(_leave_button)

func get_players() -> Array:
	return get_parent().get_node("Players").get_children()

func get_player(id: int) -> Player:
	return get_parent().get_node_or_null("Players/" + str(id)) as Player

func accepts_input(id: int) -> bool:
	var player := get_player(id)
	return phase == "active" and player != null and player.is_alive

func begin() -> void:
	if multiplayer.is_server() and phase == "waiting":
		_sync_phase.rpc("active")
		log_event("match_started")

@rpc("authority", "call_local", "reliable")
func _sync_phase(value: String) -> void:
	phase = value
	for player in get_players():
		player._apply_readability_style(GameManager.readability_style)
		for sync_name in ["PlayerSynchronizer", "InputSynchronizer"]:
			var sync: MultiplayerSynchronizer = player.get_node(sync_name)
			if value == "active" and sync.has_meta("playtest_config"):
				sync.replication_config = sync.get_meta("playtest_config")

func _process(delta: float) -> void:
	if phase == "ended":
		return
	if phase == "waiting" and not _reported_spawn_ready and get_players().size() == Overhaul.rules.player_count():
		_reported_spawn_ready = true
		_report_spawn_ready.rpc_id(1)
	# Entity visibility is checked every frame, including fast projectiles.
	_fog_timer -= delta
	if _fog_timer <= 0.0:
		_fog_timer = 0.1
		_update_vision()
	_update_presentations()
	_update_camera()
	_update_hud()

func _physics_process(delta: float) -> void:
	if phase != "active" or not multiplayer.is_server():
		return
	elapsed += delta
	for id in respawns.keys():
		respawns[id] = maxf(0.0, float(respawns[id]) - delta)
		if float(respawns[id]) <= 0.0:
			_respawn(int(id))
	for node in get_players():
		var player := node as Player
		if player == null or not player.is_alive:
			continue
		player.spawn_protection = maxf(0.0, player.spawn_protection - delta)
		if player.global_position.distance_to(Overhaul.spawn_position(player.team_id, 0) * Vector2(1, 0)) < 185.0:
			if elapsed - player.last_damage_time >= Overhaul.rules.recovery_damage_delay:
				player._apply_heal.rpc(Overhaul.rules.recovery_rate * delta, player.player_id, "Base")
				player._restore_mana.rpc(Overhaul.rules.recovery_rate * delta)
	if Overhaul.rules.preset == PlaytestRules.Preset.TEAM_OBJECTIVE:
		_tick_objective(delta)
	_sync_timer -= delta
	if _sync_timer <= 0.0:
		_sync_timer = 0.1
		_sync_snapshot.rpc(elapsed, scores, occupants, respawns, _player_states())

func _tick_objective(delta: float) -> void:
	occupants.clear()
	if elapsed >= Overhaul.rules.objective_delay:
		for node in get_players():
			var player := node as Player
			if player != null and player.is_alive and player.spawn_protection <= 0.0:
				if objective_cells.has(HexCells.player_unique_instance.local_to_map(player.global_position)):
					if not occupants.has(player.team_id):
						occupants.append(player.team_id)
	var owner := PlaytestRules.score_owner(occupants)
	if owner >= 0:
		scores[owner] += delta
	if occupants != _last_occupants:
		log_event("objective_occupancy", {"teams": occupants.duplicate()})
		_last_occupants = occupants.duplicate()
	if int(scores[0] + scores[1]) != _last_score:
		_last_score = int(scores[0] + scores[1])
		log_event("score", {"scores": scores.duplicate()})
	for team in range(2):
		if scores[team] >= Overhaul.rules.score_to_win:
			finish(team, "score")
			return
	if elapsed >= Overhaul.rules.time_limit:
		finish(-1 if is_equal_approx(scores[0], scores[1]) else (0 if scores[0] > scores[1] else 1), "time_limit")

func _player_states() -> Array:
	var states: Array = []
	for node in get_players():
		var player := node as Player
		states.append({"id": player.player_id, "hp": player.stats_update.current_health,
			"mana": player.stats_update.current_mana, "protection": player.spawn_protection})
	return states

@rpc("authority", "call_remote", "reliable")
func _sync_snapshot(time: float, points: Array, teams: Array, timers: Dictionary, states: Array) -> void:
	elapsed = time
	scores.assign(points)
	occupants = teams
	respawns = timers
	for state in states:
		var player := get_player(int(state.id))
		if player != null:
			player.stats_update.set_health(float(state.hp))
			player.stats_update.set_mana(float(state.mana))
			player.spawn_protection = float(state.protection)

func on_death(id: int) -> void:
	if phase != "active" or not multiplayer.is_server():
		return
	var player := get_player(id)
	if player == null or not player.is_alive:
		return
	_set_dead.rpc(id)
	log_event("death", {"player": id, "team": player.team_id})
	if Overhaul.rules.preset == PlaytestRules.Preset.TEAM_OBJECTIVE:
		respawns[id] = Overhaul.rules.respawn_delay
	else:
		finish(1 - player.team_id, "elimination")

@rpc("authority", "call_local", "reliable")
func _set_dead(id: int) -> void:
	var player := get_player(id)
	if player == null:
		return
	player.is_alive = false
	player.velocity = Vector2.ZERO
	player._input.direction = Vector2.ZERO
	player._input.use_ability = false
	player._ability.process_mode = Node.PROCESS_MODE_DISABLED
	player.visible = false
	player.get_node("CollisionShape2D").set_deferred("disabled", true)
	player.get_node("Area2D/CollisionShape2D").set_deferred("disabled", true)
	for node in get_tree().get_nodes_in_group("magic"):
		if node is Magic and node.player_id == id:
			node.fizzle()
	for node in get_tree().get_nodes_in_group("water_orb_wire"):
		if int(node.get("player_id")) == id:
			node.queue_free()
	var field_controller := player.get_node_or_null("AuroraFieldController")
	if field_controller != null and is_instance_valid(field_controller.active_field):
		field_controller.active_field.queue_free()
	if id == multiplayer.get_unique_id():
		_reset_targeting()
	_update_vision()

func _reset_targeting() -> void:
	Magic.last_placed_cell = Vector2i.ZERO
	HexCells.player_unique_instance.get_node("LastMagic").hide()

func _respawn(id: int) -> void:
	var player := get_player(id)
	if player == null:
		return
	var spawn := Overhaul.spawn_position(player.team_id, player.spawn_slot)
	# Choose a nearby clear slot, including protection from temporary shields.
	for offset in [Vector2.ZERO, Vector2(0, 70), Vector2(0, -70), Vector2(70, 0), Vector2(-70, 0), Vector2(0, 140), Vector2(0, -140)]:
		var candidate: Vector2 = spawn + offset
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = player.get_node("CollisionShape2D").shape
		query.transform = Transform2D(0, candidate)
		query.collision_mask = 1
		if get_world_2d().direct_space_state.intersect_shape(query).is_empty():
			_restore_player.rpc(id, candidate)
			respawns.erase(id)
			log_event("respawn", {"player": id})
			return
	# Retry next tick if all nearby positions are blocked.

@rpc("authority", "call_local", "reliable")
func _restore_player(id: int, point: Vector2) -> void:
	var player := get_player(id)
	if player == null:
		return
	player.global_position = point
	player.is_alive = true
	player.spawn_protection = Overhaul.rules.protection_duration
	player.rooted_until_msec = 0
	player.silenced_until_msec = 0
	player._move_modifiers.clear()
	player._fading_modifier_versions.clear()
	player._input.direction = Vector2.ZERO
	player._input.use_ability = false
	player._ability.reset_for_respawn()
	player._ability.process_mode = Node.PROCESS_MODE_INHERIT
	player.stats_update.set_health(player.stats_update.max_health)
	player.stats_update.set_mana(player.stats_update.max_mana)
	player.get_node("CollisionShape2D").set_deferred("disabled", false)
	player.get_node("Area2D/CollisionShape2D").set_deferred("disabled", false)
	if id == multiplayer.get_unique_id():
		_reset_targeting()

func finish(team: int, reason: String) -> void:
	if not multiplayer.is_server() or phase == "ended":
		return
	phase = "ended"
	log_event("match_ended", {"winner": team, "reason": reason, "scores": scores.duplicate()})
	_finish.rpc(team, reason, scores)

@rpc("authority", "call_local", "reliable")
func _finish(team: int, reason: String, points: Array) -> void:
	scores.assign(points)
	phase = "ended"
	Overhaul.result_team = team
	Overhaul.result_text = "Draw" if team < 0 else "Team %s wins" % ("Blue" if team == 0 else "Red")
	if reason == "disconnect":
		Overhaul.result_text = "Match ended: player disconnected"
	Telemetry.end_match({"winner_team": team, "scores": points, "match_end_reason": reason,
		"result": "draw" if team < 0 else ("win" if team == Overhaul.team_for(multiplayer.get_unique_id()) else "loss")})
	_show_result()

func point_blocked(point: Vector2) -> bool:
	for wall in walls:
		if wall.has_point(point):
			return true
	return false

func can_see(point: Vector2) -> bool:
	if not Overhaul.rules.limited_vision:
		return true
	var cell := HexCells.player_unique_instance.local_to_map(point)
	return visible_cells.has(cell)

func _update_vision() -> void:
	visible_cells.clear()
	var observers: Array[Vector2] = []
	for node in get_players():
		var player := node as Player
		if player != null and player.is_alive and Overhaul.local_friendly(player.player_id):
			observers.append(player.global_position)
	for cell in HexCells.cell_dict:
		var point := HexCells.map_to_local(cell)
		for origin in observers:
			if origin.distance_to(point) <= Overhaul.rules.sight_radius and PlaytestVisionMask.has_line_of_sight(origin, point, walls):
				visible_cells[cell] = true
				break
	_fog.queue_redraw() if _fog != null else queue_redraw()

func _update_presentations() -> void:
	var enemy_seen := false
	for node in get_players():
		var player := node as Player
		var reveal := player.is_alive and (Overhaul.local_friendly(player.player_id) or can_see(player.global_position))
		player.visible = reveal
		if reveal and not Overhaul.local_friendly(player.player_id):
			enemy_seen = true
	for node in get_tree().get_nodes_in_group("magic"):
		if node is Magic:
			node.visible = Overhaul.local_friendly(node.player_id) or can_see(node.global_position)
	# Detached and large-area effects are deliberately conservative: only show
	# them when the complete footprint is visible, so their shape cannot reveal a setup.
	for node in get_tree().get_nodes_in_group("overhaul_effect"):
		var points: PackedVector2Array = node.get_meta("vision_points", PackedVector2Array([node.global_position]))
		var reveal: bool = Overhaul.local_friendly(int(node.get_meta("vision_owner", -1)))
		if not reveal:
			reveal = true
			for point in points:
				if not can_see(point):
					reveal = false
					break
		node.visible = reveal
	if enemy_seen != _last_sight:
		log_event("local_sight_changed", {"enemy_visible": enemy_seen})
		_last_sight = enemy_seen

func _update_camera() -> void:
	var camera := get_parent().get_node_or_null("Camera2D") as Camera2D
	var local := get_player(multiplayer.get_unique_id())
	if camera == null or local == null or local.is_alive:
		return
	var point := Overhaul.spawn_position(local.team_id, 0) * Vector2(1, 0)
	for node in get_players():
		var player := node as Player
		if player.is_alive and player.team_id == local.team_id:
			point = player.global_position
			break
	camera.global_position = point

func _update_hud() -> void:
	var team := Overhaul.team_for(multiplayer.get_unique_id())
	var local := get_player(multiplayer.get_unique_id())
	var mode := "2v2 CONTROL" if Overhaul.rules.preset == PlaytestRules.Preset.TEAM_OBJECTIVE else "VISION DUEL"
	var visibility := "LIMITED VISION" if Overhaul.rules.limited_vision else "FULL VISION"
	_status.text = "%s  |  %s  |  TEAM %s" % [mode, visibility, "BLUE" if team == 0 else "RED"]
	if Overhaul.rules.preset == PlaytestRules.Preset.TEAM_OBJECTIVE:
		var remaining := maxi(0, ceili(Overhaul.rules.time_limit - elapsed))
		var state := "CONTESTED" if occupants.size() == 2 else ("EMPTY" if occupants.is_empty() else "BLUE CONTROLS" if occupants.has(0) else "RED CONTROLS")
		if elapsed < Overhaul.rules.objective_delay:
			state = "OPENS IN %ds" % ceili(Overhaul.rules.objective_delay - elapsed)
		_hint.text = "BLUE %d — %d RED  |  %d:%02d  |  %s" % [int(scores[0]), int(scores[1]), remaining / 60, remaining % 60, state]
	else:
		_hint.text = "Eliminate the opponent • Walls conceal players and prepared magic"
	if phase == "waiting":
		_hint.text = "Waiting for all players to load…"
	elif local != null and not local.is_alive:
		_hint.text += "  |  RESPAWN %.1fs" % float(respawns.get(local.player_id, Overhaul.rules.respawn_delay))
	elif local != null and local.spawn_protection > 0.0:
		_hint.text += "  |  PROTECTED (casting ends protection)"

func _draw() -> void:
	for wall in walls:
		draw_rect(wall, Color("253849"))
		draw_rect(wall, Color("93aabe"), false, 3)
	if Overhaul.rules.preset == PlaytestRules.Preset.TEAM_OBJECTIVE:
		for cell in objective_cells:
			var points := PackedVector2Array(HexCells.get_hex_points_around(cell))
			draw_colored_polygon(points, Color(0.8, 0.7, 0.2, 0.12))
			draw_polyline(points, Color("dfca6b"), 2, true)
		for team in range(2):
			var center := Overhaul.spawn_position(team, 0) * Vector2(1, 0)
			draw_circle(center, 180, Color(TEAM_COLORS[team], 0.12))
			draw_arc(center, 180, 0, TAU, 48, TEAM_COLORS[team], 3, true)

func _draw_fog() -> void:
	if not Overhaul.rules.limited_vision:
		return
	for cell in HexCells.cell_dict:
		if not visible_cells.has(cell):
			_fog.draw_colored_polygon(PackedVector2Array(HexCells.get_hex_points_around(cell)), Color(0.02, 0.03, 0.06, 0.65))

func log_event(event: String, data: Dictionary = {}) -> void:
	if _log == null:
		return
	var record := data.duplicate(true)
	record["event"] = event
	record["elapsed"] = elapsed
	_log.store_line(JSON.stringify(record))
	_log.flush()


@rpc("any_peer", "call_local", "reliable")
func _report_spawn_ready() -> void:
	if not multiplayer.is_server() or phase != "waiting":
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		sender = multiplayer.get_unique_id()
	if not MultiplayerManager.players.has(sender):
		return
	_spawn_ready[sender] = true
	if _spawn_ready.size() == Overhaul.rules.player_count():
		begin()


func _show_result() -> void:
	var peer := multiplayer.multiplayer_peer
	var connected: bool = peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	var host: bool = connected and multiplayer.is_server()
	_status.text = Overhaul.result_text
	_hint.text = "Blue %d — %d Red · %s" % [int(scores[0]), int(scores[1]), "Host can start the next match" if host else "Waiting for host"]
	_rematch_button.visible = host and MultiplayerManager.players.size() == Overhaul.rules.player_count()
	_leave_button.show()
	for player in get_players():
		player._ability.process_mode = Node.PROCESS_MODE_DISABLED

func show_disconnected() -> void:
	phase = "ended"
	Overhaul.result_text = "Match ended: host disconnected"
	_show_result()

func _leave_match() -> void:
	await LobbyMatchmakingManager.cleanup_lobby()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	MultiplayerManager.players.clear()
	Overhaul.reset_for_legacy()
	SceneManager.load_title_screen()

@rpc("authority", "call_local", "reliable")
func _restart() -> void:
	if phase != "ended":
		return
	for player in get_players():
		_set_dead(player.player_id)
		_restore_player(player.player_id, Overhaul.spawn_position(player.team_id, player.spawn_slot))
		player.spawn_protection = 0.0
		player.last_damage_time = -100.0
	for effect in get_tree().get_nodes_in_group("overhaul_effect"):
		effect.queue_free()
	respawns.clear()
	scores = [0.0, 0.0]
	occupants.clear()
	elapsed = 0.0
	_last_score = -1
	_last_occupants.clear()
	_rematch_button.hide()
	_leave_button.hide()
	phase = "active"
	Telemetry.start_match("overhaul_2v2" if Overhaul.rules.player_count() == 4 else "vision_duel",
		{"preset": Overhaul.rules.preset, "limited_vision": Overhaul.rules.limited_vision})
	MultiplayerManager._register_telemetry_players()
	if multiplayer.is_server():
		if _log != null:
			_log.close()
		_log = FileAccess.open("user://overhaul-%s.jsonl" % Time.get_unix_time_from_system(), FileAccess.WRITE)
		log_event("match_started", {"rematch": true, "preset": Overhaul.rules.preset, "limited_vision": Overhaul.rules.limited_vision})
	_update_vision()
