extends Magic
class_name MagicLightArrow

@onready var arrow_particles: Node2D = $ArrowParticles

var rot_tween : Tween
var final_angle : float


# Rotate around randomly when spawned
func _ready() -> void:
	final_angle = randf_range(-1,1)*PI
	
	arrow_particles.rotate(final_angle)
	create_tween_rotate_to_selected(HexCells.curr_cell)
	
	Events.select_new_cell.connect(create_tween_rotate_to_selected)
	
	started_rolling.connect(turn_to_roll)

func turn_to_roll():
	if rot_tween:
		rot_tween.kill()
		
	var duration : float = 0.15
	rot_tween = create_tween()
		
	rot_tween.set_trans(Tween.TRANS_BACK)
	rot_tween.set_ease(Tween.EASE_OUT)
		
	arrow_particles.rotation = fposmod(arrow_particles.rotation, 2*PI)
	if arrow_particles.rotation>PI:
		arrow_particles.rotation-=2*PI
		
	final_angle = arrow_particles.rotation
	final_angle += Vector2.RIGHT.rotated(arrow_particles.rotation).angle_to(rolling_dir)
	
	rot_tween.tween_property(arrow_particles, "rotation", final_angle, duration)

# Rotate around if hovering over last placed
# Or rotate smoothly towards the target
func create_tween_rotate_to_selected(target_cell: Vector2i = self_cell):
	if rolling:
		return
	
	if rot_tween:
		rot_tween.kill()
	
	var duration : float = 0.5
	rot_tween = create_tween()
	
	rot_tween.set_trans(Tween.TRANS_SINE)
	rot_tween.set_ease(Tween.EASE_OUT)
	
	
	if target_cell != last_placed_cell:
		
		var target_dir : Vector2 = HexCells.map_to_local(target_cell)-HexCells.map_to_local(last_placed_cell)
		target_dir = target_dir.normalized()
		
		arrow_particles.rotation = fposmod(arrow_particles.rotation, 2*PI)
		if arrow_particles.rotation>PI:
			arrow_particles.rotation-=2*PI
		
		final_angle = arrow_particles.rotation
		final_angle += Vector2.RIGHT.rotated(final_angle).angle_to(target_dir)
	else:
		if Vector2.RIGHT.rotated(final_angle) == Vector2.RIGHT.rotated(arrow_particles.rotation):
			final_angle = arrow_particles.rotation + PI*[-2.,2.].pick_random()
	
	rot_tween.tween_property(arrow_particles, "rotation", final_angle, duration)
