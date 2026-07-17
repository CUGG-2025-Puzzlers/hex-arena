@tool
extends Path2D
class_name HexCells


@onready var text = $Coordinates
@onready var last_magic = $LastMagic

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
static var players_cells: Dictionary = {1: Vector2i()}
static var curr_cell: Vector2i = Vector2i()


static var hex_shape = []
static var hex_polygon_shape : ConvexPolygonShape2D

static var v : Vector2
static var w : Vector2
const hex_vw_points_around = [Vector2i.RIGHT, Vector2i.ONE, Vector2i.DOWN, Vector2i.LEFT, -Vector2i.ONE, Vector2i.UP]

static var player_unique_instance : HexCells

func recalculate() -> void:
	hex_height = 2*r
	hex_width = sqrt(3)*r

	v = Vector2.UP*r
	w = Vector2.RIGHT.rotated(PI/6)*r

	hex_shape = []
	for i in range(6):
		hex_shape.append(r*Vector2.UP.rotated(i*PI/3.))

	hex_polygon_shape = ConvexPolygonShape2D.new()
	hex_polygon_shape.points=hex_shape.duplicate()

	hex_shape.append(hex_shape.front())

	vertical_n = max(int(height/(hex_height))-1,0)+1
	horizontal_n = max(int(width/(hex_width))-1,0)+1

	cell_dict = Dictionary()

	for j in range(vertical_n):
		for i in range(horizontal_n):
			var map_point : Vector2i = Vector2i(int(i-horizontal_n/2.),int(j-vertical_n/2.))

			# Create mapping to fill in the future
			cell_dict[map_point]=null

	var grid_outline: GridOutline = find_child("GridOutline")
	grid_outline.recalculate()


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

		#var vw  = local_to_vw(get_global_mouse_position())
		#vw = Vector2i(roundi(vw.x),roundi(vw.y))
		#text.text = str(new_curr_cell)+"\n"+str(vw)
		if curr_cell!=new_curr_cell:
			curr_cell = new_curr_cell


			if cell_dict.has(curr_cell):
				get_node("LazyFollow").position = map_to_local(curr_cell)

			Events.emit_signal("select_new_cell",curr_cell)

		text.position = get_global_mouse_position()+Vector2(25,-5)

@rpc("call_local","any_peer","reliable")
func try_and_change_magic_for_player(pos: Vector2, radius_cells: Array, new_state: Magic.MagicType, player_id: int, mana: float): #rng_seed: int
	if not multiplayer.is_server():
		return false

	var change_around_cell = local_to_map(pos)

	var player_owner: Player = null
	var player_cell: Vector2i = local_to_map(pos)
	var other_player_cells = []
	for player in get_tree().current_scene.find_child("Players").get_children():
		if player.player_id == player_id:
			player_owner = player
		else:
			other_player_cells.append(local_to_map(player.get_node("CollisionShape2D").global_position))

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

	while not surrounding_cells.is_empty():
		var cell_to_check = surrounding_cells.pop_back()
		if cell_dict.has(cell_to_check) and is_instance_valid(cell_dict[cell_to_check]):
			var magic_instance : Magic = cell_dict[cell_to_check]

			# Spawn logic: can turn unclaimed or own magic
			# Cannot change any magic on opponents' cells
			# Cannot create shield on own cell
			if (magic_instance.player_id < 0 or magic_instance.player_id == player_id) \
			and not (cell_to_check in other_player_cells) and \
			not (cell_to_check==player_cell and new_state==Magic.MagicType.PASSIVE):
				var cost = magic_instance.change_state_cost(new_state)
				if cost>=0 and mana>=cost:
					change_magic_in_cell_for_player.rpc(cell_to_check, new_state, player_id)

					player_owner._use_mana.rpc(cost)
					mana-=cost
				else:
					continue

@rpc("call_local", "authority", "reliable")
func change_magic_in_cell_for_player(cell: Vector2i, new_state: Magic.MagicType, player_id: int):
	if not (cell_dict.has(cell) and is_instance_valid(cell_dict[cell])):
		push_error('Could not get the magic instance for changing')
		return

	var player_owner: Player = get_node("../Players/"+str(player_id))
	if player_owner == null or player_owner.player_id!=player_id:
		push_error('Unable to get the player who changed the magic')

	var magic_instance: Magic = cell_dict[cell]
	magic_instance.change_state_for_player(new_state, player_owner)


@rpc("call_local", "any_peer", "reliable")
func try_place_magic_for_player(mouse_pos: Vector2, type: Magic.MagicType,
player_cell:Vector2i, radius_cells: Array, _player_id: int):
	if not multiplayer.is_server():
		return false

	var player_pos = map_to_local(player_cell)
	var cell_to_place = local_to_map(mouse_pos)

	if not cell_dict.has(cell_to_place) or is_instance_valid(cell_dict[cell_to_place]):
		return false

	var in_radius = false
	for radius_cell in radius_cells:
		if cell_to_place==local_to_map(player_pos+map_to_local(radius_cell)):
			in_radius=true
			break
	if not in_radius:
		return false

	"""
	# Prevents placing magic on top of other player
	# In turn, can softlock both players inside a shield circle

	var other_player_cells = []
	for player in get_tree().current_scene.find_child("Players").get_children():
		if int(player.name)!=_player_id:
			other_player_cells.append(local_to_map(player.get_node("CollisionShape2D").global_position))
	if cell_to_place in other_player_cells:
		return false
	"""

	place_magic_in_cell_for_player.rpc(cell_to_place, type, _player_id)
	return true

