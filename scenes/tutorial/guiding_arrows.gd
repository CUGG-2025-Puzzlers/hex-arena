# res://scripts/guiding_arrows.gd
extends Node2D
class_name GuidingArrows

@export var arrow_count := 3
@export var arrow_scale := 0.75
@export var arrow_spacing := 64.0
@export var arrow_start_offset := Vector2(0, 105)

@export var arrow_color := Color(0.35, 0.85, 1.0, 1.0)
@export var arrow_glow_color := Color(0.1, 0.65, 1.0, 1.0)

@export var arrow_base_alpha := 0.22
@export var arrow_lit_alpha := 1.0

@export var arrow_pulse_interval := 0.16
@export var arrow_pulse_duration := 0.26
@export var arrow_cycle_pause := 2.8

var arrow_time := 0.0

var _arrow_fade_alpha := 1.0
var arrow_fade_alpha: float:
	get:
		return _arrow_fade_alpha
	set(value):
		_arrow_fade_alpha = value
		queue_redraw()


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return

	if arrow_fade_alpha <= 0.01:
		return

	arrow_time += delta
	queue_redraw()


func _draw() -> void:
	if not visible:
		return

	if arrow_fade_alpha <= 0.01:
		return

	_draw_guiding_arrows()


func reset() -> void:
	arrow_time = 0.0
	arrow_fade_alpha = 1.0
	visible = true
	queue_redraw()


func hide_immediately() -> void:
	visible = false
	arrow_fade_alpha = 0.0


func fade_out(duration := 0.35) -> Tween:
	var tween := create_tween()
	tween.tween_property(self, "arrow_fade_alpha", 0.0, duration)
	return tween


func _draw_guiding_arrows() -> void:
	var sequence_duration = arrow_pulse_interval * max(arrow_count - 1, 0) + arrow_pulse_duration
	var cycle_duration = sequence_duration + arrow_cycle_pause
	var cycle_pos := fposmod(arrow_time, cycle_duration)

	for i in range(arrow_count):
		var order_index := arrow_count - 1 - i
		var start_time := float(order_index) * arrow_pulse_interval

		var lit_strength := _get_pulse_strength(cycle_pos, start_time, arrow_pulse_duration)
		var alpha := lerpf(arrow_base_alpha, arrow_lit_alpha, lit_strength) * arrow_fade_alpha

		var offset := arrow_start_offset + Vector2(0, i * arrow_spacing)
		_draw_single_arrow(offset, arrow_scale, alpha, lit_strength)


func _get_pulse_strength(time_pos: float, start_time: float, duration: float) -> float:
	var local_time := time_pos - start_time

	if local_time < 0.0 or local_time > duration:
		return 0.0

	var t := local_time / duration
	return sin(t * PI)


func _draw_single_arrow(offset: Vector2, scale_value: float, alpha: float, lit_strength: float) -> void:
	var points := PackedVector2Array([
		Vector2(-44, 26),
		Vector2(-44, -2),
		Vector2(0, -34),
		Vector2(44, -2),
		Vector2(44, 26),
		Vector2(0, 10),
		Vector2(-44, 26),
	])

	for i in range(points.size()):
		points[i] = points[i] * scale_value + offset

	var glow_strength := lerpf(0.8, 1.35, lit_strength)

	draw_polyline(
		points,
		Color(arrow_glow_color.r, arrow_glow_color.g, arrow_glow_color.b, alpha * 0.18),
		20.0 * scale_value * glow_strength,
		true
	)

	draw_polyline(
		points,
		Color(arrow_glow_color.r, arrow_glow_color.g, arrow_glow_color.b, alpha * 0.35),
		10.0 * scale_value * glow_strength,
		true
	)

	draw_polyline(
		points,
		Color(arrow_color.r, arrow_color.g, arrow_color.b, alpha),
		4.0 * scale_value,
		true
	)

	if lit_strength > 0.2:
		draw_polyline(
			points,
			Color(1.0, 1.0, 1.0, alpha * 0.45 * lit_strength),
			1.5 * scale_value,
			true
		)
