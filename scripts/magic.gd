extends Area2D
class_name Magic

enum MagicType {NONE, NEUTRAL, LIGHT, HEAVY, PASSIVE}
@export var state : MagicType = MagicType.NONE


static var last_placed_cell : Vector2i

# Hard enable/disable randomness for path generation
const RANDOM_PATHS = true
# Set between 1 (fully random) and 0 (fully corrected with snapping)
static var path_randomness_ratio : float = 0.4

const BULLET_DISTANCE : float = 800

var rolling : bool = false
var rolling_dir : Vector2
var rolling_pathfollow : PathFollow2D

var self_cell: Vector2i
var player_owner : Player
var player_id : int = -1
var telemetry_name: String = ""


@export var own_cost: float
@export var own_health: float
@export var damage: float
@export var roll_speed: float
@export var collides_w_own: bool

@export var own_transforms: Dictionary[MagicType, MagicStats] = {
	MagicType.NEUTRAL: null,
	MagicType.LIGHT: null,
	MagicType.HEAVY: null,
	MagicType.PASSIVE: null
}

@onready var magic_particles_instance : CPUParticles2D = $FizzleParticles


var process_callables : Array[Callable]

var screen : Rect2

signal started_rolling


# By default, reads @export stats from static dictionaries (JSON)
# Take up own cell, calculate screen size
func setup():
	if is_instance_valid(HexCells.player_unique_instance):
		
		var owner_hexcells : HexCells = HexCells.player_unique_instance
		
		var cell_dict : Dictionary = owner_hexcells.cell_dict

		if cell_dict.has(self_cell) and is_instance_valid(cell_dict[self_cell]) and cell_dict[self_cell]!=self:
			cell_dict[self_cell].queue_free()
		else:
			owner_hexcells.cell_dict[self_cell]=self
		
		screen.size = Vector2(owner_hexcells.width,owner_hexcells.height)
		screen.size*=1.33
		screen.position=-0.5*screen.size

func reset_stats(stats_reference: MagicStats):
	state = stats_reference.type
	own_cost = stats_reference.cost
	own_health = stats_reference.health
	damage = stats_reference.damage
	roll_speed = stats_reference.speed
	telemetry_name = stats_reference.magic_name
	collides_w_own = stats_reference.collide_w_own
	
	own_transforms.clear()
	for key in stats_reference.transform_dict:
		var resource_val = stats_reference.transform_dict[key]
		own_transforms[key] = resource_val as MagicStats


func place_instance_for_player(cell: Vector2i, _player_owner: Player = null, _stats_reference: MagicStats = null) -> void:
	var hex_cells: HexCells = HexCells.player_unique_instance
	
	if is_instance_valid(HexCells.cell_dict[cell]):
		HexCells.cell_dict[cell].queue_free()
	
	position = HexCells.map_to_local(cell)
	self_cell = cell
	HexCells.cell_dict[cell] = self
	
	player_owner = _player_owner
	if _stats_reference:
		reset_stats(_stats_reference)
	
	if player_owner:
		player_id = _player_owner.player_id
	else:
		player_id = -1
	
	hex_cells.add_child(self, true)
	name = "Magic"
	add_to_group('magic')
	
	if player_id > 0 and player_id != multiplayer.get_unique_id():
		modulate = Color(0.819, 0.205, 0.204, 1.0)

func get_telemetry_name() -> String:
	if not telemetry_name.is_empty():
		return telemetry_name
	return MagicType.keys()[state] if state != MagicType.NONE else "Magic"


# Create and start moving along provided path
func start_rolling(wiggly_path: PackedVector2Array):
	# Might need a separate 'can_roll' property
	if roll_speed == 0:
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
	
	rolling = true
	
	if _advance_rolling not in process_callables:
		process_callables.append(_advance_rolling)
	
	rolling_dir = wiggly_path[len(wiggly_path)-1] - wiggly_path[0]
	rolling_dir = rolling_dir.normalized()
	
	started_rolling.emit()


# Subclasses with explicit attacks can suppress the base Player collision damage.
func handles_player_contact() -> bool:
	return false


# Only active, travelling Light/Heavy magic is vulnerable by default.
# Stationary or special attacks override this when needed.
func can_be_cut_by_wire() -> bool:
	return (
		rolling
		and state in [MagicType.LIGHT, MagicType.HEAVY]
		and not is_queued_for_deletion()
	)


func change_state_cost(_new_state: MagicType) -> float:
	if own_transforms.has(_new_state) and own_transforms[_new_state]:
		return own_transforms[_new_state].cost
	else:
		return -1

# Replace scene with a different magic scene
func change_state_for_player(new_magic_state: MagicType, _player_owner: Player):
	monitoring = false
	monitorable = false
	
	var new_magic : Magic = own_transforms[new_magic_state].scene.instantiate()
	
	new_magic.place_instance_for_player(self_cell, _player_owner, own_transforms[new_magic_state])
	
	queue_free()

# Callable for moving forward along a path
func _advance_rolling(delta: float):
	if rolling:
		if is_instance_valid(rolling_pathfollow):
			rolling_pathfollow.progress+=roll_speed*delta
			
			if rolling_pathfollow.progress_ratio>=1:
				
				var trajectory = rolling_pathfollow.get_parent()
				trajectory.global_position=global_position
				rolling_pathfollow.progress_ratio = 0

		if not screen.has_point(global_position):
			fizzle()



# Update each callable function in process_callables every frame
func _process(delta: float) -> void:
	for custom_function in process_callables:
		custom_function.call(delta)

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
	if area.is_in_group('magic') and \
	(not area.player_id==player_id \
	or collides_w_own or area.collides_w_own):
		take_damage(area.damage)

# Decreases this magic object's health
# Destroys it if no health remains
func take_damage(damage_to_take: float):
	own_health -= damage_to_take
	
	if own_health <= 0:
		fizzle()

# Destroys this object and its associated path
func fizzle():
	if is_queued_for_deletion() or not is_inside_tree():
		return
	
	if is_instance_valid(get_tree()) and is_instance_valid(get_tree().current_scene):
		magic_particles_instance.reparent(get_tree().current_scene)
		magic_particles_instance.finished.connect(magic_particles_instance.queue_free)
		magic_particles_instance.restart()
	
	if is_instance_valid(rolling_pathfollow):
		if rolling_pathfollow.get_parent() is Path2D:
			rolling_pathfollow.get_parent().queue_free()
		else:
			rolling_pathfollow.queue_free()
	
	queue_free()
