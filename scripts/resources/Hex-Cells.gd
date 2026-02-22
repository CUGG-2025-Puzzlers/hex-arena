@tool
extends Path2D
class_name HexCells


@onready var text = get_node("Coordinates")
# Radius == side
@export var r: float = 60.:
	set(new_r):
		r = new_r
		recalculate()

static var hex_height: float #= 2*r
static var hex_width: float #= sqrt(3)*r

@export var width: float = 2000: #5000.:
	set(new_w):
		width=new_w
		recalculate()
@export var height: float = 2000: #5000.
	set(new_h):
		height=new_h
		recalculate()

var vertical_n : int
var horizontal_n : int

static var cell_dict: Dictionary = {}
static var curr_cell: Vector2i = Vector2i()

var points = []
static var hex_shape = []
static var hex_polygon_shape : ConvexPolygonShape2D

static var player_unique_instance : HexCells

func recalculate() -> void:
	hex_height = 2*r
	hex_width = sqrt(3)*r
	
	hex_shape = []
	for i in range(6):
		hex_shape.append(r*Vector2.UP.rotated(i*PI/3.))
	
	hex_polygon_shape = ConvexPolygonShape2D.new()
	hex_polygon_shape.points=hex_shape.duplicate()
	
	hex_shape.append(hex_shape.front())
	
	vertical_n = max(int(height/(hex_height))-1,0)+1
	horizontal_n = max(int(width/(hex_width))-1,0)+1
	
	points = []
	cell_dict = Dictionary()
	
	for j in range(vertical_n):
		for i in range(horizontal_n):
			var map_point : Vector2i = Vector2i(int(i-horizontal_n/2.),int(j-vertical_n/2.))
			
			# Create mapping to fill in the future
			cell_dict[map_point]=null
			
			var hex_points = get_hex_points_around(map_point)
			points.append(hex_points)
	
	queue_redraw()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player_unique_instance = self
	recalculate()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		#event.global_position -= get_viewport_rect().size/2
		#get_node("LazyFollow").position = event.global_position
		#position = event.global_position
		
		var new_curr_cell = local_to_map(get_global_mouse_position())
		
		if curr_cell!=new_curr_cell:
			curr_cell = new_curr_cell
			
			text.text = str(curr_cell)
			if cell_dict.has(curr_cell):
				get_node("LazyFollow").position = map_to_local(curr_cell)
			
			Events.emit_signal("select_new_cell",curr_cell)
		
		text.position = get_global_mouse_position()+Vector2(25,-5)

@rpc("call_local","any_peer","reliable") 
func change_magic(pos: Vector2, radius_cells: Array, new_state: Magic.MagicType, player_id: int, player_stats, how_many:int): #rng_seed: int
	var change_around_cell = local_to_map(pos)
	
	var player_cells = []
	for player in get_tree().current_scene.find_child("Players").get_children():
		player_cells.append(local_to_map(player.get_node("CollisionShape2D").global_position))
	
	var surrounding_cells = radius_cells.duplicate()
	for i in range(len(surrounding_cells)):
		surrounding_cells[i]=local_to_map(map_to_local(change_around_cell)+map_to_local(surrounding_cells[i]))

	surrounding_cells.erase(change_around_cell)
	"""
	var rng : RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	rng.state = 0
	for i in range(len(surrounding_cells)):
		var ind2 = len(surrounding_cells)-i-1
		var ind1 = rng.randi()%(ind2+1)
		var temp = surrounding_cells[ind2]
		surrounding_cells[ind2]=surrounding_cells[ind1]
		surrounding_cells[ind1]=temp
	"""
	surrounding_cells.append(change_around_cell)
	
	var counter = 0
	var owned = player_id == multiplayer.get_unique_id()
	
	while not surrounding_cells.is_empty():
		var cell_to_check = surrounding_cells.pop_back()
		if cell_dict.has(cell_to_check) and is_instance_valid(cell_dict[cell_to_check]):
			var magic_instance : Magic = cell_dict[cell_to_check]
			
			if magic_instance.state == Magic.MagicType.NEUTRAL \
			and magic_instance.player_id == player_id \
			and not (cell_to_check in player_cells and new_state==Magic.MagicType.SHIELD):
				if counter<how_many:
					magic_instance.change_state(new_state)
					counter+=1
					if owned:
						player_stats.use_mana(Magic.cost[new_state])
				else:
					break

