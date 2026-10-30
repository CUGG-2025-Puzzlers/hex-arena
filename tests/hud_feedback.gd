extends Node

var failures: int = 0

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error("HUD TEST FAILED: " + description)

func _ready() -> void:
	Telemetry.enabled = false
	call_deferred("run")

func run() -> void:
	Overhaul.reset_for_legacy()
	var arena: Node = load("res://scenes/arena.tscn").instantiate()
	get_tree().root.add_child(arena)
	get_tree().current_scene = arena
	await get_tree().process_frame
	var local: Player = MultiplayerManager._spawn_player_from_data({
		"id": 1, "character": Util.Character.Hekaset, "position": Vector2.ZERO
	})
	arena.get_node("Players").add_child(local)
	var hud: CanvasLayer = arena.get_node("HUD")
	hud.connect_to_player(local)
	var input_node := local.get_node("InputSynchronizer") as MultiplayerInput
	var ability := local.get_node("Ability") as AbilityBase
	check(hud.move_state.text == "READY", "ability starts ready")
	check(hud.get_node("%PassiveKey").text == "Q", "key hints use action bindings")
	_check_click_through(hud.get_node("PlayerMargin"))
	var viewport_width := get_viewport().get_visible_rect().size.x
	check(hud.get_node("PlayerMargin/Vitals").position.x < viewport_width * 0.25, "health stays in the left screen region")
	check(hud.get_node("PlayerMargin/AbilityContainer").position.x > viewport_width * 0.6, "abilities stay in the right screen region")
	check(hud.portrait.texture != null, "authored character portrait is displayed")
	local.stats_update.set_mana(local.stats_update.max_mana * 0.25)
	check(is_equal_approx(hud.mana_ring.get("fraction"), 0.25) and hud.mana_percent.text == "25%", "center gauge reflects actual mana fraction")
	local.stats_update.set_mana(0.0)
	check(hud.get_node("%LightState").text == "LOW MANA", "mana signal marks unaffordable magic")
	local.stats_update.set_mana(local.stats_update.max_mana)
	check(hud.get_node("%LightState").text.is_empty(), "mana recovery clears warning")
	ability._start_cooldown()
	ability.cooldown_updated.emit(ability.cooldown_duration * 0.5, ability.cooldown_duration)
	check(is_equal_approx(hud.move_progress.value, 0.5), "cooldown shows normalized recovery")
	check(hud.move_state.text == "RECHARGING", "cooldown has explicit state")
	ability.reset_for_respawn()
	check(not hud.move_overlay.visible and hud.move_state.text == "READY", "respawn clears cooldown visuals")
	input_node.direction = Vector2.ONE
	input_node.use_ability = true
	hud._concede_dialog.popup_centered()
	check(input_node.ui_input_blocked, "modal owns local input immediately")
	check(input_node.direction == Vector2.ZERO and not input_node.use_ability, "modal clears latched movement and ability")
	Input.action_press("right")
	input_node._physics_process(0.016)
	check(input_node.direction == Vector2.ZERO, "polling cannot move while modal is open")
	var ability_event := InputEventAction.new()
	ability_event.action = "ability"
	ability_event.pressed = true
	input_node._unhandled_input(ability_event)
	check(not input_node.use_ability, "modal rejects ability input")
	check(hud.move_state.text == "MENU OPEN", "modal lock is visible")
	hud._concede_dialog.hide()
	check(not input_node.ui_input_blocked, "cancel returns input ownership")
	input_node._physics_process(0.016)
	check(input_node.direction.x > 0.0, "movement resumes after cancel")
	Input.action_release("right")
	input_node._physics_process(0.016)
	local.silenced_until_msec = Time.get_ticks_msec() + 1000
	hud._process(0.0)
	check(hud.get_node("%LightState").text == "SILENCED", "silence overrides affordability")
	local.silenced_until_msec = 0
	local.is_alive = false
	hud._process(0.0)
	check(hud.move_state.text == "RESPAWNING", "death overrides ready state")
	local.is_alive = true
	ability._start_cooldown()
	hud._concede_dialog.popup_centered()
	hud.connect_to_player(null)
	check(not input_node.ui_input_blocked, "unbinding releases the old player")
	check(not hud.move_overlay.visible, "unbinding clears stale cooldown")
	check(not ability.cooldown_updated.is_connected(hud._on_move_cooldown_updated), "unbinding disconnects cooldown signals")
	hud._concede_dialog.hide()
	hud.connect_to_player(local)
	hud.connect_to_player(local)
	check(local.stats_update.mana_changed.get_connections().filter(func(c): return c.callable == hud._on_player_mana_changed).size() == 1, "rebinding does not duplicate subscriptions")
	_test_objective_header(arena)
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--screenshot="):
			local.stats_update.set_process(false)
			var ready_preview := "--hud-ready-preview" in OS.get_cmdline_user_args()
			local.stats_update.set_health(local.stats_update.max_health * (0.9 if ready_preview else 0.22))
			local.stats_update.set_mana(80.0 if ready_preview else 4.0)
			ability.set_process(false)
			ability.cooldown_remaining = 3.2
			ability.cooldown_updated.emit(3.2, 5.0)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			image.save_png(argument.trim_prefix("--screenshot="))
	hud._concede_dialog.popup_centered()
	hud.queue_free()
	await get_tree().process_frame
	check(not input_node.ui_input_blocked, "freeing HUD releases modal ownership")
	print("HUD_FEEDBACK_COMPLETE failures=%d" % failures)
	get_tree().quit(0 if failures == 0 else 1)

func _check_click_through(node: Node) -> void:
	if node is Control:
		check(node.mouse_filter == Control.MOUSE_FILTER_IGNORE, "decorative HUD passes pointer input: " + str(node.name))
	for child in node.get_children():
		_check_click_through(child)


func _test_objective_header(arena: Node) -> void:
	Overhaul.rules.preset = PlaytestRules.Preset.TEAM_OBJECTIVE
	Overhaul.session_enabled = true
	MultiplayerManager.players[1] = {"team_id": 0}
	var match_node: Node = load("res://scripts/playtest/playtest_match.gd").new()
	match_node.name = "PlaytestMatch"
	arena.add_child(match_node)
	match_node.set_process(false)
	match_node.phase = "active"
	match_node.round_time = 45.0
	match_node.round_wins[0] = 1
	match_node.control.owner = 0
	match_node.scores[0] = 100.0
	match_node.scores[1] = 42.0
	match_node.control.overtime = true
	match_node.control.overtime_remaining = 3.0
	match_node._update_hud()
	check(match_node._blue_score.text.begins_with("99%"), "objective score preserves overtime 99 percent display")
	check(match_node._red_score.text.ends_with("42%"), "opposing percentage is independent")
	check(match_node._hint.text.contains("OVERTIME"), "objective header retains overtime state")
	match_node.scores[0] = 65.0
	match_node.control.overtime = false
	match_node._update_hud()
