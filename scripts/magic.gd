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

var animation_timers : Array[float] = [0., 0.]
var animation_total_times : Array[float] = [3., PI]

@onready var animated_sprite : Sprite2D = get_node("Sprite2D")
@onready var animated_children : Array
var shield_animated_texture : GradientTexture2D

var points =[]

var player_id : int

func _ready() -> void:
	animated_children = find_children("ChildLight*", "Sprite2D")

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
	

func change_state(new_state: MagicType):
	state = new_state
	match state:
		MagicType.NEUTRAL:
			modulate=Color.WHITE
			health = 25
			damage = 0
		MagicType.LIGHT:
			#modulate=Color.BLUE
			health = 50
			damage = 50
			
			animated_sprite.visible = false
			
			var arrow_particles : Node2D = get_node("ArrowParticles")
			arrow_particles.visible = true
			arrow_particles.rotation = rolling_dir.angle()
			#arrow_particles.scale *= 4
		MagicType.HEAVY:
			#modulate=Color.CRIMSON
			health = 200
			damage = 100
			
			animated_sprite.visible = false
			animated_sprite = get_node("EyeSprite")
			animated_sprite.visible = true
			animated_sprite.scale = Vector2.ONE*randf_range(0.2,0.3)
			animated_sprite.rotation=randf()*2*PI
			animated_sprite.flip_h = randf()<0.5
			animated_sprite.flip_v = randf()<0.5
			
			animation_timers = [0.]
			animation_total_times = [3.]
			points = []
			for i in range(randi_range(5,23)):
				points.append(Vector2.ONE.rotated(randf()*2*PI)*randf_range(5,15))
				animation_timers.append(0.)
				animation_total_times.append(randf_range(2,8))
			queue_redraw()
			
		MagicType.SHIELD:
			#modulate=Color.WEB_PURPLE
			health = 100
			damage = 100
			
			animation_total_times[0] = 5
			shield_animated_texture = find_child("Shield Glow").texture.duplicate()
			find_child("Shield Glow").texture = shield_animated_texture
			visualize_shield()
			scale = 0.9*Vector2.ONE
			var coll_shape :CollisionShape2D = get_node("CollisionShape2D")
			coll_shape.shape = HexCells.hex_polygon_shape
			get_node("StaticBody2D").add_child(coll_shape.duplicate())

