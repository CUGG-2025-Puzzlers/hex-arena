extends Magic
class_name MagicRootHand

@export var travel_time: float = 0.8
@export var linger_time: float = 0.5
@export var root_duration: float = 1.6

var is_active: bool = false
var _hit_consumed: bool = false
var _cast_origin_global: Vector2
var _movement_tween: Tween

func _ready() -> void:
	# The placed hand can still detect incoming magic through its own monitoring,
	# but players cannot collide with it until it is fired.
	monitorable = false
	queue_redraw()

func start_rolling(wiggly_path: PackedVector2Array) -> void:
	if rolling or wiggly_path.size() < 2:
		return

	var direction := wiggly_path[wiggly_path.size() - 1] - wiggly_path[0]
	if direction.is_zero_approx():
		return

	rolling_dir = direction.normalized()
	_cast_origin_global = global_position

	if HexCells.cell_dict.has(self_cell) and HexCells.cell_dict[self_cell] == self:
		HexCells.cell_dict[self_cell] = null

	rolling = true
	is_active = true
	monitorable = true
	rotation = rolling_dir.angle()
	started_rolling.emit()

	if _update_hand_visual not in process_callables:
		process_callables.append(_update_hand_visual)

	var target_position := _cast_origin_global + rolling_dir * (HexCells.hex_width * 1.5)
	_movement_tween = create_tween()
	_movement_tween.set_trans(Tween.TRANS_LINEAR)
	_movement_tween.set_ease(Tween.EASE_IN_OUT)
	_movement_tween.tween_property(self, "global_position", target_position, travel_time)
	_movement_tween.tween_interval(linger_time)
	_movement_tween.tween_callback(fizzle)

func try_consume_hit() -> bool:
	if not is_active or _hit_consumed:
		return false

	_hit_consumed = true
	return true

func _update_hand_visual(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var red := Color(0.92, 0.874, 0.876, 1.0)
	var dark_red := Color(0.77, 0.0, 0.077, 1.0)

	if is_active:
		var origin_local := to_local(_cast_origin_global)
		draw_line(origin_local, Vector2(-8.0, 0.0), dark_red, 11.0, true)
		draw_line(origin_local, Vector2(-8.0, 0.0), red, 6.0, true)

	# Palm.
	draw_circle(Vector2(0.0, 0.0), 13.0, dark_red)
	draw_circle(Vector2(2.0, 0.0), 10.5, red)

	# Four fingers reaching forward.
	for y in [-9.0, -3.0, 3.0, 9.0]:
		draw_line(Vector2(7.0, y * 0.72), Vector2(27.0, y), dark_red, 7.0, true)
		draw_line(Vector2(7.0, y * 0.72), Vector2(27.0, y), red, 4.0, true)
		draw_circle(Vector2(27.0, y), 2.0, red)

	# Thumb.
	draw_line(Vector2(5.0, 8.0), Vector2(18.0, 17.0), dark_red, 8.0, true)
	draw_line(Vector2(5.0, 8.0), Vector2(18.0, 17.0), red, 4.5, true)
