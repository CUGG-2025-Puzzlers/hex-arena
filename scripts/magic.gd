extends Node2D
class_name Magic

enum MagicType {NEUTRAL, LIGHT, HEAVY}
var state = MagicType.NEUTRAL

static var last_placed_cell : Vector2i

const BULLET_SPEED : float = 450
const BULLET_DISTANCE : float = 800

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _unhandled_key_input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("fire_magic"):
		if state == MagicType.NEUTRAL and last_placed_cell!=HexCells.curr_cell:
			var pellet_instance : PathFollow2D = preload("res://scenes/pellet.tscn").instantiate()
			var dir :Vector2 = get_parent().map_to_local(HexCells.curr_cell)-get_parent().map_to_local(last_placed_cell)
			dir = dir.normalized()
			var trajectory: Path2D = Path2D.new()
			pellet_instance.get_node("VisibleOnScreenNotifier2D")\
			.screen_exited.connect(trajectory.queue_free)
			trajectory.curve = Curve2D.new() 
			
			trajectory.curve.add_point(Vector2.ZERO)
			var last_point: Vector2 = Vector2.ZERO
			var extra_points = randi_range(1,39)
			var progress = 0.;
			for i in range(extra_points):
				var temp = progress
				progress+=(1-progress)*1./(randf_range(1,extra_points-i))*clampf(abs(randfn(0,0.2)),0,1)
				if progress>=1:
					break
				var next_point = last_point + (dir*BULLET_DISTANCE-last_point)\
				.rotated(randfn(0,PI/lerpf(30,6,progress-temp)))*(progress-temp)/(1.-temp)
				var other_option = dir.rotated(randfn(0,PI/lerpf(100,10,progress-temp)))*BULLET_DISTANCE*progress
				next_point = abs(randfn(0.,0.05))*(other_option-next_point)+next_point
				trajectory.curve.add_point(next_point)
				last_point = next_point
			trajectory.curve.add_point(dir*BULLET_DISTANCE)
			
			add_child(trajectory)
			trajectory.add_child(pellet_instance)
	
	if state==MagicType.NEUTRAL:
		var possible_states = []
		if Input.is_action_just_pressed("turn_pure_to_heavy"):
			possible_states.append(MagicType.HEAVY)
		if Input.is_action_just_pressed("turn_pure_to_light"):
			possible_states.append(MagicType.LIGHT)
		if not possible_states.is_empty():
			state = possible_states.pick_random()
			change_state()

func change_state():
	match state:
		MagicType.NEUTRAL:
			modulate=Color.WHITE
		MagicType.HEAVY:
			modulate=Color.CRIMSON
		MagicType.LIGHT:
			modulate=Color.CYAN

func _process(delta: float) -> void:
	if get_child_count()==0:
		return
	#print(get_child_count())
	var finished_paths = []
	for child_path in get_children():
		if not is_instance_valid(child_path) or child_path is not Path2D:
			continue
		if child_path.get_child_count()==0:
			finished_paths.append(child_path)
			continue
		var pellet: PathFollow2D = child_path.get_child(0)
		if not is_instance_valid(pellet):
			finished_paths.append(child_path)
			continue
		var temp = pellet.progress_ratio
		pellet.progress+=BULLET_SPEED*delta
		if pellet.progress_ratio<temp:
			finished_paths.append(child_path)
	for child_path in finished_paths:
		child_path.queue_free()
