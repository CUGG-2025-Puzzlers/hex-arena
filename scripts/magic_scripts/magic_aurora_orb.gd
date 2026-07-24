
extends Magic
class_name MagicAuroraOrb

var animation_time: float = 0.0


func _ready() -> void:
	add_to_group("aurora_orb")
	queue_redraw()


func _process(delta: float) -> void:
	super._process(delta)
	animation_time += delta
	queue_redraw()


func handles_player_contact() -> bool:
	return true


func can_be_cut_by_wire() -> bool:
	return false


func start_rolling(_path: PackedVector2Array) -> void:
	if player_owner == null or is_queued_for_deletion():
		return

	var controller := player_owner.get_node_or_null("AuroraFieldController")
	if controller != null:
		controller.call("request_activate_field")


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(animation_time * 3.6)
	draw_circle(Vector2.ZERO, 24.0 + pulse * 2.5, Color(0.64, 0.52, 1.0, 0.28))
	draw_circle(Vector2.ZERO, 17.0, Color(0.62, 0.87, 1.0, 0.78))
	draw_circle(Vector2(-4.0, -5.0), 7.0, Color(1.0, 0.84, 0.66, 0.98))
	draw_arc(Vector2.ZERO, 29.0, 0.0, TAU, 36, Color(1.0, 0.76, 0.94, 0.85), 3.0, true)
