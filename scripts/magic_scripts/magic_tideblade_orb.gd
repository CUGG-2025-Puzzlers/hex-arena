extends Magic

class_name MagicTidebladeOrb


@export_group("Attack")
@export var max_attacks: int = 3
@export var swing_windup: float = 0.12
@export var swing_active_time: float = 0.16
@export var swing_recovery: float = 0.30
@export var remote_damage_multiplier: float = 0.55
@export var remote_radius_multiplier: float = 0.82

@export_group("Slash Hitbox")
@export_range(40.0, 260.0, 1.0) var swing_radius: float = 155.0
@export_range(0.0, 240.0, 1.0) var swing_inner_radius: float = 68.0
@export_range(20.0, 260.0, 1.0) var swing_arc_degrees: float = 150.0
@export_range(1.0, 40.0, 1.0) var swing_tip_thickness: float = 5.0

@export_group("Slash Visual")
@export_range(0.0, 1.0, 0.01) var swing_body_alpha: float = 0.68
@export_range(0.0, 1.0, 0.01) var swing_glow_alpha: float = 0.16
@export_range(1.0, 24.0, 1.0) var swing_edge_width: float = 8.0
@export_range(0.0, 24.0, 1.0) var swing_glow_width: float = 13.0
@export_range(8, 96, 1) var swing_visual_segments: int = 48


var attacks_remaining: int = 3
var creation_sequence: int = -1

var animation_time: float = 0.0

var local_swing_progress: float = 0.0
var local_swing_visible: bool = false
var local_swing_direction: Vector2 = Vector2.RIGHT

var remote_swings: Dictionary = {}
var next_remote_swing_id: int = 0

var local_swing_tween: Tween = null

static var next_sequence_by_player: Dictionary = {}


func _ready() -> void:
	setup()
	attacks_remaining = max_attacks
	add_to_group("tideblade_orb")
	_server_register_creation_sequence()
	queue_redraw()


func _process(delta: float) -> void:
	super._process(delta)
	animation_time += delta
	queue_redraw()


func handles_player_contact() -> bool:
	# Tideblade is a stationary weapon. Its explicit slash handles damage.
	return true


func can_be_cut_by_wire() -> bool:
	return false


func can_activate_water_attack() -> bool:
	return (
		attacks_remaining > 0
		and not rolling
		and not is_queued_for_deletion()
	)


func start_rolling(direction_path: PackedVector2Array) -> void:
	if not can_activate_water_attack() or direction_path.size() < 2:
		return

	var direction: Vector2 = (
		direction_path[direction_path.size() - 1]
		- direction_path[0]
	)

	if direction.is_zero_approx():
		return

	rolling_dir = direction.normalized()
	_begin_local_swing(rolling_dir)


func _begin_local_swing(direction: Vector2) -> void:
	rolling = true
	local_swing_direction = direction.normalized()
	local_swing_progress = 0.0
	local_swing_visible = true

	if local_swing_tween != null:
		local_swing_tween.kill()

	local_swing_tween = create_tween()

	(
		local_swing_tween
		.tween_method(
			_set_local_swing_progress,
			0.0,
			0.42,
			swing_windup
		)
		.set_trans(Tween.TRANS_QUAD)
		.set_ease(Tween.EASE_IN)
	)

	local_swing_tween.tween_callback(_resolve_local_swing)

	(
		local_swing_tween
		.tween_method(
			_set_local_swing_progress,
			0.42,
			1.0,
			swing_active_time
		)
		.set_trans(Tween.TRANS_QUAD)
		.set_ease(Tween.EASE_OUT)
	)

	local_swing_tween.tween_interval(swing_recovery)
	local_swing_tween.tween_callback(_finish_local_swing)


func _set_local_swing_progress(value: float) -> void:
	local_swing_progress = value
	queue_redraw()


func _resolve_local_swing() -> void:
	if attacks_remaining <= 0 or is_queued_for_deletion():
		return

	_resolve_swing_hits(
		local_swing_direction,
		1.0,
		1.0
	)

	attacks_remaining -= 1
	_trigger_flow_circuit(local_swing_direction)
	queue_redraw()


