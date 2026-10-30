extends Node2D

## Read-only view of replicated gameplay. Never spends mana or dispatches casts.
const STATES := [Magic.MagicType.PASSIVE, Magic.MagicType.LIGHT, Magic.MagicType.HEAVY]
const ACTIONS := ["turn_to_passive", "turn_to_light", "turn_to_heavy"]
const KEYS := ["Q", "E", "R"]
var entries: Array[Dictionary] = []
var previews: Array[Dictionary] = []
var _sample: float = 0.0
var _movement: Dictionary = {}

func _ready() -> void:
	z_index = 23
	add_to_group("combat_readability")

func _process(delta: float) -> void:
	_sample -= delta
	if _sample <= 0.0:
		_sample = 0.05
		refresh()
	queue_redraw()

func refresh() -> void:
	entries.clear()
	previews.clear()
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return
	var player := scene.get_node_or_null("Players/" + str(Juice.local_id())) as Player
	if not is_instance_valid(player):
		return
	var grid := HexCells.player_unique_instance
	if not is_instance_valid(grid):
		return
	var candidates: Array[Magic] = []
	for node in get_tree().get_nodes_in_group("magic"):
		if node is Magic and not node.is_queued_for_deletion() and node.visible and Juice.visible_at(node.global_position, node.player_id):
			if node.global_position.distance_squared_to(player.global_position) < 850.0 * 850.0:
				candidates.append(node)
	candidates.sort_custom(func(a: Magic, b: Magic): return a.global_position.distance_squared_to(player.global_position) < b.global_position.distance_squared_to(player.global_position))
	for magic in candidates.slice(0, 64):
		if not magic.rolling or magic is MagicTidebladeOrb:
			entries.append({"magic": weakref(magic), "state": state_of(magic)})
	var input := player.get_node("InputSynchronizer") as MultiplayerInput
	if player.is_gameplay_input_blocked() or input.ui_input_blocked or Juice.settings_open:
		return
	for state in STATES:
		# Passive is a wire command on this character, not a Passive transformation.
		if state == Magic.MagicType.PASSIVE and player.has_node("WaterOrbWireController"):
			continue
		previews.append_array(plan(player, state))
	for child in scene.get_node("Players").get_children():
		if child is Player:
			_movement_accent(child)

func _movement_accent(player: Player) -> void:
	var id := player.get_instance_id()
	var moving := player.velocity.length() > 20.0
	var previous: Dictionary = _movement.get(id, {})
	_movement[id] = {"moving": moving, "direction": player.velocity.normalized()}
	if previous.is_empty() or not player.is_alive or not player.visible or not Juice.visible_at(player.global_position, player.player_id):
		return
	if moving != bool(previous.moving) and not player.is_dashing() and not player.is_channeling():
		if Juice._gate("stride:%d" % id, 0.25):
			Juice.world("stride" if moving else "stop", player.global_position, player.player_id, player.velocity.normalized() if moving else previous.direction)

func state_of(magic: Magic) -> Dictionary:
	var result := {"kind": "unclaimed" if magic.player_id < 0 else "prepared", "progress": 1.0, "uses": -1}
	if magic is MagicPressureLance:
		result.kind = "charging" if magic.charge_progress < 1.0 else "ready"
		result.progress = magic.charge_progress
	elif magic is MagicTidebladeOrb:
		result.uses = magic.attacks_remaining
		result.kind = "exhausted" if magic.attacks_remaining <= 0 else ("recovering" if magic.rolling else "ready")
	elif magic is MagicShield and magic.expires:
		for child in magic.get_children():
			if child is Timer and not child.is_stopped():
				result.progress = child.time_left / maxf(child.wait_time, 0.01)
				if child.time_left <= 1.25:
					result.kind = "expiring"
	return result

func plan(player: Player, state: Magic.MagicType) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var grid := HexCells.player_unique_instance
	var cell := grid.local_to_map(player.get_node("CollisionShape2D").global_position)
	var cells: Array = []
	for offset in player.radius_cells:
		cells.append(grid.local_to_map(HexCells.map_to_local(cell) + HexCells.map_to_local(offset)))
	cells.erase(cell)
	cells.append(cell)
	var blocked: Array = []
	for other in get_tree().current_scene.get_node("Players").get_children():
		# Hidden occupants must never be disclosed by a preview.
		if other is Player and other.is_alive and not player.is_friendly_to(other) and other.visible and Juice.visible_at(other.global_position, other.player_id):
			blocked.append(grid.local_to_map(other.global_position))
	var mana := player.stats_update.current_mana
	while not cells.is_empty():
		var at: Vector2i = cells.pop_back()
		var magic := HexCells.get_magic_in_cell(at)
		if magic == null or not magic.visible or not Juice.visible_at(magic.global_position, magic.player_id):
			continue
		var cost := magic.change_state_cost(state)
		var status := "valid"
		if player.is_gameplay_input_blocked() or (magic.player_id >= 0 and magic.player_id != player.player_id) or at in blocked or (at == cell and state == Magic.MagicType.PASSIVE) or cost < 0.0:
			status = "blocked"
		elif mana < cost:
			status = "mana"
		else:
			mana -= cost
		var stats := magic.own_transforms.get(state) as MagicStats
		result.append({"magic": weakref(magic), "cell": at, "state": state, "status": status, "cost": cost, "name": stats.magic_name if stats != null else "Unavailable"})
	return result

