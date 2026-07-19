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


func _ready() -> void:
	setup()
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
	_resolve_player_hits()
	_resolve_magic_hits()
	queue_redraw()


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

		if not _point_is_inside_lance(target_position, 22.0):
			continue

		var actual_damage := damage / 3.4
		target._apply_damage.rpc(actual_damage)


func _resolve_magic_hits() -> void:
	# Magic health is already resolved identically on each peer in the existing
	# collision system, so this deterministic beam check follows that convention.
	for node in get_tree().get_nodes_in_group("magic"):
		if not (node is Magic):
			continue

		var target := node as Magic
		if target == self or target.player_id == player_id:
			continue
		if target.is_queued_for_deletion():
			continue
		if not _point_is_inside_lance(target.global_position, 18.0):
			continue

		target.take_damage(damage)


func _point_is_inside_lance(point: Vector2, extra_radius: float) -> bool:
	var offset := point - global_position
	var forward_distance := offset.dot(firing_direction)
	if forward_distance < 0.0 or forward_distance > beam_range:
		return false

	var perpendicular_distance := absf(firing_direction.cross(offset))
	return perpendicular_distance <= beam_width * 0.5 + extra_radius


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(animation_time * 4.0)
	var dark_water := Color(0.02, 0.22, 0.48, 0.98)
	var pressure_blue := Color(0.28, 0.72, 1.0, 0.98)
	var highlight := Color(0.9, 0.99, 1.0, 0.98)

	draw_circle(Vector2.ZERO, 21.0, dark_water)
	draw_circle(Vector2.ZERO, 15.0 + pulse * 1.5, pressure_blue)

	var charge_angle := TAU * charge_progress
	draw_arc(Vector2.ZERO, 28.0, -PI * 0.5, -PI * 0.5 + charge_angle, 48, highlight, 4.0, true)

	if firing and not beam_visible:
		var telegraph_length := beam_range * firing_progress
		draw_line(
			Vector2.ZERO,
			firing_direction * telegraph_length,
			Color(0.78, 0.96, 1.0, 0.42),
			3.0,
			true
		)

	if beam_visible:
		draw_line(
			Vector2.ZERO,
			firing_direction * beam_range,
			Color(0.08, 0.48, 0.94, 0.55),
			beam_width,
			true
		)
		draw_line(
			Vector2.ZERO,
			firing_direction * beam_range,
			Color(0.88, 0.99, 1.0, 0.98),
			beam_width * 0.28,
			true
		)
