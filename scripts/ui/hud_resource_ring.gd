extends Control

var fraction: float = 0.0:
	set(next):
		fraction = clampf(next, 0.0, 1.0)
		queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 7.0
	draw_circle(center, radius - 5.0, Color(0.04, 0.07, 0.11, 0.6))
	draw_arc(center, radius, 0, TAU, 96, Color(0.85, 0.9, 1, 0.25), 5.0, true)
	if fraction > 0.0:
		draw_arc(center, radius, -PI * 0.5, -PI * 0.5 + TAU * fraction, 96, Color("82e7ff"), 5.0, true)
	draw_arc(center, radius - 8.0, 0, TAU, 96, Color(1, 1, 1, 0.7), 1.0, true)
