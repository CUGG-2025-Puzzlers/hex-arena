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
			temp[2]=lerp(corner[1],corner[2],corner_fill_ratio)
			# Uneven overlapping lines
			draw_polyline(temp,Color.WHITE,thickness, thickness>0)
			# Smoother gradient
			#draw_polyline_colors([corner[0],temp[0],corner[1],temp[2],corner[2]],
			#[Color.BLACK,Color.WHITE,Color.WHITE,Color.WHITE,Color.BLACK],thickness,thickness>0)

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
