extends Area2D
class_name Magic

enum MagicType {NEUTRAL, LIGHT, HEAVY, SHIELD}
var state = MagicType.NEUTRAL

static var last_placed_cell : Vector2i

# Hard enable/disable randomness for path generation
const RANDOM_PATHS = true
# Set between 1 (fully random) and 0 (fully corrected with snapping)
static var path_randomness_ratio : float = 0.4

static var cost = {
	MagicType.NEUTRAL: 5,
	MagicType.LIGHT: 5,
	MagicType.HEAVY: 10,
	MagicType.SHIELD: 5, }

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

var screen : Rect2

@onready var player_id : int = multiplayer.get_unique_id()

func _ready() -> void:
	var cell_dict : Dictionary = HexCells.player_unique_instance.cell_dict

	if cell_dict.has(self_cell) and is_instance_valid(cell_dict[self_cell]) and cell_dict[self_cell]!=self:
		cell_dict[self_cell].queue_free()
	else:
		HexCells.player_unique_instance.cell_dict[self_cell]=self
	animated_children = find_children("ChildLight*", "Sprite2D")
	
	screen.size = Vector2(HexCells.player_unique_instance.width,HexCells.player_unique_instance.height)
	screen.size*=1.33
	screen.position=-0.5*screen.size


func start_rolling(wiggly_path: PackedVector2Array):
	match state:
		MagicType.LIGHT:
			roll_speed = BULLET_SPEED*1.2
		MagicType.HEAVY:
			roll_speed = BULLET_SPEED*0.6
		_:
			return
	
	if HexCells.cell_dict.has(self_cell) and HexCells.cell_dict[self_cell]==self:
		HexCells.cell_dict[self_cell] = null
	
	if rolling:
		return
	
	var trajectory: Path2D = Path2D.new()
	trajectory.curve = Curve2D.new()
	for point in wiggly_path:
		trajectory.curve.add_point(point)
	
	rolling_pathfollow = PathFollow2D.new()
	rolling_pathfollow.loop = false
	rolling_pathfollow.rotates = false
	
	trajectory.global_position=global_position
	
	get_tree().current_scene.add_child(trajectory)
	trajectory.add_child(rolling_pathfollow)
	reparent(rolling_pathfollow)
	
	if state==MagicType.LIGHT:
		rotation = (wiggly_path[len(wiggly_path)-1]-wiggly_path[0]).angle()
	
	rolling = true

func change_state(new_state: MagicType):
	state = new_state
	match state:
		MagicType.NEUTRAL:
			modulate=Color.WHITE
			health = 25
			damage = 0
		MagicType.LIGHT:
			#modulate=Color.BLUE
			health = 30
			damage = 40
			
			animated_sprite.visible = false
			
			var arrow_particles : Node2D = get_node("ArrowParticles")
			arrow_particles.visible = true
			arrow_particles.rotation = rolling_dir.angle()
			#arrow_particles.scale *= 4
		MagicType.HEAVY:
			#modulate=Color.CRIMSON
			health = 40
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
			health = 80
			damage = 30
			
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
		if not screen.has_point(global_position):
			fizzle()
			
	#advance_child_pellets(delta)

func instantiate_pellet(dir: Vector2) -> void:
	var pellet_instance : PathFollow2D = preload("res://scenes/pellet.tscn").instantiate()
	var trajectory: Path2D = Path2D.new()
	pellet_instance.get_node("VisibleOnScreenNotifier2D")\
	.screen_exited.connect(trajectory.queue_free)
	
	trajectory.curve = Curve2D.new()
	for point in create_wiggly_path(dir, BULLET_DISTANCE):
		trajectory.curve.add_point(point)
	#trajectory.curve = create_wiggly_path(dir, BULLET_DISTANCE)
	add_child(trajectory)
	trajectory.add_child(pellet_instance)

