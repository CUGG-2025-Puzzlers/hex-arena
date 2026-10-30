extends ProgressBar

var _trail_value: float = -1.0
var _last_value: float = -1.0
var _trail_hold: float = 0.0

var critical: bool = false:
	set(next):
		critical = next
		queue_redraw()

func _ready() -> void:
	reset_trail()
	value_changed.connect(_value_changed)
	resized.connect(queue_redraw)

func reset_trail() -> void:
	_trail_value = value
	_last_value = value
	_trail_hold = 0.0
	queue_redraw()

func _value_changed(next: float) -> void:
	if next < _last_value:
		_trail_value = maxf(_trail_value, _last_value)
		_trail_hold = 0.16
	else:
		_trail_value = maxf(_trail_value, next)
	_last_value = next
	queue_redraw()

func _process(delta: float) -> void:
	_trail_hold = maxf(0.0, _trail_hold - delta)
	if _trail_hold <= 0.0 and _trail_value > value:
		_trail_value = move_toward(_trail_value, value, max_value * delta * 2.3)
		queue_redraw()

func _draw() -> void:
	var count := clampi(ceili(max_value / 25.0), 4, 20)
	var unit := size.x / float(count)
	var fraction := clampf(value / maxf(max_value, 0.001), 0.0, 1.0)
	var fill := Color("ff616b") if critical else Color("f2f6ff")
	for i in range(count):
		var x := float(i) * unit
		var width := unit - 3.0
		var points := PackedVector2Array([Vector2(x + 4, 0), Vector2(x + width + 4, 0), Vector2(x + width, size.y), Vector2(x, size.y)])
		draw_colored_polygon(points, Color(0.08, 0.11, 0.16, 0.85))
		var trail := clampf(_trail_value / maxf(max_value, 0.001) * count - i, 0.0, 1.0)
		if trail > 0.0 and Juice.intensity > 0.0:
			var trail_width := width * trail
			draw_colored_polygon(PackedVector2Array([Vector2(x + 4, 0), Vector2(x + trail_width + 4, 0), Vector2(x + trail_width, size.y), Vector2(x, size.y)]), Color(1.0, 0.66, 0.4, 0.7 * Juice.intensity))
		var amount := clampf(fraction * count - i, 0.0, 1.0)
		if amount > 0.0:
			var filled_width := width * amount
			draw_colored_polygon(PackedVector2Array([Vector2(x + 4, 0), Vector2(x + filled_width + 4, 0), Vector2(x + filled_width, size.y), Vector2(x, size.y)]), fill)
