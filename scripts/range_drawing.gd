extends Node2D

var cell: Vector2i
var radius_cells: Array = []

var drawn = false

@onready var player_parent : CharacterBody2D = get_parent()
func _ready() -> void:
	player_parent.changed_cell.connect(move_cell)
	player_parent.tree_exiting.connect(queue_free)

func move_cell(_player_ind:int, new_cell: Vector2i):
	if not drawn:
		return
	
	cell=new_cell
	global_position=HexCells.map_to_local(cell)
	
	# Comment out if it becomes too much with > 2 players
	reorder()

func reorder():
	if player_parent.player_id!=multiplayer.get_unique_id() \
	and get_parent().get_child_count()>1:
		get_parent().move_child(self,-2)

func draw_range(new_rad_cells):
	global_position = Vector2.ZERO
	radius_cells = new_rad_cells 
	queue_redraw()
	reparent(GridOutline.player_unique_instance)
	reorder()


func _draw() -> void:
	var color: Color = Color.MAGENTA
	if player_parent.player_id!=multiplayer.get_unique_id():
		color = Color.TOMATO
	for draw_point in radius_cells:
		var hex_points = HexCells.player_unique_instance.get_hex_points_around(draw_point)
		var thickness = GridOutline.player_unique_instance.grid_thickness
		draw_polyline(hex_points, color, thickness, true if thickness>0 else false)
	drawn = true
