extends Node2D

const WALL_CELLS: Array[Vector2i] = [
	Vector2i(-4, -3), Vector2i(-3, -3), Vector2i(-4, -2), Vector2i(-3, -2),
	Vector2i(-4, 2), Vector2i(-3, 2), Vector2i(-4, 3), Vector2i(-3, 3),
	Vector2i(3, -3), Vector2i(2, -3), Vector2i(4, -2), Vector2i(3, -2),
	Vector2i(4, 2), Vector2i(3, 2), Vector2i(3, 3), Vector2i(2, 3),
]
const TEAM_COLORS: Array[Color] = [Color("69dfff"), Color("ff727b")]
var walls: Array[PackedVector2Array] = []
var phase: String = "waiting"
var elapsed: float = 0.0
var control := ControlPointState.new()
var scores: Array[float] = control.percentages
var round_wins: Array[int] = [0, 0]
var round_number: int = 1
var round_time: float = 0.0
var _feedback_owner: int = -2
var _feedback_overtime: bool = false
var _feedback_contested: bool = false
var _feedback_phase: String = ""
var _feedback_clock: float = 0.0
var _overtime_beat: float = 0.0
var round_pause: float = 0.0
var occupants: Array = []
var respawns: Dictionary = {}
var visible_cells: Dictionary = {}
var _fog_timer: float = 0.0
var _sync_timer: float = 0.0
var _log: FileAccess
var _status: Label
var _rematch_button: Button
var _leave_button: Button
var _capture_bar: ProgressBar
var _overtime_bar: ProgressBar
var _hint: Label
var _score_row: HBoxContainer
var _blue_score: Label
var _red_score: Label
var _point_badge: Label
var _fog: Node2D
var _last_sight: bool = false
var _last_occupants: Array = []
var _last_score: int = -1
var objective_cells: Array = []
var _spawn_ready: Dictionary = {}
var _reported_spawn_ready: bool = false

func _ready() -> void:
	z_index = 3
	_build_walls()
	control.capture_seconds = Overhaul.rules.capture_seconds
	control.percent_per_second = Overhaul.rules.control_percent_per_second
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
			"sight_radius": Overhaul.rules.sight_radius, "magic_sight_radius": Overhaul.rules.magic_sight_radius, "map": "hex-crossroads-v2"})
	_update_vision()
	queue_redraw()

func _build_walls() -> void:
	for cell in WALL_CELLS:
		HexCells.player_unique_instance.add_wall(cell)
	walls.assign(HexCells.get_wall_polygons())

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 90)
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -340.0
	panel.offset_right = 340.0
	panel.offset_top = 18.0
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	_score_row = HBoxContainer.new()
	_score_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_score_row.add_theme_constant_override("separation", 24)
	box.add_child(_score_row)
	_blue_score = _score_label(TEAM_COLORS[0])
	_point_badge = _score_label(Color.WHITE)
	_point_badge.text = "A"
	_red_score = _score_label(TEAM_COLORS[1])
	_status = Label.new()
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_font_size_override("font_size", 16)
	box.add_child(_status)
	_hint = Label.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = 660.0
	_hint.add_theme_font_size_override("font_size", 18)
	box.add_child(_hint)
	_capture_bar = ProgressBar.new()
	_capture_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_capture_bar.max_value = 1.0
	_capture_bar.show_percentage = false
	_capture_bar.custom_minimum_size.y = 8.0
	box.add_child(_capture_bar)
	_overtime_bar = ProgressBar.new()
	_overtime_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overtime_bar.max_value = 5.0
	_overtime_bar.show_percentage = false
	_overtime_bar.custom_minimum_size.y = 8.0
	_overtime_bar.modulate = Color("ffb347")
	box.add_child(_overtime_bar)
	var buttons := HBoxContainer.new()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