@rpc("call_local", "any_peer", "reliable")
func place_magic_in_cell(mouse_pos: Vector2, player_cell:Vector2i, radius_cells: Array, player_id: int, player_stats):
	var player_pos = map_to_local(player_cell)
	var cell_to_place = local_to_map(mouse_pos)
	var in_radius = false
	for radius_cell in radius_cells:
		if cell_to_place==local_to_map(player_pos+map_to_local(radius_cell)):
			in_radius=true
			break
	if not in_radius:
		return
		
	if cell_dict.has(cell_to_place) and not is_instance_valid(cell_dict[cell_to_place]):
		var magic_instance : Magic = preload("res://scenes/magic.tscn").instantiate()
		
		
		magic_instance.position = map_to_local(cell_to_place)
		magic_instance.self_cell = cell_to_place
		cell_dict[cell_to_place]=magic_instance
		add_child(magic_instance, true)
		magic_instance.name = "Magic"
		magic_instance.add_to_group('magic')
		
		if player_id!=multiplayer.get_unique_id():
			magic_instance.modulate = Color.WEB_MAROON
		else:
			Magic.last_placed_cell=cell_to_place
			get_node("LastMagic").global_position=map_to_local(cell_to_place)
			get_node("LastMagic").visible = true
			player_stats.use_mana(Magic.cost[Magic.MagicType.NEUTRAL])
		
		magic_instance.player_id = player_id

@rpc("call_local","any_peer","reliable")
func launch_magic_in_cell(cell: Vector2i, wiggly_path_points: PackedVector2Array, player_id: int):
	for magic_instance in get_tree().get_nodes_in_group('magic'):
		if is_instance_valid(magic_instance) and magic_instance.player_id==player_id and magic_instance.self_cell == cell:
			magic_instance.start_rolling(wiggly_path_points)

func _draw() -> void:
	if points.is_empty():
		return
	
	for hex_points in points:
		draw_polyline(hex_points,Color.CYAN) #1.01, true
	
	"""
	var hex_points = get_hex_points_around(curr_cell)
	draw_polyline(hex_points,Color.MAGENTA)
	
	for cell in get_surrounding_cells_in_radius(curr_cell,2):
		hex_points = get_hex_points_around(cell)
		draw_polyline(hex_points, Color.MAGENTA)
	"""

func get_hex_points_around(pos: Vector2i):
	var hex_points = hex_shape.duplicate()
	var center = map_to_local(pos)
	
	for k in range(len(hex_points)):
		hex_points[k]+=center
	return hex_points

func local_to_map(pos: Vector2):
	var x = 0
	var y = pos.y/r
	
	if fposmod(y+0.5,1.5)>1:
		var x0 = floori(pos.x/(hex_width))
		var x1 = roundi(pos.x/(hex_width))
		
		var y0 = 2*floori(floor((y+1.)/1.5)/2.)
		var y1 = 2*floori((floor((y+1.)/1.5)-1.)/2.)+1
		
		if pos.x<0:
			var temp = y0
			y0 = y1
			y1 = temp
		
		if floori(abs(pos.x)/(hex_width/2.)) % 2:
			var temp = y0
			y0 = y1
			y1 = temp
		
		var point0 = Vector2i(x0,y0)
		var point1 = Vector2i(x1,y1)
		
		if (pos-map_to_local(point0)).project((map_to_local(point1)-map_to_local(point0)).normalized()).length()<hex_width/2.:
			y = y0
			x = x0
		else:
			y=y1
			x=x1
		
		# Glitchy version
		#y = roundi(sign(pos.y)*0.5*(abs(pos.x)+abs(pos.y)*sqrt(3))/hex_width)
		#x = floori(pos.x/hex_width+(0. if (abs(y)%2) else 0.5))
		# Freer version
		#y = int((y-0.5)/1.5)
		#x = int(pos.x/hex_width+(0. if (abs(y)%2) else 0.5))
	else:
		
		y = int(sign(pos.y)*(abs(y)+0.5)/1.5)
		x = floori(pos.x/hex_width+(0. if (abs(y)%2) else 0.5))
	
	var result = Vector2i(x,y)
	
	return result

static func map_to_local(pos: Vector2i):
	var i = pos.x
	var j = pos.y
	var right_displacement : int = abs(j) % 2
	var center : Vector2 = Vector2(i*hex_width
		+ (hex_width/2)*right_displacement, hex_height*0.75*j)
	return center

static func get_surrounding_cells(cell: Vector2i) -> Array:
	var cells = [Vector2i(0,-1), Vector2i(1,0), Vector2i(0,1), Vector2i(-1,1), Vector2i(-1,0), Vector2i(-1,-1)]
	if fposmod(cell.y,2):
		for i in [0,2,3,5]:
			cells[i]+=Vector2i(1,0)
	for i in range(len(cells)):
		cells[i]+=cell
	return cells

static func get_surrounding_cells_in_radius(cell: Vector2i, radius: int) -> Array:
	var surrounding_cells = [cell]
	var extend_past_index = 0
	for i in range(radius):
		var ind = extend_past_index
		var limit = len(surrounding_cells)
		while ind < limit:
			var new_surround_cells = get_surrounding_cells(surrounding_cells[ind])
			ind+=1
			for surrond_cell in new_surround_cells:
				if surrond_cell not in surrounding_cells:
					surrounding_cells.append(surrond_cell)
			extend_past_index+=1
	return surrounding_cells