func _finish_local_swing() -> void:
	rolling = false
	local_swing_visible = false
	local_swing_progress = 0.0
	queue_redraw()

	if attacks_remaining <= 0:
		call_deferred("fizzle")


func perform_remote_swing(direction: Vector2) -> void:
	if attacks_remaining <= 0 or is_queued_for_deletion():
		return

	if direction.is_zero_approx():
		return

	next_remote_swing_id += 1
	var swing_id: int = next_remote_swing_id

	remote_swings[swing_id] = {
		"direction": direction.normalized(),
		"progress": 0.0,
	}

	var remote_tween: Tween = create_tween()

	(
		remote_tween
		.tween_method(
			func(value: float) -> void:
				_set_remote_swing_progress(swing_id, value),
			0.0,
			0.42,
			swing_windup
		)
		.set_trans(Tween.TRANS_QUAD)
		.set_ease(Tween.EASE_IN)
	)

	remote_tween.tween_callback(
		func() -> void:
			if not remote_swings.has(swing_id):
				return

			var swing: Dictionary = remote_swings[swing_id]
			var swing_direction: Vector2 = swing["direction"]
			_resolve_swing_hits(
				swing_direction,
				remote_damage_multiplier,
				remote_radius_multiplier
			)
	)

	(
		remote_tween
		.tween_method(
			func(value: float) -> void:
				_set_remote_swing_progress(swing_id, value),
			0.42,
			1.0,
			swing_active_time
		)
		.set_trans(Tween.TRANS_QUAD)
		.set_ease(Tween.EASE_OUT)
	)

	remote_tween.tween_callback(
		func() -> void:
			remote_swings.erase(swing_id)
			queue_redraw()
	)


func _set_remote_swing_progress(
	swing_id: int,
	value: float
) -> void:
	if not remote_swings.has(swing_id):
		return

	var swing: Dictionary = remote_swings[swing_id]
	swing["progress"] = value
	remote_swings[swing_id] = swing
	queue_redraw()


func _resolve_swing_hits(
	direction: Vector2,
	damage_multiplier: float,
	radius_multiplier: float
) -> void:
	# Player damage remains server-authoritative, matching Hekaset's explicit
	# attacks. Magic health is resolved deterministically on every peer, matching
	# Pressure Lance and the existing magic-vs-magic collision convention.
	_resolve_player_hits(
		direction,
		damage_multiplier,
		radius_multiplier
	)
	_resolve_magic_hits(
		direction,
		damage_multiplier,
		radius_multiplier
	)


func _resolve_player_hits(
	direction: Vector2,
	damage_multiplier: float,
	radius_multiplier: float
) -> void:
	if not multiplayer.is_server():
		return

	var players_node: Node = get_tree().current_scene.find_child(
		"Players"
	)

	if players_node == null:
		return

	for child: Node in players_node.get_children():
		if not (child is Player):
			continue

		var target: Player = child as Player

		if target.player_id == player_id:
			continue

		var target_position: Vector2 = target.global_position
		var target_shape: CollisionShape2D = (
			target.get_node_or_null("CollisionShape2D")
			as CollisionShape2D
		)

		if target_shape != null:
			target_position = target_shape.global_position

		var offset: Vector2 = target_position - global_position

		if not _is_point_inside_slash(
			offset,
			direction,
			radius_multiplier
		):
			continue

		var actual_damage: float = (
			(damage / 3.4)
			* damage_multiplier
		)

		target._apply_damage.rpc(actual_damage)


