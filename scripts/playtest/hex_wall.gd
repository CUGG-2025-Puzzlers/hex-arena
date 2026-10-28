extends StaticBody2D
class_name HexWall

## Permanent terrain occupies the same cell registry as placed magic.
var cell: Vector2i

func _ready() -> void:
	position = HexCells.map_to_local(cell)
	collision_layer = 1
	z_index = 3
	var collider := CollisionShape2D.new()
	collider.shape = HexCells.hex_polygon_shape
	add_child(collider)
	queue_redraw()

func _draw() -> void:
	draw_colored_polygon(HexCells.hex_polygon_shape.points, Color("253849"))
	draw_polyline(PackedVector2Array(HexCells.hex_shape), Color("93aabe"), 3.0, true)

func _exit_tree() -> void:
	if HexCells.cell_dict.get(cell) == self:
		HexCells.cell_dict[cell] = null
	if HexCells.wall_cells.get(cell) == self:
		HexCells.wall_cells.erase(cell)
