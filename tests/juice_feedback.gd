extends Node

var failures: int = 0
var events: Array[Dictionary] = []

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error("JUICE TEST FAILED: " + description)

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
	var local: Player = MultiplayerManager._spawn_player_from_data({"id": 1, "character": Util.Character.Hekaset, "position": Vector2(-160, 0)})
	var enemy: Player = MultiplayerManager._spawn_player_from_data({"id": 2, "character": Util.Character.Zilo, "position": Vector2(160, 0)})
	arena.get_node("Players").add_child(local)
	arena.get_node("Players").add_child(enemy)
	local.get_node("InputSynchronizer").set_process_unhandled_input(false)
	local.get_node("InputSynchronizer").set_physics_process(false)
	var hud: CanvasLayer = arena.get_node("HUD")
	hud.connect_to_player(local)
	Juice.presented.connect(func(event: Dictionary): events.append(event))
	await get_tree().process_frame
	var before := enemy.stats_update.current_health
	enemy.spawn_protection = 1.0
	enemy._apply_damage(10.0, 1, "fixture")
	check(events.is_empty() and enemy.stats_update.current_health == before, "invulnerable hits cannot confirm damage")
	enemy.spawn_protection = 0.0
	enemy._apply_damage(10.0, 2, "fixture")
	check(events.is_empty(), "friendly/self-suppressed damage cannot emit success")
	enemy._apply_damage(10.0, 1, "fixture")
	check(events.size() == 1 and events[0].kind == "confirmed_hit", "confirmed hostile damage reaches attacker once")
	check(is_equal_approx(enemy.stats_update.current_health, before - 10.0), "presentation preserves damage")
	events.clear()
	enemy.stats_update.set_health(before - 20.0)
	check(events.is_empty(), "snapshot updates cannot replay hit cues")
	local.stats_update.set_health(local.stats_update.max_health - 20.0)
	local._apply_damage(5.0, 2, "fixture")
	check(events.size() == 1 and events[0].kind == "hurt" and events[0].bearing.x > 0.0, "incoming hit has correct bearing")
	check(hud.player_hp_bar.get("_trail_value") > hud.player_hp_bar.value, "health trails confirmed damage briefly")
	local._apply_heal(5.0, 1, "fixture")
	check(is_equal_approx(local.stats_update.current_health, local.stats_update.max_health - 20.0), "presentation preserves healing")
	events.clear()
	enemy.stats_update.set_health(8.0)
	enemy._apply_damage(20.0, 1, "fixture")
	enemy._apply_damage(20.0, 1, "fixture")
	check(events.filter(func(event: Dictionary): return event.kind == "elimination").size() == 1, "lethal damage confirms once, even if damage repeats after death")
	enemy.stats_update.set_health(before)
	var cell := Vector2i(0, 1)
	var stats: MagicStats = local.preset.magics[Magic.MagicType.NEUTRAL]
	var magic: Magic = stats.scene.instantiate()
	magic.place_instance_for_player(cell, local, stats)
	check(_has_effect("place"), "real placement creates a hex accent")
	magic.change_state_for_player(Magic.MagicType.LIGHT, local)
	await get_tree().process_frame
	check(_has_effect("transform"), "real transformation creates a distinct accent")
	var transformed: Magic = HexCells.cell_dict[cell]
	var collision_shape: CollisionShape2D = transformed.find_children("*", "CollisionShape2D", true, false)[0]
	var collision_scale: Vector2 = collision_shape.scale
	HexCells.player_unique_instance._launch_approved(cell, PackedVector2Array([Vector2.ZERO, Vector2(260, 0)]), 1)
	check(transformed.rolling and _has_effect("launch"), "approved launch creates release feedback")
	check(collision_shape.scale == collision_scale, "feedback cannot scale gameplay collision")
	var ability := local.get_node("Ability") as AbilityBase
	events.clear()
	Juice._last.clear()
	ability._start_cooldown()
	ability._process(ability.cooldown_duration + 0.1)
	check(events.filter(func(event: Dictionary): return event.kind == "ready").size() == 1, "natural cooldown expiry announces once")
	events.clear()
	ability.reset_for_respawn()
	check(events.is_empty(), "respawn reset cannot fake a ready cue")
	local.silenced_until_msec = Time.get_ticks_msec() + 10000
	ability._start_cooldown()
	ability._process(ability.cooldown_duration + 0.1)
	check(events.is_empty(), "cooldown expiry while silenced cannot promise readiness")
	local.silenced_until_msec = 0
	Juice.open_settings()
	check(local.get_node("InputSynchronizer").ui_input_blocked, "settings own local gameplay input")
	hud._concede_dialog.exclusive = false # Fixture-only overlapping modal ownership test.
	hud._concede_dialog.popup_centered()
	Juice._dialog.hide()
	check(local.get_node("InputSynchronizer").ui_input_blocked, "overlapping concede modal retains input ownership")
	hud._concede_dialog.hide()
	hud._concede_dialog.exclusive = true
	check(not local.get_node("InputSynchronizer").ui_input_blocked, "last modal releases input")
	Overhaul.session_enabled = true
	Overhaul.rules.preset = PlaytestRules.Preset.TEAM_OBJECTIVE
	Overhaul.rules.limited_vision = true
	MultiplayerManager.players[1] = {"team_id": 0}
	MultiplayerManager.players[2] = {"team_id": 1}
	var match_node: Node = load("res://scripts/playtest/playtest_match.gd").new()
	match_node.name = "PlaytestMatch"
	arena.add_child(match_node)
	match_node.set_process(false)
	match_node.set_physics_process(false)
	match_node.phase = "active"
	match_node.visible_cells.clear()
	var count := Juice._effects.size()
	Juice.world("hit", Vector2(900, 900), 2)
	check(Juice._effects.size() == count, "hidden hostile effects cannot leak fog information")
	Juice._last.clear()
	events.clear()
	match_node._update_hud()
	match_node.control.owner = 0
	match_node._update_hud()
	match_node._update_hud()
	check(events.filter(func(event: Dictionary): return event.kind == "objective").size() == 1, "capture edge announces once")
	Overhaul.rules.limited_vision = false
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--preview="):
			await _preview(argument.trim_prefix("--preview="), local, enemy)
	Juice.audio_enabled = true
	Juice._last.clear()
	Juice._pending.clear()
	for id in range(30):
		Juice.queue_sound("place", Vector2.ZERO, id, true)
	Juice.queue_sound("elimination", Vector2.ZERO, 1, true)
	Juice._process(0.016)
	check(Juice._voices.size() <= 4, "audio has a per-frame budget")
	check(Juice._voices.any(func(voice: Dictionary): return voice.score >= 8.0), "critical confirmation survives placement spam")
	Juice.queue_sound("block", Vector2.ZERO, 1)
	Juice._process(0.016)
	check(Juice._voices.any(func(voice: Dictionary): return voice.node is AudioStreamPlayer2D), "world cues use spatial audio separately from personal confirmations")
	Juice.audio_enabled = false
	for i in range(70):
		Juice.world("place", Vector2.ZERO, 1)
	Juice.world("break", Vector2.ZERO, 1)
	check(Juice._effects.size() <= Juice.MAX_EFFECTS and _has_effect("break"), "critical effects survive placement spam within the visual budget")
	for kind in ["place", "hit", "block", "break", "ready", "elimination"]:
		check(Juice._sound(kind).data.size() > 0, "audio generated: " + kind)
	var replacement := Node2D.new()
	get_tree().root.add_child(replacement)
	get_tree().current_scene = replacement
	Juice._process(0.016)
	check(Juice._effects.is_empty() and Juice._voices.is_empty() and Juice._pending.is_empty(), "scene handoff clears transient effects, voices and pending cues")
	Overhaul.reset_for_legacy()
	print("JUICE_FEEDBACK_COMPLETE failures=%d" % failures)
	get_tree().quit(0 if failures == 0 else 1)

func _has_effect(kind: String) -> bool:
	for node in get_tree().get_nodes_in_group("juice_effect"):
		if node.kind == kind and not node.is_queued_for_deletion():
			return true
	return false

func _preview(path: String, local: Player, enemy: Player) -> void:
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	local.stats_update.set_health(local.stats_update.max_health * 0.55)
	enemy.stats_update.set_health(enemy.stats_update.max_health)
	Juice.world("place", Vector2(-90, 100), 1)
	Juice.world("transform", Vector2(30, 100), 1)
	Juice.world("block", Vector2(0, -80), 1, Vector2.LEFT)
	Juice.world("break", Vector2(120, -80), 2)
	Juice._last.clear()
	local._apply_damage(8.0, 2, "preview")
	Juice.cue("ready")
	# Staged still: freeze only decorative effect nodes so startup stalls cannot
	# consume their short lifetime before the screenshot is read back.
	for effect in get_tree().get_nodes_in_group("juice_effect"):
		effect.set_process(false)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
