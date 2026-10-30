extends Node

const VIEW := preload("res://scripts/feedback/combat_readability.gd")
var failures: int = 0
var events: Array[Dictionary] = []
func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error("READABILITY TEST FAILED: " + description)

func _ready() -> void:
	Telemetry.enabled = false
	call_deferred("run")

func run() -> void:
	Overhaul.reset_for_legacy()
	Juice.audio_enabled = false
	Juice.intensity = 0.75
	var arena: Node = load("res://scenes/arena.tscn").instantiate()
	get_tree().root.add_child(arena)
	get_tree().current_scene = arena
	await get_tree().process_frame
	var local: Player = MultiplayerManager._spawn_player_from_data({"id": 1, "character": Util.Character.Hekaset, "position": Vector2.ZERO})
	var enemy: Player = MultiplayerManager._spawn_player_from_data({"id": 2, "character": Util.Character.Zilo, "position": Vector2(450,0)})
	arena.get_node("Players").add_child(local)
	arena.get_node("Players").add_child(enemy)
	for player in [local, enemy]:
		player.set_physics_process(false)
		player.get_node("InputSynchronizer").set_physics_process(false)
		player.get_node("InputSynchronizer").set_process_unhandled_input(false)
	await get_tree().process_frame
	var view: Node2D = Juice._readability
	check(is_instance_valid(view), "observer attaches to arena without scene edits")
	view.set_process(false)
	check(view.key_label(0) == "Q" and view.key_label(2) == "R", "preview labels follow actual action bindings")
	Juice.presented.connect(func(event: Dictionary): events.append(event))
	var stats: MagicStats = local.preset.magics[Magic.MagicType.NEUTRAL]
	var cells := [Vector2i.ZERO, Vector2i(1,0), Vector2i(-1,0)]
	var magics: Array[Magic] = []
	for cell in cells:
		var magic: Magic = stats.scene.instantiate()
		magic.place_instance_for_player(cell, local, stats)
		magics.append(magic)
	var cost := magics[0].change_state_cost(Magic.MagicType.LIGHT)
	check(cost > 0, "fixture has a payable transform")
	local.stats_update.current_mana = cost
	var before := local.stats_update.current_mana
	var preview: Array = view.plan(local, Magic.MagicType.LIGHT)
	check(preview.filter(func(p: Dictionary): return p.status == "valid").size() == 1, "batch preview allocates finite mana once")
	check(preview[0].cell == Vector2i.ZERO and preview[0].status == "valid", "preview matches authoritative self-cell-first order")
	check(local.stats_update.current_mana == before and not magics[0].is_queued_for_deletion(), "preview cannot spend mana or transform spells")
	var passive: Array = view.plan(local, Magic.MagicType.PASSIVE)
	check(passive[0].status == "blocked", "shield preview rejects caster cell")
	enemy.global_position = HexCells.map_to_local(Vector2i(1,0))
	preview = view.plan(local, Magic.MagicType.LIGHT)
	check(preview.any(func(p: Dictionary): return p.cell == Vector2i(1,0) and p.status == "blocked"), "visible enemy occupancy blocks preview")
	enemy.hide()
	preview = view.plan(local, Magic.MagicType.LIGHT)
	check(preview.any(func(p: Dictionary): return p.cell == Vector2i(1,0) and p.status == "mana"), "hidden occupancy cannot leak through blocked markers")
	enemy.show()
	enemy.global_position = Vector2(450,0)
	magics[1].player_id = 2
	preview = view.plan(local, Magic.MagicType.LIGHT)
	check(preview.any(func(p: Dictionary): return p.cell == Vector2i(1,0) and p.status == "blocked"), "opponent-owned magic cannot be promised")
	magics[1].player_id = 1
	view.refresh()
	check(not view.previews.is_empty(), "active player sees previews")
	local.get_node("InputSynchronizer").ui_input_blocked = true
	view.refresh()
	check(view.previews.is_empty(), "modal ownership hides cast previews")
	local.get_node("InputSynchronizer").ui_input_blocked = false
	var lance := MagicPressureLance.new()
	lance.charge_progress = 0.4
	check(view.state_of(lance).kind == "charging", "charge state uses actual progress")
	lance.charge_progress = 1.0
	check(view.state_of(lance).kind == "ready", "charge completion yields ready shape")
	lance.free()
	var orb := MagicTidebladeOrb.new()
	orb.attacks_remaining = 0
	check(view.state_of(orb).kind == "exhausted", "finite attack exhaustion is distinct")
	orb.attacks_remaining = 2
	orb.rolling = true
	check(view.state_of(orb).kind == "recovering", "busy orb cannot falsely show ready")
	orb.free()
	var shield_stats := magics[2].own_transforms[Magic.MagicType.PASSIVE] as MagicStats
	var shield: MagicShield = shield_stats.scene.instantiate()
	shield.place_instance_for_player(Vector2i(0,2), local, shield_stats)
	for child in shield.get_children():
		if child is Timer:
			child.start(0.8)
	check(view.state_of(shield).kind == "expiring", "shield warning derives from live timer")
	Juice._last.clear()
	shield.take_damage(1.0)
	check(events.any(func(e: Dictionary): return e.kind == "success" and e.text == "BLOCKED"), "real shield contact confirms defense")
	events.clear()
	shield.take_damage(0.0)
	check(events.is_empty(), "zero damage cannot claim a defensive success")
	enemy._apply_root(0.4, 1, "test")
	check(events.any(func(e: Dictionary): return e.kind == "success" and e.text == "ROOTED"), "root confirms added crowd control")
	events.clear()
	enemy._apply_root(0.01, 1, "test")
	check(events.is_empty(), "non-extending root cannot replay success")
	Juice._last.clear()
	enemy._apply_silence(0.4, 1, "test")
	check(events.any(func(e: Dictionary): return e.kind == "success" and e.text == "SILENCED"), "silence confirms separately")
	var ending: Magic = stats.scene.instantiate()
	ending.place_instance_for_player(Vector2i(0,-2), local, stats)
	ending.fizzle("expired")
	check(has_effect("expired"), "expiration has a contraction rather than a break")
	var dash := enemy.get_node("Ability") as DashAbility
	dash._execute()
	check(has_effect("depart"), "dash departure is directional")
	dash.cancel_dash()
	check(has_effect("interrupted"), "dash cancel reports interruption")
	var match_node: Node = load("res://scripts/playtest/playtest_match.gd").new()
	match_node.name = "PlaytestMatch"
	arena.add_child(match_node)
	match_node.set_physics_process(false)
	match_node.set_process(false)
	match_node.phase = "active"
	match_node.control.overtime = true
	match_node.control.overtime_remaining = 4.0
	match_node._process(0.016)
	var calm: float = match_node._overtime_beat
	match_node._overtime_beat = 0.0
	match_node.control.overtime_remaining = 0.2
	match_node._process(0.016)
	check(match_node._overtime_beat < calm, "overtime rhythm accelerates with actual remaining time")
	match_node.phase = "intermission"
	match_node._process(0.016)
	check(match_node._overtime_beat == 0.0, "round break stops overtime rhythm")
	Overhaul.rules.limited_vision = true
	match_node.visible_cells.clear()
	view.refresh()
	check(view.entries.all(func(e: Dictionary): return e.magic.get_ref().player_id != 2), "hidden hostile state markers are absent")
	Overhaul.rules.limited_vision = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--preview="):
			Overhaul.session_enabled = true
			Overhaul.rules.preset = PlaytestRules.Preset.TEAM_OBJECTIVE
			MultiplayerManager.players[1] = {"team_id": 0}
			MultiplayerManager.players[2] = {"team_id": 1}
			arena.get_node("HUD").connect_to_player(local)
			local.stats_update.current_mana = 80.0
			local.global_position = Vector2.ZERO
			var fresh: Magic = stats.scene.instantiate()
			fresh.place_instance_for_player(Vector2i.ZERO, local, stats)
			match_node.phase = "active"
			match_node.round_time = 30.0
			match_node.control.capture_team = 0
			match_node.control.capture_progress = 0.65
			match_node.control.overtime = false
			match_node._process(0.016)
			view.refresh()
			view.queue_redraw()
			get_viewport().warp_mouse(get_viewport().get_canvas_transform() * fresh.global_position)
			view.set_process(false)
			for effect in get_tree().get_nodes_in_group("juice_effect"):
				effect.set_process(false)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--preview="))
	Overhaul.reset_for_legacy()
	print("READABILITY_FEEDBACK_COMPLETE failures=%d" % failures)
	get_tree().quit(0 if failures == 0 else 1)

func has_effect(kind: String) -> bool:
	return get_tree().get_nodes_in_group("juice_effect").any(func(node: Node): return node.kind == kind and not node.is_queued_for_deletion())