func _process(delta: float) -> void:
	for i in range(len(animation_timers)):
		animation_timers[i]+=randfn(delta/animation_total_times[i],delta/animation_total_times[i]*0.3)#+randfn(0,animation_timers[i]/3.)
		if animation_timers[i]>=1 or animation_timers[i]<0:
			animation_timers[i]=fposmod(animation_timers[i], 1)
	match state:
		MagicType.HEAVY:
			#animated_sprite.texture.seamless_blend_skirt = lerpf(0.6,1,0.5*cos(2*PI*animation_timer)+0.5)
			queue_redraw()
			animated_sprite.scale.y=0.5*(cos(2*PI*animation_timers[0])+1)*animated_sprite.scale.x
			animated_sprite.scale.y = clampf(animated_sprite.scale.y, 0.07, animated_sprite.scale.x)
			animated_sprite.position = Vector2.UP.rotated(animated_sprite.rotation)*cos(2*PI*(animation_timers[0]+0.2))*4
		MagicType.SHIELD:
			shield_animated_texture.fill_to = Vector2.ONE*lerpf(0.6,0.8,0.5*(cos(2*PI*animation_timers[0])+1))*sqrt(2)
		MagicType.NEUTRAL:
			animated_children[0].position = Vector2.RIGHT.rotated(2*PI*animation_timers[0])*20
			animated_sprite.position = Vector2.UP*sin(animation_timers[1]*2*PI)*6
			#animated_children[1].position = Vector2.RIGHT.rotated(-2*PI*animation_timer*3)*150
		MagicType.LIGHT:
			var dir : Vector2 = rolling_dir
			if not rolling:
				#dir = (get_global_mouse_position()-global_position).normalized()
				dir = HexCells.map_to_local(HexCells.curr_cell)-HexCells.map_to_local(last_placed_cell)
				dir = dir.normalized()
				if dir == Vector2.ZERO:
					dir = Vector2.UP
			get_node("ArrowParticles").rotation = dir.angle()
	
	if rolling:
		if is_instance_valid(rolling_pathfollow):
			rolling_pathfollow.progress+=roll_speed*delta
			if state == MagicType.HEAVY:
				rotation = 2*PI*rolling_pathfollow.progress_ratio
			if rolling_pathfollow.progress_ratio>=1:
				
				var trajectory = rolling_pathfollow.get_parent()
				trajectory.global_position=global_position
				rolling_pathfollow.progress_ratio = 0
				"""
				match state:
					MagicType.HEAVY:
						trajectory.curve = create_wiggly_path(rolling_dir, BULLET_DISTANCE*randf_range(1,2))
					MagicType.LIGHT:
						trajectory.curve = create_wiggly_path(rolling_dir, BULLET_DISTANCE*randf_range(0.5,1))
				"""
		else:
			var trajectory : Path2D = Path2D.new()
			match state:
				MagicType.HEAVY:
					trajectory.curve = create_wiggly_path(rolling_dir, BULLET_DISTANCE*randf_range(1,2))
				MagicType.LIGHT:
					trajectory.curve = create_wiggly_path(rolling_dir, BULLET_DISTANCE*randf_range(0.5,1))
			
			
			rolling_pathfollow = PathFollow2D.new()
			rolling_pathfollow.loop = false
			rolling_pathfollow.rotates = false
			trajectory.global_position=global_position
			get_tree().current_scene.add_child(trajectory)
			trajectory.add_child(rolling_pathfollow)
			reparent(rolling_pathfollow)
			
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
	var bounding_box: Rect2 = Rect2()
	bounding_box.position = Vector2(HexCells.hex_shape[5].x,HexCells.hex_shape[0].y)
	bounding_box.size = abs(bounding_box.position)*2
	
	for polygon in find_children("Shield*", "Polygon2D"):
		polygon.polygon = HexCells.hex_shape
		
		var scale_vec : Vector2 = polygon.texture.get_size()/bounding_box.size
		#polygon.texture_scale = Vector2.ONE*min(scale_vec.x,scale_vec.y)
		#polygon.texture_scale = scale_vec
		polygon.texture_scale = Vector2.ONE*max(scale_vec.x,scale_vec.y)
		polygon.texture_scale*=2
	
		#polygon.texture_offset = -bounding_box.position
		#polygon.texture_offset = position-bounding_box.position
		#polygon.texture_rotation = randfn(0, PI*0.01)
		#polygon.texture_rotation=randfn(PI*randi_range(0,5)/3,PI*0.05)
	
		polygon.visible=true
	get_node("Sprite2D").visible = false


func _draw() -> void:
	if not points.is_empty():
		var fill_prog = 0.5*(cos(2*PI*animation_timers[0])+1)
		
		draw_circle(Vector2.ZERO, lerpf(15.5,17,fill_prog), Color.RED)
		draw_circle(Vector2.ZERO, lerpf(12,15,fill_prog), Color.WHITE)
		
		for i in range(len(points)):
			var point = points[i]*0.5*(cos(2*PI*animation_timers[i+1])+1)
			var tri = [point*2.5]
			tri.append(point-point.rotated(PI/12))
			tri.append(point-point.rotated(-PI/12))
			tri.append(point*2.5)
			draw_polygon(tri,[Color.RED])
		
		
		for i in range(len(points)):
			var point = points[i]*0.5*(cos(2*PI*animation_timers[i+1])+1)
			var tri = [point*lerpf(1.5,2,fill_prog)]
			tri.append(point-point.rotated(PI/lerpf(12,20,fill_prog)))
			tri.append(point-point.rotated(-PI/lerpf(12,20,fill_prog)))
			tri.append(point*lerpf(1.5,2,fill_prog))
			draw_polygon(tri,[Color.WHITE])