@rpc("call_local", "authority", "reliable")
func place_magic_in_cell_for_player(cell: Vector2i, type: Magic.MagicType, player_id: int):
	if is_instance_valid(cell_dict[cell]):
		cell_dict[cell].queue_free()

	var player_owner: Player = get_node("../Players/"+str(player_id))
	if player_owner == null or player_owner.player_id!=player_id:
		push_error('Unable to get the player who placed the magic')

	var magic_instance: Magic = player_owner.preset.magics[type].scene.instantiate()

	magic_instance.place_instance_for_player(cell, player_owner, player_owner.preset.magics[type])

	if multiplayer.is_server():
		player_owner._use_mana.rpc(magic_instance.own_cost)

	if player_id == multiplayer.get_unique_id():
		Magic.last_placed_cell = cell
		last_magic.position = map_to_local(cell)
		last_magic.visible = true
		last_magic.reset_timer(cell)

@rpc("call_local","any_peer","reliable")
func launch_magic_in_cell(cell: Vector2i, wiggly_path_points: PackedVector2Array, player_id: int):
	for magic_instance in get_tree().get_nodes_in_group('magic'):
		if is_instance_valid(magic_instance) and magic_instance.player_id==player_id and magic_instance.self_cell == cell:
			magic_instance.start_rolling(wiggly_path_points)


static func get_hex_points_around(pos: Vector2i):
	var hex_points = hex_shape.duplicate()
	var center = map_to_local(pos)

	for k in range(len(hex_points)):
		hex_points[k]+=center
	return hex_points

static func get_vw_points_around_vw_point(pos: Vector2i):
	var hex_points = hex_vw_points_around.duplicate()

	for k in range(len(hex_points)):
		hex_points[k]+=pos
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

static func get_surrounding_cells_in_radius(cell: Vector2i, radius: int, valid_only: bool = false, outer_only: bool = false) -> Array:
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

	# Only return cells that are in the map dictionary, OFF by default
	if valid_only:
		var to_delete = []
		for surrounding_cell in surrounding_cells:
			if not cell_dict.has(surrounding_cell):
				to_delete.append(surrounding_cell)
		for surrounding_cell in to_delete:
			surrounding_cells.erase(surrounding_cell)

	# Only return the outer-most radius ring
	if outer_only:
		for surrounding_cell in get_surrounding_cells_in_radius(cell, radius-1):
			surrounding_cells.erase(surrounding_cell)
	return surrounding_cells

static func get_edge_outline_around_cells(cells: Array, return_chain : bool= true) -> Array:
	var edge_counts = {}

	for cell_center in cells:
		var hex_points = get_vw_points_around_vw_point(map_to_vw_int(cell_center))
		for i in range(6):
			var vert : Vector2i = hex_points[i]
			var next_vert: Vector2i = hex_points[(i+1) % 6]
			if edge_counts.has([vert,next_vert]):
				edge_counts[[vert,next_vert]]+=1
			elif edge_counts.has([next_vert, vert]):
				edge_counts[[next_vert, vert]]+=1
			else:
				edge_counts[[vert,next_vert]]=1

	for edge in edge_counts.keys():
		if edge_counts[edge]>1:
			edge_counts.erase(edge)
	var final_edges = edge_counts.keys()

	var result = []
	if return_chain and not final_edges.is_empty():
		var chain = final_edges.pop_back()
		while not final_edges.is_empty():
			var found_next = false
			for edge in final_edges:
				if chain.back() in edge:
					for other_vert in edge:
						if other_vert!=chain.back():
							chain.append(other_vert)
							break
					final_edges.erase(edge)
					found_next = true
					break
			if not found_next:
				break
		for i in range(len(chain)):
			chain[i]=vw_to_local(chain[i])
		return chain

	for edge in final_edges:
		edge = [vw_to_local(edge[0]),vw_to_local(edge[1])]
		result.append(edge)
	return result

static func local_to_vw(pos: Vector2) -> Vector2:
	var w_units : float = pos.x/w.x
	var v_units : float = (pos.y-w.y*w_units)/v.y

	return Vector2(v_units, w_units)

static func vw_to_local(pos: Vector2) -> Vector2:
	return pos.x*v+pos.y*w

static func local_to_vw_int(pos: Vector2) -> Vector2i:
	var vw: Vector2 = local_to_vw(pos)
	return Vector2i(roundi(vw.x), roundi(vw.y))

static func map_to_vw_int(center: Vector2i)->Vector2i:
	return Vector2i(int(center.x-1.5*center.y+0.5*posmod(center.y,2)),int(2*center.x+posmod(center.y,2)))
static func vw_to_map_int(pos: Vector2i)->Vector2i:
	var x = floori(pos.y/2.)
	var y = int((x-pos.x+0.5*posmod(pos.y,2))*2/3)
	return Vector2i(x,y)
