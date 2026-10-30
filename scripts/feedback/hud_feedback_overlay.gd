extends Control

var _hits: Array[Dictionary] = []
var _toast: String = ""
var _toast_time: float = 0.0
var _toast_kind: String = ""
var ready_rect: Rect2
var _ready_time: float = 0.0
var _denied_time: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Juice.presented.connect(_on_feedback)

func _on_feedback(event: Dictionary) -> void:
	var kind: String = event.kind
	if kind == "hurt":
		if _hits.size() >= 4:
			_hits.pop_front()
		_hits.append({"point": event.position, "bearing": event.bearing, "time": 0.42})
	elif kind in ["objective", "elimination", "success"]:
		# Objective state takes priority over a stream of elimination notices.
		if _toast_time <= 0.0 or kind == "objective" or (_toast_kind != "objective" and (kind != "success" or _toast_kind == "success")):
			_toast = event.text
			_toast_time = 1.35
			_toast_kind = kind
	elif kind == "ready":
		_ready_time = 0.45
	elif kind == "denied":
		_denied_time = 0.22

func _process(delta: float) -> void:
	for hit in _hits:
		hit.time -= delta
	_hits = _hits.filter(func(hit: Dictionary): return hit.time > 0.0)
	_toast_time = maxf(0.0, _toast_time - delta)
	_ready_time = maxf(0.0, _ready_time - delta)
	_denied_time = maxf(0.0, _denied_time - delta)
	queue_redraw()

func _draw() -> void:
	var amount := Juice.intensity
	var transform := get_viewport().get_canvas_transform()
	for hit in _hits:
		var center: Vector2 = transform * hit.point
		var bearing: Vector2 = hit.bearing
		var alpha: float = hit.time / 0.42 * amount * (0.45 if Juice.reduced_flashes else 0.7)
		if bearing.is_zero_approx():
			draw_arc(center, 36.0, 0, TAU, 24, Color(1.0, 0.35, 0.4, alpha), 2.0, true)
		else:
			var axis := transform.basis_xform(bearing).normalized()
			draw_arc(center, 38.0, axis.angle() - 0.4, axis.angle() + 0.4, 12, Color(1.0, 0.35, 0.4, alpha), 3.0, true)
	if _ready_time > 0.0 and amount > 0.0:
		draw_rect(ready_rect.grow(3.0 * (1.0 - _ready_time / 0.45)), Color(0.55, 0.9, 1.0, _ready_time / 0.45 * amount), false, 2.0)
	if _denied_time > 0.0 and amount > 0.0:
		draw_rect(ready_rect, Color(1.0, 0.4, 0.4, _denied_time / 0.22 * amount), false, 2.0)
	if _toast_time > 0.0:
		var font := ThemeDB.fallback_font
		var font_size := 24
		var width := font.get_string_size(_toast, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var y := size.y * (0.17 if _toast_kind == "objective" else 0.70)
		var color := Color("a5e9ff") if _toast_kind == "objective" else Color("ffe0a7")
		color.a = minf(1.0, _toast_time / 0.2)
		draw_string_outline(font, Vector2((size.x - width) * 0.5, y), _toast, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color(0.02, 0.03, 0.06, color.a))
		draw_string(font, Vector2((size.x - width) * 0.5, y), _toast, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