func key_label(slot: int) -> String:
	for event in InputMap.action_get_events(ACTIONS[slot]):
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode if event.physical_keycode != 0 else event.keycode)
	return KEYS[slot]

func _draw() -> void:
	if Juice.intensity <= 0.0:
		return
	var alpha := Juice.intensity * 0.8
	for entry in entries:
		var magic = entry.magic.get_ref()
		if not is_instance_valid(magic) or magic.is_queued_for_deletion() or not magic.visible or not Juice.visible_at(magic.global_position, magic.player_id):
			continue
		var center := to_local(magic.global_position) + Vector2(0, 34)
		var state: Dictionary = entry.state
		var color := Color("baddeb") if Overhaul.local_friendly(magic.player_id) else Color("ffb8b0")
		if magic.player_id < 0:
			color = Color("d2c8b2")
		color.a = alpha
		draw_circle(center, 9, Color(0.04, 0.08, 0.12, alpha * 0.85))
		match state.kind:
			"unclaimed":
				for i in range(3):
					draw_arc(center, 5, i * TAU / 3, i * TAU / 3 + 1.0, 6, color, 1.2, true)
			"charging":
				draw_arc(center, 6, -PI / 2, -PI / 2 + maxf(0.03, state.progress) * TAU, 20, color, 2, true)
			"ready":
				draw_polyline(PackedVector2Array([center + Vector2(0,-5), center + Vector2(5,0), center + Vector2(0,5), center + Vector2(-5,0), center + Vector2(0,-5)]), color, 1.5, true)
			"recovering":
				draw_arc(center, 6, 0, PI, 12, color, 1.5, true)
			"exhausted":
				draw_line(center - Vector2(4,4), center + Vector2(4,4), color, 1.5)
				draw_line(center - Vector2(4,-4), center + Vector2(4,-4), color, 1.5)
			"expiring":
				draw_arc(center, 7, -PI / 2, -PI / 2 + maxf(0.03, state.progress) * TAU, 20, color, 1.5, true)
				draw_line(center - Vector2(3, 3), center + Vector2(3, 3), color, 1.5)
			_:
				draw_rect(Rect2(center - Vector2(3,3), Vector2(6,6)), color, false, 1.2)
		if int(state.uses) >= 0:
			for i in range(mini(int(state.uses), 6)):
				draw_circle(center + Vector2((i - (state.uses - 1) * 0.5) * 5, 10), 1.4, color)
	var grid := HexCells.player_unique_instance
	if not is_instance_valid(grid):
		return
	var hovered := grid.local_to_map(grid.get_global_mouse_position())
	for preview in previews:
		var magic = preview.magic.get_ref()
		if not is_instance_valid(magic) or magic.is_queued_for_deletion() or not magic.visible or not Juice.visible_at(magic.global_position, magic.player_id):
			continue
		var slot := STATES.find(preview.state)
		var color := Color("91e1b2") if preview.status == "valid" else (Color("f4c76d") if preview.status == "mana" else Color("d6b4bc"))
		color.a = alpha
		var center := to_local(magic.global_position) + Vector2((slot - 1) * 18, 55)
		draw_rect(Rect2(center + Vector2(-8,-15), Vector2(16,21)), Color(0.04,0.08,0.12,alpha * 0.85))
		draw_string(ThemeDB.fallback_font, center + Vector2(-3,-5), key_label(slot), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, color)
		# Check / horizontal mana bar / cross communicate status without color.
		if preview.status == "valid":
			draw_polyline(PackedVector2Array([center + Vector2(-3,0), center + Vector2(-1,3), center + Vector2(4,-3)]), color, 1.5, true)
		elif preview.status == "mana":
			draw_line(center - Vector2(4,0), center + Vector2(4,0), color, 2)
		else:
			draw_line(center - Vector2(3,3), center + Vector2(3,3), color, 1.2)
			draw_line(center - Vector2(3,-3), center + Vector2(3,-3), color, 1.2)
		if preview.cell == hovered:
			var origin := to_local(magic.global_position) + Vector2(65, -30 + slot * 20)
			var reason := "" if preview.status == "valid" else (" · NEED MANA" if preview.status == "mana" else " · BLOCKED")
			var text := "%s  %s  %s%s" % [key_label(slot), preview.name, str(int(preview.cost)) if preview.cost >= 0 else "—", reason]
			var width := ThemeDB.fallback_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_rect(Rect2(origin + Vector2(-5,-15), Vector2(width + 10,20)), Color(0.04,0.08,0.12,0.9 * Juice.intensity))
			draw_string_outline(ThemeDB.fallback_font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color("142231"))
			draw_string(ThemeDB.fallback_font, origin, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)
