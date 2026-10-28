@tool
extends Node2D
class_name GridOutline

var hex_centers = []
var hex_outlines = []
var max_dist : float = 2000.

static var player_unique_instance: GridOutline
static var player_focus:Sprite2D
static var magic_focus: Sprite2D

@export var grid_thickness : float = 1:
	set(new_thickness):
		grid_thickness=new_thickness
		queue_redraw()

"""
@export var grid_gradient : GradientTexture1D:
	set(new_value):
		grid_gradient=new_value
		queue_redraw()

@export var gradient_dist_curve : Curve:
	set(new_value):
		gradient_dist_curve=new_value
		queue_redraw()
"""

@export var animation_full_time_mean: float = 5.
@onready var animation_full_time : float = animation_full_time_mean
var animation_timer : float = 0.

signal redrawn

func _ready() -> void:
	player_unique_instance=self
	
	#clip_children=CanvasItem.CLIP_CHILDREN_DISABLED
	player_focus = get_node("PlayerFocus")
	player_focus.visible = false
	
	magic_focus = get_node("MagicFocus")
	magic_focus.visible=false

func recalculate():
	max_dist = sqrt(HexCells.player_unique_instance.width**2+HexCells.player_unique_instance.height**2)
	
	hex_centers = HexCells.cell_dict.keys()
	
	hex_outlines = []
	for center in hex_centers:
		var hex_points = HexCells.get_hex_points_around(center)
		hex_outlines.append(hex_points)
	
	queue_redraw()

func _draw() -> void:
	if hex_outlines.is_empty():
		return
	
	
	#var color : Color = Color.from_hsv(randf(),randf_range(0.6,1),randf_range(0.1,0.3),1)
	# Just draw the grid in white
	for hex_outline in hex_outlines:
		draw_polyline(hex_outline, Color.WHITE, grid_thickness, grid_thickness>0)
	
	
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
	
	
	"""
	# Dynamic player-distance coloring
	var player_cell_centers : PackedVector2Array
	
	for mult_id in HexCells.players_cells.keys():
		player_cell_centers.append(HexCells.map_to_local(HexCells.players_cells[mult_id]))
	if player_cell_centers.is_empty():
		player_cell_centers.append(Vector2())
	
	for i0 in range(len(hex_centers)):
		var hex_center : Vector2 = HexCells.map_to_local(hex_centers[i0])
		
		var center = player_cell_centers[0]
		var dist: float = center.distance_to(hex_center) 
		for i in range(len(player_cell_centers)-1):
			var other_center = player_cell_centers[i+1]
			var new_dist : float = other_center.distance_to(hex_center)
			if new_dist<dist:
				dist=new_dist
				center = other_center
		
		var ratio : float = dist*1./max_dist
		#ratio = gradient_dist_curve.sample(ratio)
		var color : Color = grid_gradient.gradient.sample(ratio)
		draw_polyline(hex_outlines[i0], color, grid_thickness, grid_thickness>0)
	"""
	
	"""
	var hex_points = get_hex_points_around(curr_cell)
	draw_polyline(hex_points,Color.MAGENTA)
	
	for cell in get_surrounding_cells_in_radius(curr_cell,2):
		hex_points = get_hex_points_around(cell)
		draw_polyline(hex_points, Color.MAGENTA)
	"""
	
	redrawn.emit()

func _process(delta: float) -> void:
	animation_timer+=delta/animation_full_time
	if animation_timer>=1:
		animation_timer=fmod(animation_timer,1)
		animation_full_time=(abs(randfn(0.2,0.2))+0.8)*animation_full_time_mean
	
	#self_modulate.v=lerpf(0.35,0.5,0.5*cos(2*PI*animation_timer)+0.5)
