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
	var hexagon := PackedVector2Array()
	for i in range(6):
		hexagon.append(Vector2.UP.rotated(i * PI / 3.0) * 60.0)
	var walls: Array[PackedVector2Array] = [hexagon]
	check(not PlaytestVisionMask.has_line_of_sight(Vector2(-100, 0), Vector2(100, 0), walls), "wall occludes")
	check(PlaytestVisionMask.has_line_of_sight(Vector2(-100, 80), Vector2(100, 80), walls), "open route reveals")
	check(not PlaytestVisionMask.has_line_of_sight(Vector2(0, -100), Vector2(0, 100), walls), "vertical ray blocks")
	check(PlaytestVisionMask.has_line_of_sight(Vector2(45, -58), Vector2(65, -58), walls), "hex corner stays open instead of using a bounding rectangle")
	check(PlaytestVisionMask.clip_segment(Vector2(-100, 0), Vector2(100, 0), walls).is_equal_approx(Vector2(-sqrt(3.0) * 30.0, 0)), "projectile clips at actual hex edge")
	_test_control_rules()
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
	var stale_cell: Vector2i = grid.local_to_map(blue.global_position)
	var stale = Node2D.new()
	stale.free()
	HexCells.cell_dict[stale_cell] = stale
	var mana_before_stale := blue.stats_update.current_mana
	grid.try_and_change_magic_for_player(blue.position, [], Magic.MagicType.LIGHT, 1, 100)
	check(HexCells.cell_dict[stale_cell] == null and blue.stats_update.current_mana == mana_before_stale, "freed cell occupant is cleaned before type checking or charging mana")
	grid.change_magic_in_cell_for_player(stale_cell, Magic.MagicType.LIGHT, 1)
	check(HexCells.wall_cells.size() == match_node.WALL_CELLS.size(), "wall layout occupies grid cells")
	for cell in HexCells.wall_cells:
		var wall: HexWall = HexCells.wall_cells[cell]
		check(HexCells.cell_dict[cell] == wall and wall.position.is_equal_approx(HexCells.map_to_local(cell)), "wall registry and grid center agree")
		check(wall.get_child(0).shape.points == HexCells.hex_polygon_shape.points, "wall collision reuses grid hex shape")
	var wall_cell: Vector2i = match_node.WALL_CELLS[0]
	var wall_reference: HexWall = HexCells.wall_cells[wall_cell]
	blue.position = HexCells.map_to_local(wall_cell)
	blue.stats_update.set_mana(100)
	grid.try_place_magic_for_player(blue.position, Magic.MagicType.NEUTRAL, Vector2i.ZERO, [], 1)
	grid.try_and_change_magic_for_player(blue.position, [], Magic.MagicType.LIGHT, 1, 100)
	check(HexCells.cell_dict[wall_cell] == wall_reference and blue.stats_update.current_mana == 100, "placement and transformation cannot replace terrain or spend mana on it")
	blue.position = Vector2(-600, -270)
	blue.stats_update.set_mana(0)
	var count: int = get_tree().get_nodes_in_group("magic").size()
	grid.try_place_magic_for_player(blue.position, Magic.MagicType.NEUTRAL, Vector2i.ZERO, [], 1)
	check(get_tree().get_nodes_in_group("magic").size() == count, "server rejects unaffordable placement")
	blue.stats_update.set_mana(100)
	grid.try_place_magic_for_player(blue.position, Magic.MagicType.NEUTRAL, Vector2i(999, 999), [], 1)
	check(get_tree().get_nodes_in_group("magic").size() == count + 1, "server derives actual placement range")
	check(blue.stats_update.current_mana < 100, "placement spends authoritative mana")
	# Remote allied magic acts as a scout even outside both players' sight.
	blue.position = Vector2(-740, -120)
	ally.position = Vector2(-740, 120)
	red.position = HexCells.map_to_local(Vector2i(5, 0))
	grid.place_magic_in_cell_for_player(Vector2i(4, 0), Magic.MagicType.NEUTRAL, 3)
	var scout := HexCells.cell_dict[Vector2i(4, 0)] as Magic
	match_node._update_vision()
	check(match_node.can_see(red.position), "allied prepared magic shares short-range vision")
	check(not match_node.can_see(HexCells.map_to_local(Vector2i(7, 0))), "magic does not grant player-sized vision")
	grid.change_magic_in_cell_for_player(Vector2i(4, 0), Magic.MagicType.LIGHT, 3)
	scout = HexCells.cell_dict[Vector2i(4, 0)] as Magic
	scout.start_rolling(PackedVector2Array([Vector2.ZERO, Vector2(800, 0)]))
	scout.global_position = HexCells.map_to_local(Vector2i(5, 0))
	red.position = HexCells.map_to_local(Vector2i(6, 0))
	match_node._update_vision()
	check(match_node.can_see(red.position), "travelling magic carries its vision")
	scout.fizzle()
	check(HexCells.get_magic_in_cell(Vector2i(4, 0)) == null, "fizzle leaves no stale cell reference")
	grid.place_magic_in_cell_for_player(Vector2i(7, 0), Magic.MagicType.NEUTRAL, 2)
	match_node._update_vision()
	check(not match_node.can_see(red.position), "fizzled allied magic loses sight and hostile magic grants none")
	grid.place_magic_in_cell_for_player(Vector2i(-5, -2), Magic.MagicType.NEUTRAL, 3)
	scout = HexCells.cell_dict[Vector2i(-5, -2)] as Magic
	scout.global_position = Vector2(-480, -170)
	blue.position = Vector2(-740, 300)
	ally.position = Vector2(-740, -500)
	red.position = HexCells.map_to_local(Vector2i(-4, -1))
	match_node._update_vision()
	check(not match_node.can_see(red.position), "hex wall blocks magic vision within its sight radius")
	scout.fizzle()
	blue.position = Vector2(-600, -270)
	ally.position = Vector2(-120, -270)
	red.position = Vector2(-200, -270)
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
	match_node.round_time = Overhaul.rules.objective_delay
	match_node._tick_objective(4)
	check(match_node.control.owner == -1 and match_node.control.capture_progress > 0.0, "point requires capture before ownership")
	match_node._tick_objective(4)
	check(match_node.control.owner == 0, "uncontested capture gives ownership")
	red.position = Vector2.ZERO
	var score: float = match_node.scores[0]
	match_node._tick_objective(1)
	check(match_node.scores[0] > score, "contesting freezes capture but not owner's percentage")
	match_node.control.winner = 0
	match_node._tick_objective(0.1)
	check(match_node.phase == "intermission" and match_node.round_wins[0] == 1, "first round win starts intermission")
	match_node._start_round()
	check(match_node.phase == "active" and match_node.round_number == 2 and match_node.control.owner == -1 and match_node.scores[0] == 0.0, "next round resets point and keeps round wins")
	check(HexCells.wall_cells.size() == match_node.WALL_CELLS.size() and HexCells.cell_dict[wall_cell] == wall_reference, "round reset preserves wall cells")
	match_node.round_time = Overhaul.rules.objective_delay
	match_node.control.winner = 0
	match_node._tick_objective(0.1)
	check(match_node.phase == "ended" and match_node.round_wins[0] == 2, "two round wins end the match")
	match_node._restart()
	check(match_node.round_wins[0] == 0 and match_node.control.owner == -1 and match_node.round_number == 1, "rematch clears round score and point ownership")
	print("PLAYTEST_SMOKE_COMPLETE failures=", failures)
	get_tree().quit(failures)


