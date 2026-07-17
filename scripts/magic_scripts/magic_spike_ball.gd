extends Magic
class_name MagicSpikeBall

@onready var eye_sprite: Sprite2D = $EyeSprite

var points: Array[Vector2] = []
var center_fill_prog: float = 0.0
var point_prog_array: Array[float] = []

var squish_and_bob_tween : Tween
var spike_tweens: Array[Tween] = []


func _ready() -> void:
	
	configure_eye_sprite()
	create_spikes()
	started_rolling.connect(initialize_rotation)

func initialize_rotation():
	process_callables.append(_rotating)

func _rotating(_delta: float):
	if rolling_pathfollow:
		rotation = 2*PI*rolling_pathfollow.progress_ratio

func configure_eye_sprite():
	eye_sprite.scale = Vector2.ONE*randf_range(0.2,0.3)
	eye_sprite.rotation=randf()*2*PI
	eye_sprite.flip_h = randf()<0.5
	eye_sprite.flip_v = randf()<0.5
	
	squish_and_bob_tween = create_tween().set_loops()
	squish_and_bob_tween.tween_method(
		func(prog: float):
			eye_sprite.scale.y = clampf(0.5 * (cos(2*PI*prog) + 1.0) * eye_sprite.scale.x,
			0.07, eye_sprite.scale.x)
			eye_sprite.position = Vector2.UP.rotated(eye_sprite.rotation) *  cos(2*PI*(prog + 0.2)) * 4.0,
		0., 1., 3.)

func create_spikes() -> void:
	points = []
	center_fill_prog = 0.
	point_prog_array = []
	
	for tw in spike_tweens:
		if tw:
			tw.kill()
	spike_tweens = []
	
	var num_points = randi_range(5, 23)
	for i in range(num_points):
		points.append(Vector2.ONE.rotated(randf() * 2 * PI) * randf_range(5, 15))
		point_prog_array.append(0.)
	
	var spike_speed_multiplyer: float = randf_range(0.7, 1.)
	
	for i in range(num_points):
		var point_tween = create_tween().set_loops()
		var rand_cycle = randf_range(2., 8.)*spike_speed_multiplyer
		point_tween.tween_method(
			func(prog: float):
				point_prog_array[i] = prog,
			0., 1., rand_cycle)
		spike_tweens.append(point_tween)
	
	queue_redraw()
	
	if _update_fill_prog not in process_callables:
		process_callables.append(_update_fill_prog)

func _update_fill_prog(delta):
	center_fill_prog = fmod(center_fill_prog+delta, 3.)/3.
	queue_redraw()

# Draws the heavy magic red and white texture
func _draw():
	var fill_prog: float  = 0.5 * (cos(2 * PI * center_fill_prog) + 1)
	
	draw_circle(Vector2.ZERO, lerpf(15.5, 17, fill_prog), Color.RED)
	draw_circle(Vector2.ZERO, lerpf(12, 15, fill_prog), Color.WHITE)
	
	var scaled_points = points.duplicate()
	for i in range(len(points)):
		scaled_points[i] *= 0.5 * (cos(2 * PI * point_prog_array[i]) + 1)
		var point: Vector2 = scaled_points[i]
		var start: Vector2 = point * 2.5
		var angle: float = PI / 12
		_draw_tri(point, start, angle, Color.RED)
	
	for i in range(len(points)):
		var point: Vector2 = scaled_points[i]
		var start: Vector2 = point * lerpf(1.5, 2, fill_prog)
		var angle: float = PI / lerpf(12, 20, fill_prog)
		
		_draw_tri(point, start, angle, Color.WHITE)

# Draws a triangle based on a point, a scaled version of that point, and an angle
# Fills the triangle with the given color
func _draw_tri(point: Vector2, scaled_point: Vector2, angle: float, color: Color):
	var tri = [scaled_point]
	tri.append(point - point.rotated(angle))
	tri.append(point - point.rotated(-angle))
	tri.append(scaled_point)
	draw_polygon(tri, [color])
