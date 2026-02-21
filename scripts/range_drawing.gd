extends Node2D

var cell: Vector2i
var radius_cells: Array = []

var drawn = false

func draw_range(new_rad_cells):
	global_position = Vector2.ZERO
	radius_cells = new_rad_cells 
	queue_redraw()

func _process(_delta: float) -> void:
	cell = get_parent().cell
	if drawn:
		global_position=HexCells.map_to_local(cell)

func _draw() -> void:
	var color: Color = Color.MAGENTA
	if get_parent().player_id!=multiplayer.get_unique_id():
		color = Color.TOMATO
	for draw_point in radius_cells:
		var hex_points = HexCells.player_unique_instance.get_hex_points_around(draw_point)
		draw_polyline(hex_points,color)
	drawn = true
