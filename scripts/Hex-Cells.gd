@tool
extends Path2D
class_name HexCells

const WATER_ORB_WIRE_SCENE := preload("res://scenes/magic_types/water_orb_wire.tscn")


@onready var text = $Coordinates
@onready var last_magic = $LastMagic

# Radius == side
@export var r: float = 60.:
	set(new_r):
		r = new_r
		recalculate()

@export var grid_thickness : float = 1:
	set(new_thickness):
		grid_thickness=new_thickness
		queue_redraw()

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
	
	# No need to redraw if using a constant r with fixed texture
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

@rpc("call_local","any_peer","reliable")
func launch_magic_in_cell(cell: Vector2i, wiggly_path_points: PackedVector2Array, player_id: int):
	for magic_instance in get_tree().get_nodes_in_group('magic'):
		if is_instance_valid(magic_instance) and magic_instance.player_id==player_id and magic_instance.self_cell == cell:
			magic_instance.start_rolling(wiggly_path_points)

@rpc("call_local", "any_peer", "reliable")
func try_create_water_orb_wire_for_player(player_id: int) -> void:
	if not multiplayer.is_server():
		return

	# A client may request only its own wire. Calls made locally by the host have
	# sender ID 0, so those are also accepted.
	var sender_id: int = multiplayer.get_remote_sender_id()
	if sender_id != 0 and sender_id != player_id:
		push_warning("Rejected Water Orb wire request for another player.")
		return

	var player_owner := _find_player_by_id(player_id)
	if player_owner == null or player_owner.preset == null:
		return

	var passive_stats = player_owner.preset.magics.get(Magic.MagicType.PASSIVE)
	if passive_stats == null:
		return

	var variant: int
	match passive_stats.magic_name:
		"Razor Current":
			variant = 1
		"Flow Circuit":
			variant = 2
		_:
			# Q remains the normal Passive transform key for every other character.
			return

	var owned_orbs: Array[MagicTidebladeOrb] = []
	for node in get_tree().get_nodes_in_group("tideblade_orb"):
		if not (node is MagicTidebladeOrb):
			continue

		var orb := node as MagicTidebladeOrb
		if orb.player_id != player_id:
			continue
		if orb.creation_sequence < 0 or orb.attacks_remaining <= 0:
			continue
		if orb.is_queued_for_deletion():
			continue

		owned_orbs.append(orb)

	if owned_orbs.size() < 2:
		print("[WATER ORB] Q requires at least two surviving Tideblade Orbs.")
		return

	owned_orbs.sort_custom(
		func(first: MagicTidebladeOrb, second: MagicTidebladeOrb) -> bool:
			return first.creation_sequence < second.creation_sequence
	)

	var endpoint_a: MagicTidebladeOrb = owned_orbs[owned_orbs.size() - 2]
	var endpoint_b: MagicTidebladeOrb = owned_orbs[owned_orbs.size() - 1]

	# Re-pressing Q with no newer endpoints should not waste mana.
	if _water_orb_wire_matches_pair(player_id, endpoint_a.self_cell, endpoint_b.self_cell):
		return

	var hex_length: int = _water_orb_hex_distance(endpoint_a.self_cell, endpoint_b.self_cell)
	var connection_cost: float = 5.0 + 2.0 * float(hex_length)

	if player_owner.stats_update.current_mana < connection_cost:
		print(
			"[WATER ORB] Not enough mana to connect Tideblades. Need ",
			connection_cost,
			" mana."
		)
		return

	# The existing line is replaced only after Q succeeds and the cost is paid.
	player_owner._use_mana.rpc(connection_cost)
	set_water_orb_wire_for_player.rpc(
		player_id, endpoint_a.self_cell, endpoint_b.self_cell, variant
	)


func _find_player_by_id(player_id: int) -> Player:
	var players_node := get_tree().current_scene.find_child("Players")
	if players_node == null:
		return null

	for child in players_node.get_children():
		if child is Player and (child as Player).player_id == player_id:
			return child as Player

	return null


func _water_orb_wire_matches_pair(
	player_id: int, endpoint_a_cell: Vector2i, endpoint_b_cell: Vector2i
) -> bool:
	for node in get_tree().get_nodes_in_group("water_orb_wire"):
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if int(node.get("player_id")) != player_id:
			continue

		var current_a: Vector2i = node.get("endpoint_a_cell")
		var current_b: Vector2i = node.get("endpoint_b_cell")
		return (
			(current_a == endpoint_a_cell and current_b == endpoint_b_cell)
			or (current_a == endpoint_b_cell and current_b == endpoint_a_cell)
		)

	return false