func _resolve_magic_hits(
	direction: Vector2,
	damage_multiplier: float,
	radius_multiplier: float
) -> void:
	# Match Magic._on_area_entered(): the cleave behaves like a real magic
	# attack, so it can break Light magic and damage Heavy magic, Shields,
	# stationary setup magic, and other hostile magic subclasses.
	for node: Node in get_tree().get_nodes_in_group("magic"):
		if not (node is Magic):
			continue

		var target: Magic = node as Magic

		if target == self:
			continue

		if target.is_queued_for_deletion():
			continue

		var should_collide: bool = (
			target.player_id != player_id
			or collides_w_own
			or target.collides_w_own
		)

		if not should_collide:
			continue

		var offset: Vector2 = (
			target.global_position
			- global_position
		)

		if not _is_point_inside_slash(
			offset,
			direction,
			radius_multiplier
		):
			continue

		# Use the Tideblade's normal MagicStats damage, exactly like ordinary
		# magic-on-magic collision. Conducted cleaves retain their multiplier.
		target.take_damage(
			damage * damage_multiplier
		)


func _is_point_inside_slash(
	offset: Vector2,
	direction: Vector2,
	radius_multiplier: float
) -> bool:
	if offset.is_zero_approx() or direction.is_zero_approx():
		return false

	var outer_radius: float = swing_radius * radius_multiplier
	var inner_radius: float = swing_inner_radius * radius_multiplier
	var distance_from_orb: float = offset.length()

	if distance_from_orb > outer_radius:
		return false

	var half_angle: float = deg_to_rad(
		swing_arc_degrees * 0.5
	)

	var signed_angle: float = wrapf(
		offset.angle() - direction.angle(),
		-PI,
		PI
	)

	if absf(signed_angle) > half_angle:
		return false

	# Match the visual taper. The slash is narrow at both ends and widest
	# through the middle of the arc.
	var angle_fraction: float = inverse_lerp(
		-half_angle,
		half_angle,
		signed_angle
	)

	var taper: float = sin(
		clampf(angle_fraction, 0.0, 1.0) * PI
	)

	var maximum_body_thickness: float = maxf(
		1.0,
		outer_radius - inner_radius
	)

	var scaled_tip_thickness: float = clampf(
		swing_tip_thickness * radius_multiplier,
		1.0,
		maximum_body_thickness
	)

	var tapered_inner_radius: float = lerpf(
		outer_radius - scaled_tip_thickness,
		inner_radius,
		taper
	)

	return distance_from_orb >= tapered_inner_radius


func _trigger_flow_circuit(direction: Vector2) -> void:
	for node: Node in get_tree().get_nodes_in_group(
		"water_orb_wire"
	):
		if (
			not is_instance_valid(node)
			or node.is_queued_for_deletion()
		):
			continue

		if int(node.get("player_id")) != player_id:
			continue

		if not node.call("connects_cell", self_cell):
			continue

		node.call(
			"conduct_attack_from",
			self_cell,
			direction
		)


func _server_register_creation_sequence() -> void:
	if not multiplayer.is_server():
		return

	if player_id <= 0 or player_owner == null:
		return

	var next_sequence: int = int(
		next_sequence_by_player.get(player_id, 0)
	) + 1

	next_sequence_by_player[player_id] = next_sequence
	creation_sequence = next_sequence


func _draw() -> void:
	var pulse: float = 0.5 + 0.5 * sin(
		animation_time * 3.0
	)

	var dark_water := Color(0.04, 0.32, 0.62, 0.98)
	var water := Color(0.38, 0.84, 1.0, 0.98)
	var highlight := Color(0.92, 0.99, 1.0, 0.98)

	draw_circle(
		Vector2.ZERO,
		23.0 + pulse * 2.0,
		Color(0.15, 0.66, 1.0, 0.28)
	)

	draw_circle(Vector2.ZERO, 17.0, dark_water)
	draw_circle(Vector2(-2.0, -1.0), 13.0, water)
	draw_circle(Vector2(-6.0, -6.0), 3.5, highlight)

	for index: int in range(max_attacks):
		var angle: float = (
			-PI * 0.85
			+ float(index) * PI * 0.85
		)

		var pip_position: Vector2 = (
			Vector2.RIGHT.rotated(angle) * 30.0
		)

		var pip_color: Color = (
			water
			if index < attacks_remaining
			else Color(0.15, 0.25, 0.32, 0.55)
		)

		draw_circle(pip_position, 3.7, pip_color)

	if local_swing_visible:
		_draw_swing_ribbon(
			local_swing_direction,
			local_swing_progress,
			1.0,
			1.0
		)

	for swing_value: Variant in remote_swings.values():
		var swing: Dictionary = swing_value
		var swing_direction: Vector2 = swing["direction"]
		_draw_swing_ribbon(
			swing_direction,
			float(swing["progress"]),
			remote_radius_multiplier,
			0.72
		)