func _score_label(color: Color) -> Label:
	var label := Label.new()
	label.custom_minimum_size.x = 90.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 32)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_score_row.add_child(label)
	return label

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
	_feedback_clock += delta
	_overtime_beat = maxf(0.0, _overtime_beat - delta)
	if phase == "active" and control.overtime and control.overtime_remaining > 0.0:
		if _overtime_beat <= 0.0:
			_overtime_beat = lerpf(0.85, 0.35, 1.0 - clampf(control.overtime_remaining / maxf(control.overtime_duration(), 0.1), 0.0, 1.0))
			Juice.queue_sound("overtime_tick", Vector2.ZERO, Juice.local_id(), true)
	else:
		_overtime_beat = 0.0
	queue_redraw()
	if phase == "ended":
		return
	if phase == "waiting" and not _reported_spawn_ready and get_players().size() == Overhaul.rules.player_count():
		_reported_spawn_ready = true
		_report_spawn_ready.rpc_id(1)
	if phase == "intermission" and not multiplayer.is_server():
		round_pause = maxf(0.0, round_pause - delta)
	# Entity visibility is checked every frame, including fast projectiles.
	_fog_timer -= delta
	if _fog_timer <= 0.0:
		_fog_timer = 0.1
		_update_vision()
	_update_presentations()
	_update_camera()
	_update_hud()

func _physics_process(delta: float) -> void:
	if phase == "intermission":
		if multiplayer.is_server():
			round_pause = maxf(0.0, round_pause - delta)
			if round_pause <= 0.0:
				_start_round.rpc()
		return
	if phase != "active" or not multiplayer.is_server():
		return
	elapsed += delta
	round_time += delta
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
		_sync_snapshot.rpc(elapsed, scores, occupants, respawns, _player_states(), control.snapshot(), round_wins, round_time)

func _tick_objective(delta: float) -> void:
	occupants.clear()
	var counts: Array[int] = [0, 0]
	if round_time < Overhaul.rules.objective_delay:
		return
	for node in get_players():
		var player := node as Player
		if player != null and player.is_alive and not player.is_invulnerable():
			if objective_cells.has(HexCells.player_unique_instance.local_to_map(player.global_position)):
				counts[player.team_id] += 1
	for team in range(2):
		if counts[team] > 0:
			occupants.append(team)
	var previous_owner := control.owner
	var winner := control.tick(delta, counts)
	if previous_owner != control.owner:
		queue_redraw()
		log_event("point_captured", {"owner": control.owner, "round": round_number})
	if occupants != _last_occupants:
		log_event("objective_occupancy", {"teams": occupants.duplicate()})
		_last_occupants = occupants.duplicate()
	if int(scores[0] + scores[1]) != _last_score:
		_last_score = int(scores[0] + scores[1])
		log_event("score", {"scores": scores.duplicate(), "round": round_number})
	if winner >= 0:
		round_wins[winner] += 1
		log_event("round_ended", {"winner": winner, "round": round_number, "round_wins": round_wins.duplicate()})
		if round_wins[winner] >= Overhaul.rules.rounds_to_win:
			finish(winner, "control_rounds")
		else:
			_end_round.rpc(round_wins, control.snapshot())

@rpc("authority", "call_local", "reliable")
func _end_round(wins: Array, point: Dictionary) -> void:
	round_wins.assign(wins)
	control.load_snapshot(point)
	phase = "intermission"
	Juice.cue("objective", "ROUND COMPLETE")
	round_pause = Overhaul.rules.round_break
	for player in get_players():
		player._ability.process_mode = Node.PROCESS_MODE_DISABLED

@rpc("authority", "call_local", "reliable")
func _start_round() -> void:
	if phase != "intermission":
		return
	round_number += 1
	_reset_round()
	log_event("round_started", {"round": round_number})

func _player_states() -> Array:
	var states: Array = []
	for node in get_players():
		var player := node as Player
		states.append({"id": player.player_id, "hp": player.stats_update.current_health,
			"mana": player.stats_update.current_mana, "protection": player.spawn_protection})
	return states

@rpc("authority", "call_remote", "reliable")
func _sync_snapshot(time: float, points: Array, teams: Array, timers: Dictionary, states: Array, point: Dictionary, wins: Array, round_elapsed: float) -> void:
	elapsed = time
	var previous_owner := control.owner
	control.load_snapshot(point)
	if previous_owner != control.owner:
		queue_redraw()
	round_wins.assign(wins)
	round_time = round_elapsed
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
	Juice.world("heal", point, id)
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
	_finish.rpc(team, reason, scores, round_wins)

@rpc("authority", "call_local", "reliable")
func _finish(team: int, reason: String, points: Array, wins: Array) -> void:
	round_wins.assign(wins)
	scores.assign(points)
	phase = "ended"
	Overhaul.result_team = team
	Overhaul.result_text = "Draw" if team < 0 else "Team %s wins" % ("Blue" if team == 0 else "Red")
	Juice.cue("objective", "DRAW" if team < 0 else ("VICTORY" if team == Overhaul.team_for(multiplayer.get_unique_id()) else "DEFEAT"))
	if reason == "disconnect":
		Overhaul.result_text = "Match ended: player disconnected"
	Telemetry.end_match({"winner_team": team, "scores": points, "round_wins": round_wins, "match_end_reason": reason,
		"result": "draw" if team < 0 else ("win" if team == Overhaul.team_for(multiplayer.get_unique_id()) else "loss")})
	_show_result()