# Advances pellets along their path
# Destroys any paths that are completed
func advance_child_pellets(delta: float) -> void:
	if get_child_count() == 0:
		return
	
	var finished_paths = []
	for child_path in get_children():
		# Skip non-Path2D children
		if not is_instance_valid(child_path) or child_path is not Path2D:
			continue
		
		# Path has no children, mark it as finished and continue to next path
		if child_path.get_child_count() == 0:
			finished_paths.append(child_path)
			continue
		
		# Path has invalid children, mark it as finished and continue to next path
		var pellet: PathFollow2D = child_path.get_child(0)
		if not is_instance_valid(pellet):
			finished_paths.append(child_path)
			continue
		
		# Advance pellet and mark path as finished if pellet progress ratio decreased
		var temp = pellet.progress_ratio
		pellet.progress += BULLET_SPEED * delta
		if pellet.progress_ratio < temp:
			finished_paths.append(child_path)
	
	# Destroy finished paths
	for child_path in finished_paths:
		child_path.queue_free()

# Creates a path to (dir * dist) with random deviations
static func create_wiggly_path(dir: Vector2, dist: float) -> PackedVector2Array:
	var path : PackedVector2Array = []
	
	path.append(Vector2.ZERO)
	var last_point: Vector2 = Vector2.ZERO
	var extra_points: int = 0
	
	if RANDOM_PATHS:
		extra_points = randi_range(1,39)
	
	var progress: float = 0;
	
	for i in range(extra_points, 0, -1):
		# Progress by a random amount of the remaining progress
		var rand: float = clampf(abs(randfn(0, 0.2)), 0,1) / randf_range(1, i)
		var diff: float = (1 - progress) * rand
		progress += diff
		
		# Stop adding extra points after reaching 100% progress
		if progress >= 1:
			break
		
		# Get a randomly rotated remaining distance vector
		# Next point is the last point plus the random amount of the rotated remainder 
		var rand_rot: float = randfn(0, PI / lerpf(30, 6, diff))
		var rotated_remaining: Vector2 = (dir * dist - last_point).rotated(rand_rot)
		var next_point: Vector2 = last_point + rotated_remaining * rand
		
		# Get a randomly rotated current progress vector
		# Nudge the next point slightly in the direction of the rotated progress
		rand_rot = randfn(0, PI / lerpf(100, 10, diff))
		var rotated_cur_progress: Vector2 = dir.rotated(rand_rot) * dist * progress
		next_point += abs(randfn(0, 0.05)) * (rotated_cur_progress - next_point)
		
		# Interpolate between offset and straightened next point
		next_point = (1.-path_randomness_ratio) * ((next_point-path[0]).project(dir)+path[0]-next_point)+next_point
		
		path.append(next_point)
		last_point = next_point
	
	path.append(dir * dist)
	return path

# Take damage when colliding with other magic
func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group('magic') or \
	area.player_id==player_id and not \
	(area.state==MagicType.SHIELD or state ==MagicType.SHIELD):
		return
	
	take_damage(area.damage)
	
	#what is this force fizzle lol, commented out...
	#if state!=MagicType.SHIELD and area.state in [MagicType.SHIELD, MagicType.HEAVY]:
	#	fizzle()

# Decreases this magic object's health
# Destroys it if no health remains
func take_damage(damage_to_take: float):
	health -= damage_to_take
	
	if health <= 0:
		fizzle()

# Destroys this object and its associated path
func fizzle():
	if is_queued_for_deletion() or not is_inside_tree():
		return
	
	if is_instance_valid(get_tree()) and is_instance_valid(get_tree().current_scene):
		var magic_particles_instance = get_node("CPUParticles2D")
		magic_particles_instance.reparent(get_tree().current_scene)
		magic_particles_instance.finished.connect(magic_particles_instance.queue_free)
		magic_particles_instance.restart()
	
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
	if state == MagicType.HEAVY:
		if points.is_empty():
			return
		
		_draw_heavy()

# Draws the heavy magic red and white texture
func _draw_heavy():
	var fill_prog: float  = 0.5 * (cos(2 * PI * animation_timers[0]) + 1)
	
	draw_circle(Vector2.ZERO, lerpf(15.5, 17, fill_prog), Color.RED)
	draw_circle(Vector2.ZERO, lerpf(12, 15, fill_prog), Color.WHITE)
	
	var scaled_points = points.duplicate()
	for i in range(len(points)):
		scaled_points[i] *= 0.5 * (cos(2 * PI * animation_timers[i + 1]) + 1)
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