func _water_orb_hex_distance(first: Vector2i, second: Vector2i) -> int:
	# Convert this project's odd-row offset coordinates to axial coordinates.
	var first_q: int = first.x - int((first.y - posmod(first.y, 2)) / 2)
	var second_q: int = second.x - int((second.y - posmod(second.y, 2)) / 2)
	var delta_q: int = first_q - second_q
	var delta_r: int = first.y - second.y
	return int((absi(delta_q) + absi(delta_r) + absi(delta_q + delta_r)) / 2)


@rpc("call_local", "authority", "reliable")
func set_water_orb_wire_for_player(
	player_id: int,
	endpoint_a_cell: Vector2i,
	endpoint_b_cell: Vector2i,
	variant: int
) -> void:
	_clear_water_orb_wire_local(player_id)

	var endpoint_a := _find_tideblade_endpoint(player_id, endpoint_a_cell)
	var endpoint_b := _find_tideblade_endpoint(player_id, endpoint_b_cell)
	if endpoint_a == null or endpoint_b == null:
		push_warning(
			"Could not create Water Orb wire because an endpoint was missing."
		)
		return

	var wire := WATER_ORB_WIRE_SCENE.instantiate()
	get_tree().current_scene.add_child(wire, true)
	wire.call("configure", endpoint_a, endpoint_b, player_id, variant)


@rpc("call_local", "authority", "reliable")
func clear_water_orb_wire_for_player(player_id: int) -> void:
	_clear_water_orb_wire_local(player_id)


func _clear_water_orb_wire_local(player_id: int) -> void:
	for node in get_tree().get_nodes_in_group("water_orb_wire"):
		if not is_instance_valid(node):
			continue
		if int(node.get("player_id")) != player_id:
			continue
		node.queue_free()


func _find_tideblade_endpoint(player_id: int, cell: Vector2i) -> Magic:
	for node in get_tree().get_nodes_in_group("tideblade_orb"):
		if not (node is Magic):
			continue
		var magic := node as Magic
		if magic.player_id != player_id or magic.self_cell != cell:
			continue
		if magic.is_queued_for_deletion():
			continue
		return magic

	return null

func _draw() -> void:
	if points.is_empty():
		return
	
	"""
	# Save grid image as texture
	var grid_image : Image = Image.create(width,height,false,Image.FORMAT_RGBA8)
	for hex_points in points:
		for i in range(len(hex_points)-1):
			var prev: Vector2 = hex_points[i]
			var next: Vector2 = hex_points[i+1]
			
			var x_diff = floori(abs(prev.x-next.x))
			var y_diff = floori(abs(prev.y-next.y))
			for x in range(x_diff+1):
				var x_pos : float = min(prev.x,next.x)+x
				var y_pos = lerpf(prev.y,next.y,(x_pos-prev.x)/(next.x-prev.x))
				for x_posi in [floori(x_pos),ceili(x_pos)]:
					var final_x : int = roundi(width/2+x_posi)
					if final_x<0 or final_x>=width:
						continue
					for y_posi in [floori(y_pos),ceili(y_pos)]:
						var final_y : int = roundi(height/2+y_posi)
						if final_y<0 or final_y>=height:
							continue
						grid_image.set_pixel(final_x,final_y,Color.CYAN)
			
			for y in range(y_diff+1):
				var y_pos : float = min(prev.y, next.y)+y
				var x_pos = lerpf(prev.x,next.x,(y_pos-prev.y)/(next.y-prev.y))
				for x_posi in [floori(x_pos),ceili(x_pos)]:
					var final_x : int = roundi(width/2+x_posi)
					if final_x<0 or final_x>=width:
						continue
					for y_posi in [floori(y_pos),ceili(y_pos)]:
						var final_y : int = roundi(height/2+y_posi)
						if final_y<0 or final_y>=height:
							continue
						grid_image.set_pixel(final_x,final_y,Color.CYAN)
	
	# get_node("GridSprite").texture = ImageTexture.create_from_image(grid_image)
	# Disable in export
	grid_image.save_png("res://assets/textures/grid.png")
	"""
	
	
	for hex_points in points:
		draw_polyline(hex_points,Color.CYAN, grid_thickness, true)
	
	
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
