
extends Magic
class_name MagicAuroraBasic

var animation_time: float = 0.0


func _process(delta: float) -> void:
	super._process(delta)
	animation_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(animation_time * 2.8)
	var outer := Color(0.72, 0.62, 1.0, 0.30)
	var middle := Color(0.62, 0.84, 1.0, 0.68)
	var core := Color(1.0, 0.86, 0.94, 0.96)

	draw_circle(Vector2.ZERO, 24.0 + pulse * 2.0, outer)
	draw_circle(Vector2(3.0, -2.0), 17.0 + pulse, middle)
	draw_circle(Vector2(-3.0, -4.0), 9.0, core)
