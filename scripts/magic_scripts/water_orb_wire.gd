extends Area2D
class_name WaterOrbWire

# Both playtest characters share this wire implementation. The variant changes
# only what happens when a player crosses the line and when a Tideblade attacks.
enum WireVariant {
	RAZOR_CURRENT = 1,
	FLOW_CIRCUIT = 2,
}

@export var wire_thickness: float = 18.0
@export var crossing_damage: float = 12.0
@export var conduit_travel_time: float = 0.24

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var endpoint_a: Magic = null
var endpoint_b: Magic = null
var endpoint_a_cell: Vector2i
var endpoint_b_cell: Vector2i
var player_id: int = -1
var wire_id: int = -1
var variant: WireVariant = WireVariant.RAZOR_CURRENT

var wire_length: float = 0.0
var animation_time: float = 0.0
var players_inside: Dictionary = {}

var conduit_pulses: Dictionary = {}
var next_conduit_pulse_id: int = 0


func configure(
	new_endpoint_a: Magic,
	new_endpoint_b: Magic,
	new_player_id: int,
	new_variant: int,
	new_wire_id: int
) -> void:
	endpoint_a = new_endpoint_a
	endpoint_b = new_endpoint_b
	endpoint_a_cell = endpoint_a.self_cell
	endpoint_b_cell = endpoint_b.self_cell
	player_id = new_player_id
	variant = new_variant
	wire_id = new_wire_id

	add_to_group("water_orb_wire")
	_update_geometry()
	queue_redraw()


func _process(delta: float) -> void:
	animation_time += delta

	if not _endpoints_are_valid():
		# A Flow pulse that has already left an endpoint is allowed to finish.
		# The wire removes itself as soon as no active pulse remains.
		if conduit_pulses.is_empty():
			queue_free()
		return

	_update_geometry()
	queue_redraw()


func _endpoints_are_valid() -> bool:
	return (
		is_instance_valid(endpoint_a)
		and is_instance_valid(endpoint_b)
		and not endpoint_a.is_queued_for_deletion()
		and not endpoint_b.is_queued_for_deletion()
	)


func _update_geometry() -> void:
	if not _endpoints_are_valid():
		return

	var start := endpoint_a.global_position
	var finish := endpoint_b.global_position
	var direction := finish - start

	wire_length = direction.length()
	global_position = (start + finish) * 0.5
	rotation = direction.angle()

	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		rectangle = RectangleShape2D.new()
		collision_shape.shape = rectangle

	rectangle.size = Vector2(maxf(wire_length, 1.0), wire_thickness)


func connects_cell(cell: Vector2i) -> bool:
	return cell == endpoint_a_cell or cell == endpoint_b_cell


func conduct_attack_from(
	source_cell: Vector2i,
	direction: Vector2
) -> void:
	if variant != WireVariant.FLOW_CIRCUIT:
		return

	if not _endpoints_are_valid():
		return

	if not connects_cell(source_cell):
		return

	var other_endpoint: Magic = (
		endpoint_b
		if source_cell == endpoint_a_cell
		else endpoint_a
	)

	if not is_instance_valid(other_endpoint):
		return

	if not other_endpoint.has_method("perform_remote_swing"):
		return

	next_conduit_pulse_id += 1
	var pulse_id: int = next_conduit_pulse_id

	conduit_pulses[pulse_id] = {
		"from_a": source_cell == endpoint_a_cell,
		"progress": 0.0,
	}

	var conduit_tween: Tween = create_tween()

	(
		conduit_tween
		.tween_method(
			func(value: float) -> void:
				_set_conduit_progress(pulse_id, value),
			0.0,
			1.0,
			conduit_travel_time
		)
		.set_trans(Tween.TRANS_SINE)
		.set_ease(Tween.EASE_IN_OUT)
	)

	conduit_tween.tween_callback(
		func() -> void:
			if is_instance_valid(other_endpoint):
				other_endpoint.call(
					"perform_remote_swing",
					direction
				)
	)

	conduit_tween.tween_callback(
		func() -> void:
			conduit_pulses.erase(pulse_id)
			queue_redraw()
	)


func _set_conduit_progress(
	pulse_id: int,
	value: float
) -> void:
	if not conduit_pulses.has(pulse_id):
		return

	var pulse: Dictionary = conduit_pulses[pulse_id]
	pulse["progress"] = value
	conduit_pulses[pulse_id] = pulse
	queue_redraw()


func _on_area_entered(area: Area2D) -> void:
	var parent := area.get_parent()
	if parent is Player:
		_handle_player_entered(parent as Player)
		return

	if area is Magic:
		_handle_magic_entered(area as Magic)


func _on_area_exited(area: Area2D) -> void:
	var parent := area.get_parent()
	if parent is Player:
		players_inside.erase((parent as Player).get_instance_id())


func _handle_player_entered(target: Player) -> void:
	if variant != WireVariant.RAZOR_CURRENT:
		return
	if target.player_id == player_id:
		return

	var target_id := target.get_instance_id()
	if players_inside.has(target_id):
		return

	# The target is removed from this dictionary only after leaving the wire,
	# so one continuous overlap can deal damage only once.
	players_inside[target_id] = true

	if multiplayer.is_server():
		target._apply_damage.rpc(crossing_damage, player_id, "Razor Current")


func _handle_magic_entered(projectile: Magic) -> void:
	if projectile.player_id == player_id:
		return
	if not projectile.can_be_cut_by_wire():
		return

	projectile.call_deferred("fizzle")


func _draw() -> void:
	var half_length := wire_length * 0.5
	var start := Vector2(-half_length, 0.0)
	var finish := Vector2(half_length, 0.0)

	if variant == WireVariant.RAZOR_CURRENT:
		var turbulence := sin(animation_time * 10.0) * 2.5
		draw_line(
			start + Vector2(0.0, turbulence),
			finish + Vector2(0.0, -turbulence),
			Color(1.0, 0.13, 0.16, 0.92),
			7.0,
			true
		)
		draw_line(
			start + Vector2(0.0, -4.0 - turbulence),
			finish + Vector2(0.0, 4.0 + turbulence),
			Color(0.55, 0.0, 0.05, 0.78),
			2.5,
			true
		)

		for i in range(8):
			var progress := fposmod(animation_time * 0.65 + float(i) / 8.0, 1.0)
			var point := start.lerp(finish, progress)
			var spike_height := 5.0 + 3.0 * sin(animation_time * 8.0 + i)
			draw_line(
				point + Vector2(0.0, -spike_height),
				point + Vector2(0.0, spike_height),
				Color(1.0, 0.42, 0.45, 0.82),
				2.0,
				true
			)
	else:
		draw_line(start, finish, Color(0.58, 0.92, 1.0, 0.58), 5.0, true)
		draw_line(start, finish, Color(0.92, 0.99, 1.0, 0.82), 1.5, true)

		for pulse_value: Variant in conduit_pulses.values():
			var pulse: Dictionary = pulse_value
			var progress: float = float(pulse["progress"])

			if not bool(pulse["from_a"]):
				progress = 1.0 - progress

			var pulse_position: Vector2 = start.lerp(
				finish,
				progress
			)

			draw_circle(
				pulse_position,
				12.0,
				Color(0.72, 0.96, 1.0, 0.24)
			)
			draw_circle(
				pulse_position,
				5.0,
				Color(0.95, 1.0, 1.0, 0.98)
			)
