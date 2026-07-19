extends Sprite2D

@export var appear_over_time : float = 6
var own_timer : float = 0
var selected_cell : Vector2i
var new_selected_cell: Vector2i
var own_cell : Vector2i

#@onready var original_scale : Vector2 = scale

func _ready() -> void:
	Events.select_new_cell.connect(select_new_cell)

func select_new_cell(cell: Vector2i):
	new_selected_cell = cell
	if own_timer<=1:
		selected_cell=new_selected_cell

func reset_timer(cell: Vector2i):
	own_timer = 0.
	own_cell = cell
	selected_cell=new_selected_cell

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if new_selected_cell==selected_cell:
		own_timer+=delta/appear_over_time
	else:
		own_timer+=delta/appear_over_time*5
	if own_timer>=3:
		own_timer = fmod(own_timer, 2)
		selected_cell=new_selected_cell
	
	
	if own_timer>=1:
		var prog = 1-abs(own_timer-2)
		self_modulate.a=1-prog
		
		#var full_dist : float = HexCells.map_to_local(selected_cell).distance_to(global_position)
		#global_scale.y=lerpf(1,full_dist/texture.get_height(),prog)
		#global_rotation=Vector2.UP.angle_to(HexCells.map_to_local(selected_cell)-global_position)
		#Skewed shadow effect
		#global_position = lerp(HexCells.map_to_local(own_cell),lerp(HexCells.map_to_local(selected_cell),HexCells.map_to_local(own_cell),0.5),prog)
		#Sped-up cursor following effect
		#global_position = lerp(global_position,lerp(HexCells.map_to_local(selected_cell),global_position,0.5),prog)
	else:
		self_modulate.a = 1
		
		#scale=Vector2.ONE*1.641
		#global_position = HexCells.map_to_local(own_cell)
