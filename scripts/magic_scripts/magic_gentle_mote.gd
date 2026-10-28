extends Magic
class_name MagicGentleMote

@export var max_range: float = 650.0
@export var homing_radius: float = 280.0
@export var homing_strength: float = 2.4
@export var heal_amount: float = 7.0
@export var self_hit_grace: float = 0.22

var travelled: float = 0.0
var lifetime_elapsed: float = 0.0
var animation_time: float = 0.0
var hit_consumed: bool = false


func _process(delta: float) -> void:
	super._process(delta)
	animation_time += delta

	if rolling:
		_advance_mote(delta)

	queue_redraw()


func handles_player_contact() -> bool:
	return true


func can_be_cut_by_wire() -> bool:
	return rolling and not is_queued_for_deletion()


func start_rolling(path: PackedVector2Array) -> void:
	if rolling or path.size() < 2 or hit_consumed:
		return

	# A player can already be standing on the mote when it is fired. Resolve
	# that overlap before moving so the projectile cannot visually pass through.
	if _resolve_current_overlap():
		return

	var direction := path[path.size() - 1] - path[0]
	if direction.is_zero_approx():
		return

	rolling_dir = direction.normalized()
	rolling = true
	travelled = 0.0
	lifetime_elapsed = 0.0

	if HexCells.cell_dict.has(self_cell) and HexCells.cell_dict[self_cell] == self:
		HexCells.cell_dict[self_cell] = null

	started_rolling.emit()


func _advance_mote(delta: float) -> void:
	lifetime_elapsed += delta
	var target := _find_homing_target()

	if target != null:
		var target_position := _get_player_hurtbox_position(target)
		var desired := (target_position - global_position).normalized()
		rolling_dir = rolling_dir.lerp(
			desired,
			clampf(homing_strength * delta, 0.0, 1.0)
		).normalized()

	var step := maxf(roll_speed, 1.0) * delta
	global_position += rolling_dir * step
	travelled += step
	rotation = rolling_dir.angle()

	if travelled >= max_range:
		fizzle()


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("magic"):
		super._on_area_entered(area)
		return

	_try_consume_player_area(area)


func _resolve_current_overlap() -> bool:
	for area in get_overlapping_areas():
		if _try_consume_player_area(area):
			return true
	return false


func _try_consume_player_area(area: Area2D) -> bool:
	if hit_consumed:
		return false

	var target := area.get_parent() as Player
	if target == null:
		return false

	# The grace period only protects the caster from immediately catching a mote
	# they just fired. A stationary mote intentionally works on contact.
	if rolling and target.player_id == player_id and lifetime_elapsed < self_hit_grace:
		return false

	hit_consumed = true
	_resolve_hit(target)
	call_deferred("fizzle")
	return true


func _find_homing_target() -> Player:
	var players_node := get_tree().current_scene.find_child("Players")
	if players_node == null:
		return null

	var best: Player = null
	var best_score := INF

	for child in players_node.get_children():
		if not (child is Player):
			continue

		var candidate := child as Player
		if candidate.player_id == player_id and lifetime_elapsed < self_hit_grace:
			continue

		var target_position := _get_player_hurtbox_position(candidate)
		var offset := target_position - global_position
		var distance := offset.length()
		if distance > homing_radius or distance <= 0.001:
			continue

		var alignment := rolling_dir.dot(offset.normalized())
		if alignment < 0.35:
			continue

		var score := distance - alignment * 90.0
		if score < best_score:
			best_score = score
			best = candidate

	return best


func _get_player_hurtbox_position(target: Player) -> Vector2:
	var hurtbox_shape := target.get_node_or_null(
		"Area2D/CollisionShape2D"
	) as CollisionShape2D

	if hurtbox_shape != null:
		return hurtbox_shape.global_position

	return target.global_position


func _resolve_hit(target: Player) -> void:
	if not multiplayer.is_server() or player_owner == null:
		return

	if player_owner.is_friendly_to(target):
		target._apply_heal.rpc(heal_amount, player_id, get_telemetry_name())
	else:
		target._apply_damage.rpc(damage, player_id, get_telemetry_name())


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(animation_time * 9.0)
	draw_circle(Vector2.ZERO, 14.0 + pulse * 2.0, Color(1.0, 0.66, 0.84, 0.30))
	draw_circle(Vector2.ZERO, 9.0, Color(0.72, 0.86, 1.0, 0.86))
	draw_circle(Vector2(-2.0, -3.0), 4.0, Color(1.0, 0.96, 0.72, 1.0))