func _draw_swing_ribbon(
	direction: Vector2,
	progress: float,
	radius_multiplier: float,
	alpha_multiplier: float
) -> void:
	if direction.is_zero_approx():
		return

	var visible_fraction: float = clampf(
		progress / 0.42,
		0.0,
		1.0
	)

	if visible_fraction <= 0.001:
		return

	var fade_alpha: float = 1.0

	if progress > 0.42:
		fade_alpha = 1.0 - clampf(
			(progress - 0.42) / 0.58,
			0.0,
			1.0
		)

	var final_alpha: float = alpha_multiplier * fade_alpha

	if final_alpha <= 0.001:
		return

	var outer_radius: float = swing_radius * radius_multiplier
	var inner_radius: float = (
		swing_inner_radius * radius_multiplier
	)

	var half_angle: float = deg_to_rad(
		swing_arc_degrees * 0.5
	)

	var center_angle: float = direction.angle()
	var start_angle: float = center_angle - half_angle
	var full_end_angle: float = center_angle + half_angle
	var current_end_angle: float = lerpf(
		start_angle,
		full_end_angle,
		visible_fraction
	)

	var segment_count: int = maxi(
		8,
		int(
			ceil(
				float(swing_visual_segments)
				* visible_fraction
			)
		)
	)

	var outer_points := PackedVector2Array()
	var inner_points := PackedVector2Array()
	var polygon_points := PackedVector2Array()

	var maximum_body_thickness: float = maxf(
		1.0,
		outer_radius - inner_radius
	)

	var scaled_tip_thickness: float = clampf(
		swing_tip_thickness * radius_multiplier,
		1.0,
		maximum_body_thickness
	)

	for index: int in range(segment_count + 1):
		var fraction: float = (
			float(index) / float(segment_count)
		)

		var angle: float = lerpf(
			start_angle,
			current_end_angle,
			fraction
		)

		var outer_point: Vector2 = (
			Vector2.RIGHT.rotated(angle)
			* outer_radius
		)

		outer_points.append(outer_point)
		polygon_points.append(outer_point)

	for index: int in range(segment_count, -1, -1):
		var fraction: float = (
			float(index) / float(segment_count)
		)

		var angle: float = lerpf(
			start_angle,
			current_end_angle,
			fraction
		)

		var taper: float = sin(fraction * PI)

		var current_inner_radius: float = lerpf(
			outer_radius - scaled_tip_thickness,
			inner_radius,
			taper
		)

		var inner_point: Vector2 = (
			Vector2.RIGHT.rotated(angle)
			* current_inner_radius
		)

		inner_points.insert(0, inner_point)
		polygon_points.append(inner_point)

	var glow_color := Color(
		0.68,
		0.91,
		1.0,
		swing_glow_alpha * final_alpha
	)

	draw_polyline(
		outer_points,
		glow_color,
		swing_edge_width + swing_glow_width,
		true
	)

	var body_color := Color(
		1.0,
		1.0,
		1.0,
		swing_body_alpha * final_alpha
	)

	draw_colored_polygon(
		polygon_points,
		body_color
	)

	draw_polyline(
		outer_points,
		Color(1.0, 1.0, 1.0, 0.98 * final_alpha),
		swing_edge_width,
		true
	)

	draw_polyline(
		inner_points,
		Color(0.76, 0.94, 1.0, 0.62 * final_alpha),
		maxf(2.0, swing_edge_width * 0.42),
		true
	)
