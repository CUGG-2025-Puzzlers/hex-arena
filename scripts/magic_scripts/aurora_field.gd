extends Node2D
class_name AuroraField

@export var duration: float = 8.0
@export var opening_pulse_duration: float = 0.8
@export var ally_opening_multiplier: float = 1.45
@export var ally_sustained_multiplier: float = 1.28
@export var enemy_opening_multiplier: float = 0.45
@export var enemy_sustained_multiplier: float = 0.62

var owner_player_id: int = -1
var field_id: int = -1
var boundary_global := PackedVector2Array()
var boundary_local := PackedVector2Array()
var elapsed: float = 0.0
var initialized: bool = false
var affected_players: Dictionary = {}
var entered_at_msec: Dictionary = {}
var effect_phase: Dictionary = {}
var source_id: String = ""


func initialize(
	new_owner_player_id: int,
	new_field_id: int,
	points_global: PackedVector2Array
) -> void:
	owner_player_id = new_owner_player_id
	field_id = new_field_id
	source_id = "aurora_field_%s_%s" % [owner_player_id, field_id]
	boundary_global = _sort_points(points_global)

	var centroid := Vector2.ZERO
	for point in boundary_global:
		centroid += point
	centroid /= float(maxi(boundary_global.size(), 1))
	global_position = centroid

	boundary_local.clear()
	for point in boundary_global:
		boundary_local.append(point - centroid)

	initialized = boundary_global.size() >= 3
	queue_redraw()


func _process(delta: float) -> void:
	if not initialized:
		return

	elapsed += delta
	queue_redraw()

	if multiplayer.is_server():
		_update_player_effects()

	if elapsed >= duration:
		queue_free()


func _update_player_effects() -> void:
	var players_node := get_tree().current_scene.find_child("Players")
	if players_node == null:
		return

	var currently_inside: Dictionary = {}

	for child in players_node.get_children():
		if not (child is Player):
			continue

		var target := child as Player
		var target_position := _get_player_hurtbox_position(target)
		var inside := Geometry2D.is_point_in_polygon(
			target_position,
			boundary_global
		)

		if not inside:
			continue

		currently_inside[target.player_id] = target

		if not affected_players.has(target.player_id):
			affected_players[target.player_id] = target
			entered_at_msec[target.player_id] = Time.get_ticks_msec()
			effect_phase[target.player_id] = 0
			_apply_multiplier(target, true)
		else:
			var entered_msec := int(entered_at_msec[target.player_id])
			var phase := int(effect_phase.get(target.player_id, 0))
			if (
				phase == 0
				and Time.get_ticks_msec() - entered_msec
				>= int(opening_pulse_duration * 1000.0)
			):
				_apply_multiplier(target, false)
				effect_phase[target.player_id] = 1

	for player_id in affected_players.keys():
		if currently_inside.has(player_id):
			continue

		var target := affected_players[player_id] as Player
		if is_instance_valid(target):
			target._remove_move_modifier.rpc(source_id)
		affected_players.erase(player_id)
		entered_at_msec.erase(player_id)
		effect_phase.erase(player_id)


func _get_player_hurtbox_position(target: Player) -> Vector2:
	var hurtbox_shape := target.get_node_or_null(
		"Area2D/CollisionShape2D"
	) as CollisionShape2D

	if hurtbox_shape != null:
		return hurtbox_shape.global_position

	return target.global_position


func _apply_multiplier(target: Player, opening: bool) -> void:
	var friendly := target.player_id == owner_player_id
	var multiplier: float

	if friendly:
		multiplier = ally_opening_multiplier if opening else ally_sustained_multiplier
	else:
		multiplier = enemy_opening_multiplier if opening else enemy_sustained_multiplier

	target._set_move_modifier.rpc(source_id, multiplier)


func _exit_tree() -> void:
	if not multiplayer.is_server():
		return

	for target in affected_players.values():
		if is_instance_valid(target):
			(target as Player)._remove_move_modifier.rpc(source_id)

	affected_players.clear()
	entered_at_msec.clear()
	effect_phase.clear()


func _sort_points(points: PackedVector2Array) -> PackedVector2Array:
	var result := points.duplicate()
	var centroid := Vector2.ZERO
	for point in result:
		centroid += point
	centroid /= float(maxi(result.size(), 1))

	var array: Array[Vector2] = []
	for point in result:
		array.append(point)

	array.sort_custom(
		func(a: Vector2, b: Vector2) -> bool:
			return (a - centroid).angle() < (b - centroid).angle()
	)

	result.clear()
	for point in array:
		result.append(point)
	return result


func _draw() -> void:
	if boundary_local.size() < 3:
		return

	var pulse := 0.5 + 0.5 * sin(elapsed * 4.5)
	var fade_out := clampf((duration - elapsed) / 0.65, 0.0, 1.0)
	var fill_alpha := (0.26 + pulse * 0.10) * fade_out

	draw_colored_polygon(
		boundary_local,
		Color(0.46, 0.70, 1.0, fill_alpha)
	)

	var closed := boundary_local.duplicate()
	closed.append(boundary_local[0])

	# Thick dark-underlined edge remains readable on both bright and dark maps.
	draw_polyline(
		closed,
		Color(0.20, 0.10, 0.34, 0.78 * fade_out),
		11.0,
		true
	)
	draw_polyline(
		closed,
		Color(1.0, 0.66 + pulse * 0.16, 0.96, 0.98 * fade_out),
		6.0,
		true
	)

	# A second inset polygon and bright vertices make the playable boundary clear.
	var inset := PackedVector2Array()
	for point in boundary_local:
		inset.append(point * (0.88 + pulse * 0.025))
	inset.append(inset[0])
	draw_polyline(
		inset,
		Color(0.78, 0.90, 1.0, 0.58 * fade_out),
		2.5,
		true
	)

	for point in boundary_local:
		draw_circle(point, 12.0 + pulse * 3.0, Color(0.70, 0.56, 1.0, 0.38 * fade_out))
		draw_circle(point, 6.0, Color(1.0, 0.88, 0.98, 0.96 * fade_out))
