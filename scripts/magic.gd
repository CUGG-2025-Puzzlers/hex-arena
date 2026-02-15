extends Area2D
class_name Magic

enum MagicType {NEUTRAL, LIGHT, HEAVY, SHIELD}
var state = MagicType.NEUTRAL

static var last_placed_cell : Vector2i

const BULLET_SPEED : float = 450
const BULLET_DISTANCE : float = 800

var rolling : bool = false
var rolling_dir : Vector2
var rolling_pathfollow : PathFollow2D
var roll_speed : float

var self_cell: Vector2i

var health: float = 25
var damage: float = 0

var animation_timer : float = 0.
@onready var animated_sprite : Sprite2D = get_node("Sprite2D")

var points =[]

func _unhandled_key_input(_event: InputEvent) -> void:
	if rolling:
		return
	
	if Input.is_action_just_pressed("fire_magic"):
		if state in [MagicType.LIGHT, MagicType.HEAVY] and last_placed_cell!=HexCells.curr_cell:
			var dir :Vector2 = HexCells.map_to_local(HexCells.curr_cell)-HexCells.map_to_local(last_placed_cell)
			dir = dir.normalized()
			
			rolling_dir = dir
			match state:
				MagicType.LIGHT:
					roll_speed = BULLET_SPEED*1.2
				MagicType.HEAVY:
					roll_speed = BULLET_SPEED*0.6

			if HexCells.cell_dict.has(self_cell) and HexCells.cell_dict[self_cell]==self:
				HexCells.cell_dict[self_cell] = null
			
			get_node("VisibleOnScreenNotifier2D").screen_exited.connect(fizzle)
			rolling = true
			#instantiate_pellet(dir)
	
	if state==MagicType.NEUTRAL:
		var possible_states = []
		if Input.is_action_just_pressed("turn_pure_to_heavy"):
			possible_states.append(MagicType.HEAVY)
		if Input.is_action_just_pressed("turn_pure_to_light"):
			possible_states.append(MagicType.LIGHT)
		if Input.is_action_just_pressed("turn_pure_to_shield"):
			possible_states.append(MagicType.SHIELD)
		if not possible_states.is_empty():
			state = possible_states.pick_random()
			change_state()

func change_state():
	match state:
		MagicType.NEUTRAL:
			modulate=Color.WHITE
			health = 25
			damage = 0
		MagicType.LIGHT:
			modulate=Color.BLUE
			health = 50
			damage = 50
		MagicType.HEAVY:
			modulate=Color.CRIMSON
			health = 200
			damage = 100
			
			animated_sprite.texture=animated_sprite.texture.duplicate()
			animation_timer = randf()
			
		MagicType.SHIELD:
			modulate=Color.WEB_PURPLE
			health = 100
			damage = 100
			
			visualize_shield()
			scale = 0.9*Vector2.ONE
			var coll_shape :CollisionShape2D = get_node("CollisionShape2D")
			coll_shape.shape =	HexCells.hex_polygon_shape

func _process(delta: float) -> void:
	animation_timer+=randfn(delta/3.,delta/10)#+randfn(0,animation_timer/3.)
	if animation_timer>=1 or animation_timer<0:
		animation_timer=fposmod(animation_timer, 1)
	if state==MagicType.HEAVY:
		animated_sprite.texture.seamless_blend_skirt = lerpf(0.6,1,0.5*cos(2*PI*animation_timer)+0.5)
	
	if rolling:
		if not is_instance_valid(rolling_pathfollow):
			var trajectory : Path2D = Path2D.new()
			match state:
				MagicType.HEAVY:
					trajectory.curve = create_wiggly_path(rolling_dir, BULLET_DISTANCE*randf_range(1,2))
				MagicType.LIGHT:
					trajectory.curve = create_wiggly_path(rolling_dir, BULLET_DISTANCE*randf_range(0.5,1))
			
			#smooth_path(trajectory.curve)
			#points = trajectory.curve.get_baked_points()
			#queue_redraw()
			
			rolling_pathfollow = PathFollow2D.new()
			rolling_pathfollow.loop = false
			trajectory.global_position=global_position
			get_tree().current_scene.add_child(trajectory)
			trajectory.add_child(rolling_pathfollow)
			reparent(rolling_pathfollow)
		else:
			rolling_pathfollow.progress+=roll_speed*delta
			if rolling_pathfollow.progress_ratio>=1:
				var trajectory = rolling_pathfollow.get_parent()
				reparent(trajectory.get_parent())
				rolling_pathfollow.queue_free()
				trajectory.queue_free()
	#advance_child_pellets(delta)

