extends Node

var failures: int = 0
func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error("TEST FAILED: " + description)

func _ready() -> void:
	Telemetry.enabled = false
	call_deferred("run")

func run() -> void:
	var walls: Array[Rect2] = [Rect2(-20, -50, 40, 100)]
	check(not PlaytestVisionMask.has_line_of_sight(Vector2(-100, 0), Vector2(100, 0), walls), "wall occludes")
	check(PlaytestVisionMask.has_line_of_sight(Vector2(-100, 80), Vector2(100, 80), walls), "open route reveals")
	check(not PlaytestVisionMask.has_line_of_sight(Vector2(0, -100), Vector2(0, 100), walls), "vertical ray blocks")
	check(PlaytestRules.score_owner([0, 0]) == 0, "occupant count does not multiply scoring")
	check(PlaytestRules.score_owner([0, 1]) == -1, "contested scoring pauses")
	check(PlaytestRules.score_owner([]) == -1, "empty scoring pauses")
	Overhaul.session_enabled = true
	Overhaul.rules.preset = PlaytestRules.Preset.TEAM_OBJECTIVE
	MultiplayerManager.players.clear()
	for i in range(4):
		MultiplayerManager.players[i + 1] = {"name": "Test %d" % i, "character": Util.Character.Hekaset,
			"team_id": i % 2}
	var arena: Node = load("res://scenes/rework_arena.tscn").instantiate()
	get_tree().root.add_child(arena)
	get_tree().current_scene = arena
	await get_tree().process_frame
	var match_node: Node = arena.get_node("PlaytestMatch")
	for i in range(4):
		var player := MultiplayerManager._spawn_player_from_data({"id": i + 1, "team_id": i % 2, "spawn_slot": i / 2,
			"character": Util.Character.Hekaset, "position": Overhaul.spawn_position(i % 2, i / 2)})
		arena.get_node("Players").add_child(player)
		player.stats_update.deadgeLol.connect(match_node.on_death.bind(i + 1))
	match_node.begin()
	await get_tree().physics_frame
	var blue := match_node.get_player(1) as Player
	var ally := match_node.get_player(3) as Player
	var red := match_node.get_player(2) as Player
	check(blue.is_friendly_to(ally) and not blue.is_friendly_to(red), "teams distinguish ally from enemy")
	var hp := blue.stats_update.current_health
	blue._apply_damage(20, ally.player_id)
	check(is_equal_approx(blue.stats_update.current_health, hp), "allied direct damage rejected")
	blue._apply_damage(20, red.player_id)
	check(blue.stats_update.current_health < hp, "hostile direct damage works")
	# Both allied observers must lose LOS; shared sight otherwise legitimately reveals it.
	blue.position = Vector2(-600, -270)
	ally.position = blue.position
	red.position = Vector2(-200, -270)
	match_node._update_vision()
	match_node._update_presentations()
	check(not red.visible, "wall conceals opponent despite being within sight radius")
	ally.position = Vector2(-120, -270)
	match_node._update_vision()
	match_node._update_presentations()
	check(red.visible, "teammate shares sight")
	var grid: Node = arena.get_node("Path2D")
	blue.stats_update.set_mana(0)
	var count: int = get_tree().get_nodes_in_group("magic").size()
	grid.try_place_magic_for_player(blue.position, Magic.MagicType.NEUTRAL, Vector2i.ZERO, [], 1)
	check(get_tree().get_nodes_in_group("magic").size() == count, "server rejects unaffordable placement")
	blue.stats_update.set_mana(100)
	grid.try_place_magic_for_player(blue.position, Magic.MagicType.NEUTRAL, Vector2i(999, 999), [], 1)
	check(get_tree().get_nodes_in_group("magic").size() == count + 1, "server derives actual placement range")
	check(blue.stats_update.current_mana < 100, "placement spends authoritative mana")
	match_node._set_dead(3)
	match_node._update_vision()
	match_node._update_presentations()
	check(not red.visible, "dead teammate no longer provides vision")
	blue._apply_damage(999, 2)
	check(not blue.is_alive and match_node.respawns.has(1), "lethal damage schedules respawn")
	check(match_node.phase == "active", "team death does not end objective match")
	check(not match_node.accepts_input(1), "dead player cannot act")
	match_node._respawn(1)
	check(blue.is_alive and blue.spawn_protection > 0, "respawn restores life and protection")
	check(blue.stats_update.current_health == blue.stats_update.max_health, "respawn restores health")
	blue._apply_damage(50, 2)
	check(blue.stats_update.current_health == blue.stats_update.max_health, "respawn protection blocks damage")
	blue.spawn_protection = 0
	blue.position = Vector2.ZERO
	red.position = Vector2(700, 300)
	match_node.get_player(4).position = red.position
	match_node.elapsed = 20
	var score: float = match_node.scores[0]
	match_node._tick_objective(1)
	check(is_equal_approx(match_node.scores[0], score + 1), "solo team occupancy scores")
	red.position = Vector2.ZERO
	score = match_node.scores[0]
	match_node._tick_objective(1)
	check(is_equal_approx(match_node.scores[0], score), "enemy occupancy contests")
	print("PLAYTEST_SMOKE_COMPLETE failures=", failures)
	get_tree().quit(failures)
