extends Magic
class_name MagicPressureLance

@export var charge_time: float = 1.35
@export var beam_range: float = 760.0
@export var beam_width: float = 34.0
@export var firing_windup: float = 0.18
@export var beam_visible_time: float = 0.18

var charge_progress: float = 0.0
var firing: bool = false
var firing_direction: Vector2 = Vector2.RIGHT
var firing_progress: float = 0.0
var beam_visible: bool = false
var firing_tween: Tween = null
var animation_time: float = 0.0
var effective_beam_range: float = 760.0


func _ready() -> void:
	setup()
	effective_beam_range = beam_range
	queue_redraw()


func _process(delta: float) -> void:
	super._process(delta)
	animation_time += delta

	if not firing and charge_progress < 1.0:
		charge_progress = minf(charge_progress + delta / maxf(charge_time, 0.01), 1.0)

	queue_redraw()


func handles_player_contact() -> bool:
	# The placed lance does not damage a player merely for walking into it.
	return true


func can_be_cut_by_wire() -> bool:
	return false


func can_activate_water_attack() -> bool:
	return charge_progress >= 1.0 and not firing and not rolling and not is_queued_for_deletion()


func start_rolling(direction_path: PackedVector2Array) -> void:
	if not can_activate_water_attack() or direction_path.size() < 2:
		return

	var direction := direction_path[direction_path.size() - 1] - direction_path[0]
	if direction.is_zero_approx():
		return

	firing_direction = direction.normalized()
	rolling_dir = firing_direction
	rolling = true
	firing = true
	firing_progress = 0.0
	beam_visible = false
	effective_beam_range = beam_range

	if HexCells.cell_dict.has(self_cell) and HexCells.cell_dict[self_cell] == self:
		HexCells.cell_dict[self_cell] = null

	if firing_tween != null:
		firing_tween.kill()

	firing_tween = create_tween()
	(
		firing_tween
		. tween_method(_set_firing_progress, 0.0, 1.0, firing_windup)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	firing_tween.tween_callback(_fire_lance)
	firing_tween.tween_interval(beam_visible_time)
	firing_tween.tween_callback(fizzle)


func _set_firing_progress(value: float) -> void:
	firing_progress = value
	queue_redraw()


func _fire_lance() -> void:
	beam_visible = true
	var blocker := _find_blocking_shield()
	if blocker != null:
		var offset := blocker.global_position - global_position
		effective_beam_range = maxf(0.0, offset.dot(firing_direction) - _hex_radius() * 0.65)
		blocker.take_damage(damage)
		Telemetry.record_damage_blocked(
			blocker.player_id, damage / 3.4, blocker.get_telemetry_name()
		)

	_resolve_player_hits()
	_resolve_magic_hits(blocker)
	queue_redraw()


func _find_blocking_shield() -> MagicShield:
	var nearest: MagicShield = null
	var nearest_distance := beam_range + 1.0

	for node in get_tree().get_nodes_in_group("magic"):
		if not (node is MagicShield):
			continue
		var shield := node as MagicShield
		if shield.player_id == player_id or shield.is_queued_for_deletion():
			continue

		var offset := shield.global_position - global_position
		var forward_distance := offset.dot(firing_direction)
		if forward_distance <= 0.0 or forward_distance > beam_range:
			continue

		var perpendicular_distance := absf(firing_direction.cross(offset))
		if perpendicular_distance > beam_width * 0.5 + _hex_radius() * 0.8:
			continue

		if forward_distance < nearest_distance:
			nearest_distance = forward_distance
			nearest = shield

	return nearest


func _hex_radius() -> float:
	var grid := HexCells.player_unique_instance
	return grid.r if is_instance_valid(grid) else 60.0


func _resolve_player_hits() -> void:
	if not multiplayer.is_server():
		return

	var players_node := get_tree().current_scene.find_child("Players")
	if players_node == null:
		return

	for child in players_node.get_children():
		if not (child is Player):
			continue

		var target := child as Player
		if target.player_id == player_id:
			continue

		var target_position := target.global_position
		var target_shape := target.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if target_shape != null:
			target_position = target_shape.global_position

		if not _point_is_inside_lance(target_position, 22.0, effective_beam_range):
			continue

		var actual_damage := damage / 3.4
		target._apply_damage.rpc(actual_damage, player_id, get_telemetry_name())


func _resolve_magic_hits(blocker: MagicShield) -> void:
	# Magic health is already resolved identically on each peer in the existing
	# collision system, so this deterministic beam check follows that convention.
	for node in get_tree().get_nodes_in_group("magic"):
		if not (node is Magic):
			continue

		var target := node as Magic
		if target == self or target == blocker or target.player_id == player_id:
			continue
		if target.is_queued_for_deletion():
			continue
		if not _point_is_inside_lance(target.global_position, 18.0, effective_beam_range):
			continue

		target.take_damage(damage)


func _point_is_inside_lance(point: Vector2, extra_radius: float, max_range: float = -1.0) -> bool:
	var offset := point - global_position
	var forward_distance := offset.dot(firing_direction)
	var allowed_range := beam_range if max_range < 0.0 else max_range
	if forward_distance < 0.0 or forward_distance > allowed_range:
		return false

	var perpendicular_distance := absf(firing_direction.cross(offset))
	return perpendicular_distance <= beam_width * 0.5 + extra_radius


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(animation_time * 7.0)
	var dark_water := Color(0.02, 0.22, 0.48, 0.98)
	var pressure_blue := Color(0.28, 0.72, 1.0, 0.98)
	var highlight := Color(0.9, 0.99, 1.0, 0.98)

	draw_circle(Vector2.ZERO, 21.0, dark_water)
	draw_circle(Vector2.ZERO, 15.0 + pulse * 1.5, pressure_blue)

	var charge_angle := TAU * charge_progress
	draw_arc(Vector2.ZERO, 28.0, -PI * 0.5, -PI * 0.5 + charge_angle, 48, highlight, 4.0, true)

	if firing and not beam_visible:
		# Show the entire threatened lane immediately. The color intensifies from
		# warning yellow to danger red as the shot approaches instead of revealing
		# the danger area progressively from the caster outward.
		var warning := Color(
			1.0,
			lerpf(0.82, 0.12, firing_progress),
			0.06,
			0.30 + pulse * 0.18
		)
		draw_line(
			Vector2.ZERO,
			firing_direction * beam_range,
			Color(0.02, 0.02, 0.02, 0.68),
			beam_width + 8.0,
			true
		)
		draw_line(
			Vector2.ZERO,
			firing_direction * beam_range,
			warning,
			beam_width * 0.72,
			true
		)
		draw_line(
			Vector2.ZERO,
			firing_direction * beam_range,
			Color(1.0, 0.95, 0.72, 0.86),
			3.0,
			true
		)

	if beam_visible:
		draw_line(
			Vector2.ZERO,
			firing_direction * effective_beam_range,
			Color(0.08, 0.48, 0.94, 0.55),
			beam_width,
			true
		)
		draw_line(
			Vector2.ZERO,
			firing_direction * effective_beam_range,
			Color(0.88, 0.99, 1.0, 0.98),
			beam_width * 0.28,
			true
		)
