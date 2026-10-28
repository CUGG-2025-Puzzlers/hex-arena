extends Magic
class_name MagicWaterOrb

var animation_time: float = 0.0


func _ready() -> void:
	setup()
	queue_redraw()


func _process(delta: float) -> void:
	super._process(delta)
	animation_time += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(animation_time * 2.4)
	var outer := Color(0.18, 0.72, 1.0, 0.50)
	var inner := Color(0.82, 0.96, 1.0, 0.96)
	var highlight := Color(1.0, 1.0, 1.0, 0.95)

	draw_circle(Vector2.ZERO, lerpf(17.0, 20.0, pulse), outer)
	draw_circle(Vector2.ZERO, lerpf(11.0, 13.0, pulse), inner)
	draw_circle(Vector2(-4.0, -5.0), 3.2, highlight)

	for i in range(3):
		var angle := animation_time * (0.9 + i * 0.12) + TAU * float(i) / 3.0
		var droplet_position := Vector2.RIGHT.rotated(angle) * (25.0 + 2.0 * pulse)
		draw_circle(droplet_position, 3.0, Color(0.55, 0.9, 1.0, 0.9))
