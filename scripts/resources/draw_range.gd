extends Node2D

var cell: Vector2i
var radius_cells: Array = []

var drawn = false

var focus: Sprite2D

@export var animation_full_time_mean : float = 5.
var animation_timer: float = 0.
@onready var animation_full_time: float  = animation_full_time_mean

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
	
	clip_children=CanvasItem.CLIP_CHILDREN_AND_DRAW
	
	reparent(GridOutline.player_unique_instance.get_parent())
	reorder()
	
	focus = GridOutline.player_focus.duplicate()
	add_child(focus)
	
	focus.material.blend_mode = CanvasItemMaterial.BlendMode.BLEND_MODE_MUL
	
	
	var remote : RemoteTransform2D = focus.get_node("RemoteTransform2D")
	remote.reparent(player_parent.get_node("CollisionShape2D"))
	
	remote.position = Vector2()
	focus.global_position = remote.global_position
	
	remote.remote_path=remote.get_path_to(focus)
	focus.visible = true
	
	var texture : GradientTexture2D = focus.texture.duplicate()
	texture.width = HexCells.hex_width*(player_parent.radius*2+0.5)
	texture.height=texture.width
	focus.texture = texture
	
	"""
	# Multiply for enemies
	if player_parent.player_id!=multiplayer.get_unique_id():
		var material : CanvasItemMaterial = focus.material.duplicate()
		focus.material = material
		material.blend_mode=CanvasItemMaterial.BLEND_MODE_MUL
	"""

func _draw() -> void:
	var color: Color = Color.MAGENTA
	if player_parent.player_id!=multiplayer.get_unique_id():
		color = Color.TOMATO
	
	
	
	var thickness = GridOutline.player_unique_instance.grid_thickness
	for draw_point in radius_cells:
		var hex_points = HexCells.get_hex_points_around(draw_point)
		draw_polyline(hex_points, color, thickness, true if thickness>0 else false)
	
	var chain = HexCells.get_edge_outline_around_cells(radius_cells)
	var line: Line2D = Line2D.new()
	add_child(line)
	
	line.width=thickness
	line.default_color = color #Color.WHITE if color==Color.MAGENTA else Color.RED
	for i in range(len(chain)-1):
		line.add_point(chain[i])
	line.closed=true
	drawn = true

func _process(delta: float) -> void:
	animation_timer+=delta/animation_full_time
	if animation_timer>=1:
		animation_timer=fmod(animation_timer,1)
		animation_full_time=(abs(randfn(0.3,0.3))+0.7)*animation_full_time_mean
	
	#focus.self_modulate.a=lerpf(0.3,0.75, 0.5*cos(2*PI*animation_timer)+0.5)