func _test_control_rules() -> void:
	var point := ControlPointState.new()
	point.tick(4.0, [1, 0])
	check(point.owner == -1 and is_equal_approx(point.capture_progress, 0.5), "partial capture does not own neutral point")
	point.tick(2.0, [1, 1])
	check(is_equal_approx(point.capture_progress, 0.5), "contesting freezes capture")
	point.tick(4.0, [1, 0])
	check(point.owner == 0, "capture finishes after uncontested progress")
	var before := point.percentages[0]
	point.tick(1.0, [0, 0])
	check(point.percentages[0] > before, "empty owned point still scores")
	before = point.percentages[0]
	point.tick(1.0, [1, 1])
	check(point.percentages[0] > before, "contested owned point still scores")
	point.tick(5.4, [0, 2])
	check(point.owner == 1, "two capturers flip ownership faster")
	before = point.percentages[0]
	point.tick(1.0, [0, 0])
	check(point.percentages[0] == before and point.percentages[1] > 0.0, "only current owner earns percentage")
	point.reset()
	point.tick(2.0, [1, 0])
	point.tick(5.0, [0, 0])
	check(point.capture_team == -1 and point.capture_progress == 0.0, "abandoned capture decays without checkpoints")
	point.reset()
	point.owner = 0
	point.percentages[0] = 99.5
	point.tick(2.0, [1, 1])
	check(point.overtime and point.winner == -1 and point.percentages[0] == 100.0, "late contest extends round at 100 percent")
	point.tick(4.0, [1, 0])
	check(point.winner == -1, "overtime allows a return to point")
	point.tick(0.1, [1, 1])
	check(point.overtime_remaining > 4.8, "enemy retouch refreshes overtime")
	point.tick(5.1, [1, 0])
	check(point.winner == 0, "clearing overtime awards round")
	point.reset()
	point.owner = 0
	point.percentages[0] = 99.5
	point.tick(1.0, [0, 0])
	check(point.winner == 0 and not point.overtime, "uncontested 100 percent wins without overtime")
	point.reset()
	point.owner = 0
	point.percentages[0] = 98.5
	point.tick(0.1, [0, 1])
	point.tick(2.0, [0, 0])
	check(point.overtime and point.winner == -1, "recent enemy touch qualifies for overtime")
	point.reset()
	point.owner = 0
	point.percentages[0] = 99.5
	point.tick(8.0, [0, 1])
	check(point.owner == 1 and not point.overtime and point.winner == -1, "full capture flips ownership and cancels old owner's overtime")
	point.percentages[0] = 100.0
	point.tick(8.0, [1, 0])
	check(point.owner == 0 and point.overtime and point.winner == -1, "retaking at 100 percent provides displaced team an overtime window")
	var restored := ControlPointState.new()
	restored.load_snapshot(point.snapshot())
	check(restored.owner == point.owner and restored.overtime and restored.percentages == point.percentages, "point snapshot preserves public state")
