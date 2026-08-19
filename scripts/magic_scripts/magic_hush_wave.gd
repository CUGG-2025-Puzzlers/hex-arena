extends Magic
class_name MagicHushWave

# The spell stays anchored to the transformed Basic Magic. A narrow wave bar
# sweeps through a fixed square footprint instead of the whole square expanding.
@export var wave_size: float = 360.0
@export var wave_thickness: float = 72.0
@export var pre_sweep_delay: float = 0.12
@export var sweep_duration: float = 0.64
@export var linger_duration: float = 0.12
@export var silence_duration: float = 0.70
@export var starting_slow_multiplier: float = 0.35
@export var slow_fade_duration: float = 2.25

var cast_elapsed: float = 0.0
var animation_time: float = 0.0
var hit_player_ids: Dictionary = {}


func _process(delta: float) -> void:
	super._process(delta)
	animation_time += delta

	if rolling:
		_advance_cast(delta)

	queue_redraw()


func handles_player_contact() -> bool:
	return true


func can_be_cut_by_wire() -> bool:
	return rolling and not is_queued_for_deletion()


func start_rolling(path: PackedVector2Array) -> void:
	if rolling or path.size() < 2:
		return

	var direction := path[path.size() - 1] - path[0]
	if direction.is_zero_approx():
		return

	rolling_dir = direction.normalized()
	rotation = rolling_dir.angle()
	cast_elapsed = 0.0
	hit_player_ids.clear()
	rolling = true

	if HexCells.cell_dict.has(self_cell) and HexCells.cell_dict[self_cell] == self:
		HexCells.cell_dict[self_cell] = null

	started_rolling.emit()


func _advance_cast(delta: float) -> void:
	var previous_elapsed := cast_elapsed
	cast_elapsed += delta

	if multiplayer.is_server() and cast_elapsed >= pre_sweep_delay:
		var previous_front := _get_sweep_front(previous_elapsed)
		var current_front := _get_sweep_front(cast_elapsed)
		_resolve_swept_hits(previous_front, current_front)

	var total_duration := pre_sweep_delay + sweep_duration + linger_duration
	if cast_elapsed >= total_duration:
		fizzle()


func _get_sweep_progress(time: float) -> float:
	return clampf(
		(time - pre_sweep_delay) / maxf(sweep_duration, 0.01),
		0.0,
		1.0
	)


func _get_sweep_front(time: float) -> float:
	var half_thickness := wave_thickness * 0.5
	return lerpf(
		-half_thickness,
		wave_size + half_thickness,
		_get_sweep_progress(time)
	)


# Query the same Area2D collision layers used by ordinary projectile magic.
# This tests the moving wave strip against each character's full hurtbox shape,
# rather than checking one point near the CharacterBody2D origin at the feet.
func _resolve_swept_hits(previous_front: float, current_front: float) -> void:
	var half_thickness := wave_thickness * 0.5
	var swept_left := clampf(
		minf(previous_front, current_front) - half_thickness,
		0.0,
		wave_size
	)
	var swept_right := clampf(
		maxf(previous_front, current_front) + half_thickness,
		0.0,
		wave_size
	)

	if swept_right <= swept_left:
		return

	var sweep_shape := RectangleShape2D.new()
	sweep_shape.size = Vector2(
		swept_right - swept_left,
		wave_size
	)

	var local_center := Vector2(
		(swept_left + swept_right) * 0.5,
		0.0
	)

	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = sweep_shape
	query.transform = Transform2D(
		global_rotation,
		to_global(local_center)
	)
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.exclude = [get_rid()]

	var hits := get_world_2d().direct_space_state.intersect_shape(query, 64)
	for hit in hits:
		var collider := hit.get("collider") as Node
		var target := _find_player_ancestor(collider)

		if target == null:
			continue
		if target.player_id == player_id:
			continue
		if hit_player_ids.has(target.player_id):
			continue

		hit_player_ids[target.player_id] = true
		target._apply_damage.rpc(damage, player_id, get_telemetry_name())
		target._apply_silence.rpc(silence_duration, player_id, get_telemetry_name())
		target._apply_fading_slow.rpc(
			"hush_wave_%s_%s" % [player_id, get_instance_id()],
			starting_slow_multiplier,
			slow_fade_duration
		)


func _find_player_ancestor(node: Node) -> Player:
	var current := node
	while current != null:
		if current is Player:
			return current as Player
		current = current.get_parent()
	return null


func _draw() -> void:
	if not rolling:
		return

	var half_size := wave_size * 0.5
	var square := Rect2(
		Vector2(0.0, -half_size),
		Vector2(wave_size, wave_size)
	)
	var pulse := 0.5 + 0.5 * sin(animation_time * 7.0)

	# The full footprint is shown immediately as a subtle fixed telegraph.
	draw_rect(
		square,
		Color(0.58, 0.68, 1.0, 0.07),
		true
	)
	draw_rect(
		square,
		Color(0.83, 0.80, 1.0, 0.30 + pulse * 0.08),
		false,
		2.5,
		true
	)

	if cast_elapsed < pre_sweep_delay:
		return

	var line_center := _get_sweep_front(cast_elapsed)
	var half_thickness := wave_thickness * 0.5
	var left := maxf(0.0, line_center - half_thickness)
	var right := minf(wave_size, line_center + half_thickness)

	if right <= left:
		return

	# A straight bar crosses the square. The node itself never travels.
	var wave_rect := Rect2(
		Vector2(left, -half_size),
		Vector2(right - left, wave_size)
	)
	draw_rect(
		wave_rect,
		Color(0.68, 0.76, 1.0, 0.34 + pulse * 0.10),
		true
	)

	var center_x := clampf(line_center, 0.0, wave_size)
	draw_line(
		Vector2(center_x, -half_size),
		Vector2(center_x, half_size),
		Color(1.0, 0.90, 1.0, 0.98),
		7.0,
		true
	)

	# Parallel highlights make the wave read as a moving sheet of light rather
	# than an expanding rectangular fill.
	for offset in [-18.0, 18.0]:
		var highlight_x = center_x + offset
		if highlight_x < 0.0 or highlight_x > wave_size:
			continue
		draw_line(
			Vector2(highlight_x, -half_size),
			Vector2(highlight_x, half_size),
			Color(0.80, 0.88, 1.0, 0.46),
			2.0,
			true
		)
