@tool
extends Path2D
class_name HexCells


@onready var text = get_node("Label")
# Radius == side
@export var r: float = 80.:
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
			queue_redraw()
		
		text.position = get_global_mouse_position()+Vector2(25,-5)
		
	if Input.is_action_pressed("place_magic"):
		if cell_dict.has(curr_cell) and \
		not is_instance_valid(cell_dict[curr_cell]):
			var magic_instance = preload("res://scenes/magic.tscn").instantiate()
			magic_instance.position = map_to_local(curr_cell)
			magic_instance.self_cell = curr_cell
			cell_dict[curr_cell]=magic_instance
			add_child(magic_instance)
			magic_instance.add_to_group('magic')
			Magic.last_placed_cell=curr_cell

func _draw() -> void:
	if points.is_empty():
		return
	
	for hex_points in points:
		draw_polyline(hex_points,Color.CYAN)
	
	var hex_points = get_hex_points_around(curr_cell)
	draw_polyline(hex_points,Color.MAGENTA)

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
