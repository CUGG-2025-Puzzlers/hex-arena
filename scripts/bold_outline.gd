#@tool
extends Line2D

@export var animation_full_time_mean : float = 10. # 7. # for corners only 
@onready var animation_timer: float = randf()
@onready var animation_full_time: float  = animation_full_time_mean

@onready var outline_gradient : GradientTexture2D

@export var colors : Dictionary = {
	"orange": Color.TOMATO,
	"purple": Color.BLUE_VIOLET, #Color.DARK_ORCHID, #Color.VIOLET, 
	"pink":  Color.MEDIUM_VIOLET_RED,
	"yellow": Color.DARK_GOLDENROD,
	"lilac": Color.DARK_SLATE_BLUE,
	"gray": Color.DARK_GRAY
}
@export var corners_only : bool = false
@export var corner_fill_mean_ratio : float = 0.6:
	set(new_val):
		corner_fill_mean_ratio = new_val
		queue_redraw()
@export var corner_fill_ratio_deviation : float = 0.2
var corner_fill_ratio : float = corner_fill_mean_ratio
var chain = []
var corners = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	outline_gradient=texture.duplicate()
	texture=outline_gradient

func recalculate(cells: Array):
	clear_points()
	if corners_only:
		corners = HexCells.get_edge_outline_around_cells(cells,true,true)
		
		"""
		# For breaking up into smaller corners
		var max_corner_len=3
		var smaller_corners = []
		for i in range(len(corners)):
			var corner = [corners[i][0]]
			for j in range(1, len(corners[i])-1):
				if len(corner)<max_corner_len:
					corner.append(corners[i][j])
				if len(corner)==max_corner_len:
					smaller_corners.append(corner.duplicate())
					corner = [corners[i][j-1],corners[i][j]]
			corner.append(corners[i].back())
			smaller_corners.append(corner.duplicate())
		corners = smaller_corners
		"""
	else:
		chain = HexCells.get_edge_outline_around_cells(cells)
		for i in range(len(chain)-1):
			add_point(chain[i])

func _draw() -> void:
	if corners_only:
		var thickness = GridOutline.player_unique_instance.grid_thickness
		for corner in corners:
			var temp = corner.duplicate()
			temp[0]=lerp(corner[1],corner[0],corner_fill_ratio)
			temp[len(temp)-1]=lerp(corner[len(corner)-2],corner[len(corner)-1],corner_fill_ratio)
			# Disjoint lines
			draw_polyline(temp,Color.WHITE,thickness, thickness>0)
			# Smoother gradient
			#temp.append(corner.back())
			#corner = [corner[0]]
			#corner.append_array(temp)
			#var color_arr = corner.duplicate()
			#for i in range(1, len(color_arr)-1):
			#	color_arr[i] = Color.WHITE
			#color_arr[0]=Color.BLACK
			#color_arr[len(color_arr)-1]=Color.BLACK
			#draw_polyline_colors(corner,color_arr,thickness,thickness>0)

func _process(delta: float) -> void:
	animation_timer+=delta/animation_full_time
	if animation_timer>=1:
		animation_timer=fmod(animation_timer,1)
		animation_full_time=(abs(randfn(0.3,0.3))+0.7)*animation_full_time_mean
	
	if corners_only:
		corner_fill_ratio = corner_fill_mean_ratio + corner_fill_ratio_deviation*sin(animation_timer*2*PI)
		queue_redraw()
	else:
		outline_gradient.fill_to=0.5*Vector2.ONE+0.4*Vector2.RIGHT.rotated(animation_timer*2*PI)