func can_see(point: Vector2) -> bool:
	if not Overhaul.rules.limited_vision:
		return true
	var cell := HexCells.player_unique_instance.local_to_map(point)
	return visible_cells.has(cell)

func _update_vision() -> void:
	visible_cells.clear()
	var observers: Array[Vector2] = []
	var radii: Array[float] = []
	for node in get_players():
		var player := node as Player
		if player != null and player.is_alive and Overhaul.local_friendly(player.player_id):
			observers.append(player.global_position)
			radii.append(Overhaul.rules.sight_radius)
	# Prepared and travelling magic reveal a smaller area for their owner's team.
	# Unclaimed, hostile, fizzled, and dead-owner magic never contributes sight.
	for node in get_tree().get_nodes_in_group("magic"):
		var magic := node as Magic
		if magic == null or magic.is_queued_for_deletion() or not Overhaul.local_friendly(magic.player_id):
			continue
		var owner := get_player(magic.player_id)
		if owner == null or not owner.is_alive:
			continue
		observers.append(magic.global_position)
		radii.append(Overhaul.rules.magic_sight_radius)
	for cell in HexCells.cell_dict:
		var point := HexCells.map_to_local(cell)
		for i in range(observers.size()):
			var origin := observers[i]
			if origin.distance_to(point) <= radii[i] and PlaytestVisionMask.has_line_of_sight(origin, point, walls):
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

func _update_feedback_transitions() -> void:
	if phase == "active":
		if _feedback_phase in ["intermission", "waiting"]:
			Juice.cue("objective", "ROUND START")
		if Overhaul.rules.preset == PlaytestRules.Preset.TEAM_OBJECTIVE:
			if _feedback_owner != -2 and control.owner >= 0 and control.owner != _feedback_owner:
				Juice.cue("objective", "POINT CAPTURED" if control.owner == Overhaul.team_for(multiplayer.get_unique_id()) else "POINT LOST")
			if control.overtime and not _feedback_overtime:
				Juice.cue("objective", "OVERTIME")
			var contested := occupants.has(0) and occupants.has(1)
			if contested and not _feedback_contested:
				Juice.cue("objective", "POINT CONTESTED")
			_feedback_contested = contested
	_feedback_owner = control.owner
	_feedback_overtime = control.overtime
	_feedback_phase = phase

func _update_hud() -> void:
	_update_feedback_transitions()
	_score_row.visible = Overhaul.rules.preset == PlaytestRules.Preset.TEAM_OBJECTIVE
	var team := Overhaul.team_for(multiplayer.get_unique_id())
	var local := get_player(multiplayer.get_unique_id())
	var mode := "2v2 CONTROL" if Overhaul.rules.preset == PlaytestRules.Preset.TEAM_OBJECTIVE else "VISION DUEL"
	var visibility := "LIMITED VISION" if Overhaul.rules.limited_vision else "FULL VISION"
	_status.text = "%s  |  %s  |  TEAM %s" % [mode, visibility, "BLUE" if team == 0 else "RED"]
	_capture_bar.visible = control.capture_team >= 0 and phase == "active"
	_capture_bar.value = control.capture_progress
	if control.capture_team >= 0:
		_capture_bar.modulate = TEAM_COLORS[control.capture_team]
	_overtime_bar.visible = control.overtime and phase == "active"
	_overtime_bar.value = control.overtime_remaining
	if Overhaul.rules.preset == PlaytestRules.Preset.TEAM_OBJECTIVE:
		var state := "NEUTRAL" if control.owner < 0 else "%s OWNS" % ("BLUE" if control.owner == 0 else "RED")
		if control.capture_team >= 0:
			state += " · %s CAPTURING %d%%" % ["BLUE" if control.capture_team == 0 else "RED", int(control.capture_progress * 100.0)]
		if occupants.size() == 2:
			state += " · CONTESTED"
		if control.overtime:
			state += " · OVERTIME %.1fs" % control.overtime_remaining
		if round_time < Overhaul.rules.objective_delay:
			state = "OPENS IN %ds" % ceili(Overhaul.rules.objective_delay - round_time)
		if phase == "intermission":
			state = "NEXT ROUND IN %ds" % ceili(round_pause)
		var blue_percent := mini(int(scores[0]), 99) if control.overtime and control.winner < 0 and control.owner == 0 else int(scores[0])
		var red_percent := mini(int(scores[1]), 99) if control.overtime and control.winner < 0 and control.owner == 1 else int(scores[1])
		_blue_score.text = "%d%%  %s" % [blue_percent, "●".repeat(round_wins[0])]
		_red_score.text = "%s  %d%%" % ["●".repeat(round_wins[1]), red_percent]
		_point_badge.modulate = TEAM_COLORS[control.owner] if control.owner >= 0 else Color.WHITE
		_hint.text = state
	else:
		_hint.text = "Eliminate the opponent • Walls conceal players and prepared magic"
	if phase == "waiting":
		_hint.text = "Waiting for all players to load…"
	elif phase == "active" and local != null and not local.is_alive:
		_hint.text += "  |  RESPAWN %.1fs" % float(respawns.get(local.player_id, Overhaul.rules.respawn_delay))
	elif phase == "active" and local != null and local.spawn_protection > 0.0:
		_hint.text += "  |  PROTECTED (casting ends protection)"

