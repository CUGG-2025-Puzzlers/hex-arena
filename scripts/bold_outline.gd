#@tool
extends Line2D

@export var animation_full_time_mean : float = 10.
@onready var animation_timer: float = randf()
@onready var animation_full_time: float  = animation_full_time_mean

@onready var outline_gradient : GradientTexture2D

var chain = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	outline_gradient=texture.duplicate()
	texture=outline_gradient

func recalculate(cells: Array):
	chain = HexCells.get_edge_outline_around_cells(cells)
	
	clear_points()
	for i in range(len(chain)-1):
		add_point(chain[i])

func _process(delta: float) -> void:
	animation_timer+=delta/animation_full_time
	if animation_timer>=1:
		animation_timer=fmod(animation_timer,1)
		animation_full_time=(abs(randfn(0.3,0.3))+0.7)*animation_full_time_mean
	
	outline_gradient.fill_to=0.5*Vector2.ONE+0.4*Vector2.RIGHT.rotated(animation_timer*2*PI)