func instantiate_pellet(dir: Vector2) -> void:
	var pellet_instance : PathFollow2D = preload("res://scenes/pellet.tscn").instantiate()
	var trajectory: Path2D = Path2D.new()
	pellet_instance.get_node("VisibleOnScreenNotifier2D")\
	.screen_exited.connect(trajectory.queue_free)
			
	trajectory.curve = create_wiggly_path(dir, BULLET_DISTANCE)
	add_child(trajectory)
	trajectory.add_child(pellet_instance)

func advance_child_pellets(delta: float) -> void:
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

func create_wiggly_path(dir: Vector2, dist: float) -> Curve2D:
	var path = Curve2D.new() 
	
	path.add_point(Vector2.ZERO)
	var last_point: Vector2 = Vector2.ZERO
	var extra_points = randi_range(1,39)
	var progress = 0.;
	
	for i in range(extra_points):
		var temp = progress
		progress+=(1-progress)*1./(randf_range(1,extra_points-i))*clampf(abs(randfn(0,0.2)),0,1)
		if progress>=1:
			break
		var next_point = last_point + (dir*dist-last_point)\
		.rotated(randfn(0,PI/lerpf(30,6,progress-temp)))*(progress-temp)/(1.-temp)
		var other_option = dir.rotated(randfn(0,PI/lerpf(100,10,progress-temp)))*dist*progress
		next_point = abs(randfn(0.,0.05))*(other_option-next_point)+next_point
		path.add_point(next_point)
		last_point = next_point
	
	path.add_point(dir*dist)
	return path


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group('magic'):
		#if area.state==state:
		#	print('jinx -- bumped into same kind of magic')
		take_damage(area.damage)
		#if area.state==MagicType.SHIELD and state<MagicType.HEAVY:
		#	fizzle()
		#else:
		#	take_damage(area.damage)

func take_damage(damage_to_take: float):
	health-=damage_to_take
	if health<=0:
		fizzle()

func fizzle():
	if is_instance_valid(rolling_pathfollow):
			if rolling_pathfollow.get_parent() is Path2D:
				rolling_pathfollow.get_parent().queue_free()
			else:
				rolling_pathfollow.queue_free()
	queue_free()

func visualize_shield():
	var polygon : Polygon2D = get_node("Shield Texture")
	polygon.polygon = HexCells.hex_shape.duplicate()
	
	var bounding_box: Rect2 = Rect2()
	bounding_box.position = Vector2(polygon.polygon[5].x,polygon.polygon[0].y)
	bounding_box.size = abs(bounding_box.position)*2
	
	var scale_vec : Vector2 = polygon.texture.get_size()/bounding_box.size
	polygon.texture_scale = Vector2.ONE*min(scale_vec.x,scale_vec.y)
	#polygon.texture_offset = -bounding_box.position
	#polygon.texture_offset = position-bounding_box.position
	#polygon.texture_rotation = randfn(0, PI*0.01)
	polygon.texture_rotation=randfn(PI*randi_range(0,5)/3,PI*0.05)
	
	polygon.visible=true
	get_node("Sprite2D").visible = false

func smooth_path(curve: Curve2D):
	"""
	for i in range(curve.get_point_count()):
		curve.set_point_left_tangent(i,Curve.TangentMode.TANGENT_LINEAR)
		curve.set_point_right_tangent(i,Curve.TangentMode.TANGENT_LINEAR)
	return
	"""
	for i in range(1,curve.get_point_count()-2):
		var prev = curve.get_point_position(i-1)
		var next = curve.get_point_position(i+1)
		var spline: Vector2 = (next-prev).normalized()*5
		curve.set_point_in(i,-spline)
		curve.set_point_out(i,spline)

func _draw() -> void:
	if len(points)>1:
		draw_polyline(points,Color.WHITE)
