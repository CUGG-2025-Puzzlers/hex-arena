extends Magic
class_name MagicBurst

@export var expansion_time: float = 0.12
@export var visible_after_hit_time: float = 0.08

var detonating: bool = false
var _blast_progress: float = 0.0
var _blast_tween: Tween

func _ready() -> void:
	# Player hits are resolved explicitly by this script so one burst can hit
	# every enemy in the radius instead of disappearing on the first target.
	monitorable = false
	queue_redraw()

func start_rolling(_wiggly_path: PackedVector2Array) -> void:
	if rolling:
		return

	if HexCells.cell_dict.has(self_cell) and HexCells.cell_dict[self_cell] == self:
		HexCells.cell_dict[self_cell] = null

	rolling = true
	detonating = true
	started_rolling.emit()

	_blast_tween = create_tween()
	_blast_tween.tween_method(_set_blast_progress, 0.0, 1.0, expansion_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_blast_tween.tween_callback(_resolve_hits)
	_blast_tween.tween_interval(visible_after_hit_time)
	_blast_tween.tween_callback(fizzle)

func _set_blast_progress(value: float) -> void:
	_blast_progress = value
	queue_redraw()

func _resolve_hits() -> void:
	var blast_radius := (HexCells.hex_width * 1.5)
	_resolve_magic_breaks(blast_radius)

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

		if global_position.distance_to(target_position) > blast_radius:
			continue

		# Visual feedback runs on every peer. Damage remains server-authoritative,
		# matching the existing projectile damage flow in Player.gd.
		var blood := target.get_node_or_null("Area2D/CPUParticles2D") as CPUParticles2D
		if blood != null:
			blood.restart()

		if multiplayer.is_server():
			var damage_amount := damage / randf_range(3.3, 3.5)
			target._apply_damage.rpc(damage_amount, player_id, get_telemetry_name())


func _resolve_magic_breaks(blast_radius: float) -> void:
	var destroyed := 0

	for node in get_tree().get_nodes_in_group("magic"):
		if not (node is Magic):
			continue

		var target := node as Magic
		if (
			target == self
			or target.player_id == player_id
			or target.is_queued_for_deletion()
			or global_position.distance_to(target.global_position) > blast_radius
		):
			continue

		# Zilo's E is explicit counter-magic: anything hostile caught in the
		# blast is removed regardless of its remaining magic health.
		target.fizzle()
		destroyed += 1

	if destroyed > 0:
		Telemetry.record_enemy_magic_destroyed(
			player_id, destroyed, get_telemetry_name()
		)

func _draw() -> void:
	var core_red := Color(0.93, 0.828, 0.829, 1.0)
	var edge_red := Color(0.45, 0.0, 0.02, 1.0)

	# Placed-magic core.
	draw_circle(Vector2.ZERO, 15.0, edge_red)
	draw_circle(Vector2.ZERO, 11.0, core_red)

	if not detonating:
		return

	var radius := (HexCells.hex_width * 1.5) * _blast_progress
	var fill := Color(1.0, 0.03, 0.05, 0.24 * (1.0 - 0.35 * _blast_progress))
	var outline := Color(1.0, 0.12, 0.12, 0.95)
	draw_circle(Vector2.ZERO, radius, fill)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, outline, 5.0, true)


func can_be_cut_by_wire() -> bool:
	return false