func _draw() -> void:
	if Overhaul.rules.preset == PlaytestRules.Preset.TEAM_OBJECTIVE:
		var point_color: Color = Color("dfca6b") if control.owner < 0 else TEAM_COLORS[control.owner]
		for cell in objective_cells:
			var points := PackedVector2Array(HexCells.get_hex_points_around(cell))
			draw_colored_polygon(points, Color(point_color, 0.12))
			draw_polyline(points, point_color, 2, true)
		if phase == "active" and round_time >= Overhaul.rules.objective_delay and Juice.intensity > 0.0:
			var color: Color = TEAM_COLORS[control.capture_team] if control.capture_team >= 0 else point_color
			color.a = Juice.intensity * 0.6
			var radius := HexCells.hex_width * 2.3
			if control.capture_team >= 0:
				draw_arc(Vector2.ZERO, radius, -PI / 2, -PI / 2 + maxf(0.01, control.capture_progress) * TAU, 64, color, 3.0, true)
			if control.overtime:
				var pulse := 0.5 if Juice.reduced_flashes else 0.35 + 0.15 * sin(_feedback_clock * 4.0)
				draw_arc(Vector2.ZERO, radius + 7, 0, TAU, 64, Color(1.0, 0.7, 0.3, pulse * Juice.intensity), 2.0, true)
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
	_score_row.hide()
	_capture_bar.hide()
	_overtime_bar.hide()
	var peer := multiplayer.multiplayer_peer
	var connected: bool = peer != null and peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED
	var host: bool = connected and multiplayer.is_server()
	_status.text = Overhaul.result_text
	_hint.text = "Rounds: Blue %d — %d Red · %s" % [round_wins[0], round_wins[1], "Host can start the next match" if host else "Waiting for host"]
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
	round_wins.assign([0, 0])
	round_number = 1
	elapsed = 0.0
	_reset_round()
	_rematch_button.hide()
	_leave_button.hide()
	Telemetry.start_match("overhaul_2v2" if Overhaul.rules.player_count() == 4 else "vision_duel",
		{"preset": Overhaul.rules.preset, "limited_vision": Overhaul.rules.limited_vision})
	MultiplayerManager._register_telemetry_players()
	if multiplayer.is_server():
		if _log != null:
			_log.close()
		_log = FileAccess.open("user://overhaul-%s.jsonl" % Time.get_unix_time_from_system(), FileAccess.WRITE)
		log_event("match_started", {"rematch": true, "preset": Overhaul.rules.preset, "limited_vision": Overhaul.rules.limited_vision})
	_update_vision()


func _reset_round() -> void:
	for player in get_players():
		_set_dead(player.player_id)
		_restore_player(player.player_id, Overhaul.spawn_position(player.team_id, player.spawn_slot))
		player.spawn_protection = 0.0
		player.last_damage_time = -100.0
	for effect in get_tree().get_nodes_in_group("overhaul_effect"):
		effect.queue_free()
	respawns.clear()
	control.reset()
	occupants.clear()
	round_time = 0.0
	round_pause = 0.0
	_last_score = -1
	_last_occupants.clear()
	phase = "active"
	queue_redraw()
	_update_vision()
