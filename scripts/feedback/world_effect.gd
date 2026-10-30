extends Node2D

var kind: String = "hit"
var owner_id: int = -1
var tint: Color = Color.WHITE
var direction: Vector2 = Vector2.ZERO
var strength: float = 1.0
var intensity: float = 1.0
var reduced_flashes: bool = false
var follow: WeakRef
var _age: float = 0.0
var _points: Array[Vector2] = []
var _sample: float = 0.0

func _ready() -> void:
	z_index = 24
	add_to_group("juice_effect")

func _process(delta: float) -> void:
	_age += delta
	var point := global_position
	if kind == "trail":
		var target = follow.get_ref() if follow != null else null
		if not is_instance_valid(target) or target.is_queued_for_deletion() or not target.rolling or _age > 2.5:
			queue_free()
			return
		point = target.global_position
		_sample -= delta
		if _sample <= 0.0:
			_sample = 0.025
			_points.push_front(point)
			if _points.size() > 6:
				_points.pop_back()
	elif _age > 0.28:
		queue_free()
		return
	# Re-evaluate visibility every frame, including effects left behind projectiles.
	if not Juice.visible_at(point, owner_id):
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var p := clampf(_age / 0.28, 0.0, 1.0)
	var alpha := (1.0 - p) * intensity * (0.55 if reduced_flashes else 0.85)
	var color := Color(tint, alpha)
	if kind == "trail":
		for i in range(1, _points.size()):
			var midpoint := (_points[i - 1] + _points[i]) * 0.5
			if Juice.visible_at(midpoint, owner_id):
				draw_line(to_local(_points[i - 1]), to_local(_points[i]), Color(tint, intensity * (1.0 - float(i) / 6.0) * 0.35), 1.5, true)
		return
	if kind in ["place", "transform"]:
		var scale_factor := 0.62 + 0.25 * (1.0 - pow(1.0 - p, 3.0))
		var polygon := PackedVector2Array()
		for vertex in HexCells.hex_shape:
			polygon.append(vertex * scale_factor)
		polygon.append(polygon[0])
		draw_polyline(polygon, color, 2.0, true)
		if kind == "transform":
			draw_arc(Vector2.ZERO, 13.0 + 10.0 * p, 0, TAU, 20, color, 1.5, true)
	elif kind == "block":
		var angle := direction.angle() if not direction.is_zero_approx() else 0.0
		draw_arc(Vector2.ZERO, 20.0 + p * 13.0, angle - 1.1, angle + 1.1, 18, color, 2.5, true)
	elif kind == "launch":
		var axis := direction if not direction.is_zero_approx() else Vector2.RIGHT
		draw_line(-axis * (8.0 + p * 15.0), axis * 7.0, color, 2.0, true)
	elif kind in ["depart", "arrive", "stride", "stop"]:
		var axis := direction if not direction.is_zero_approx() else Vector2.RIGHT
		var radius := lerpf(22.0, 6.0, p) if kind in ["arrive", "stop"] else lerpf(6.0, 25.0, p)
		for side in [-1, 1]:
			var origin: Vector2 = axis.orthogonal() * side * 7.0
			draw_line(origin - axis * radius, origin - axis * (radius + 10.0), color, 1.5, true)
		if kind in ["depart", "arrive"]:
			draw_arc(Vector2.ZERO, radius, axis.angle() - 1.0, axis.angle() + 1.0, 14, color, 2.0, true)
	elif kind in ["expired", "completed", "interrupted", "lost_target"]:
		var radius := lerpf(17.0, 3.0, p)
		if kind == "completed":
			draw_polyline(PackedVector2Array([Vector2(-6,0), Vector2(-1,5), Vector2(8,-5)]), color, 1.5, true)
		elif kind == "interrupted":
			draw_line(Vector2(-radius,-radius), Vector2(radius,radius), color, 1.5)
			draw_line(Vector2(-radius,radius), Vector2(radius,-radius), color, 1.5)
		elif kind == "lost_target":
			draw_arc(Vector2.ZERO, radius, 0.4, PI - 0.4, 12, color, 1.5, true)
			draw_arc(Vector2.ZERO, radius, PI + 0.4, TAU - 0.4, 12, color, 1.5, true)
		else:
			draw_arc(Vector2.ZERO, radius, 0, TAU, 20, color, 1.2, true)
	elif kind in ["wall", "spell"]:
		var axis := direction if not direction.is_zero_approx() else Vector2.UP
		for i in range(-1, 2):
			var ray := axis.rotated(i * 0.65)
			draw_line(ray * (5 + p * 8), ray * (10 + p * 13), color, 1.5, true)
		if kind == "spell":
			draw_arc(Vector2.ZERO, 6 + p * 12, 0, TAU, 16, color, 1.2, true)
	elif kind == "silence":
		var center := Vector2(0, -32)
		draw_arc(center, 7, 0, TAU, 18, color, 1.5, true)
		draw_line(center - Vector2(5,5), center + Vector2(5,5), color, 2, true)
	elif kind in ["control", "root"]:
		draw_arc(Vector2(-6, -32), 7.0 + p * 3.0, -PI * 0.3, PI * 1.3, 14, color, 2.0, true)
		draw_arc(Vector2(6, -32), 7.0 + p * 3.0, PI * 0.7, PI * 2.3, 14, color, 2.0, true)
	elif kind == "heal":
		draw_arc(Vector2.ZERO, 18.0 + p * 12.0, PI * 0.15, PI * 0.85, 16, color, 2.0, true)
		var center := Vector2(0, -28.0 - p * 10.0)
		draw_line(center - Vector2(4, 0), center + Vector2(4, 0), color, 2.0)
		draw_line(center - Vector2(0, 4), center + Vector2(0, 4), color, 2.0)
	else:
		var spokes := 8 if kind == "break" else 5
		for i in range(spokes):
			var axis := Vector2.from_angle(TAU * float(i) / spokes + 0.25)
			var radius := (7.0 + p * 13.0) * strength
			draw_line(axis * radius, axis * (radius + 5.0 * (1.0 - p)), color, 2.0, true)
