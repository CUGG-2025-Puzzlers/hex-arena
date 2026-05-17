@tool
extends GridOutline

@export var rad : int = 1:
	set (new_rad):
		rad = new_rad
		if new_rad>=guessing_rad:
			recalculate_rad()
		else:
			pick_random_center()
@export var center: Vector2i = Vector2i.ZERO:
	set (new_val):
		center=new_val
		recalculate_rad()
@export var timer_full_time : float = 12
@export var shrinking_timer : float = 0
@export var full_rad : int = 15
@export var guessing_prop : float = 0.4 
@export var guessing_rad:int = 1
@export var guess_speed_curve: Curve
@export var guess_curve_frame_chance_multiplier: float = 0.1
var random_center: Vector2i = Vector2i.ZERO

func _ready() -> void:
	center = HexCells.map_to_local(global_position)
	random_center = center
	

func recalculate_rad():
	hex_centers = HexCells.get_surrounding_cells_in_radius(center, rad, true, true)
	hex_outlines = []
	for hex_center in hex_centers:
		hex_outlines.append(HexCells.get_hex_points_around(hex_center))
	queue_redraw()

func pick_random_center():
	if not hex_centers.is_empty():
		hex_centers.shuffle()
		random_center=hex_centers.pop_back()
	else:
		hex_centers=HexCells.get_surrounding_cells_in_radius(center, guessing_rad, true)
	hex_outlines=[HexCells.get_hex_points_around(random_center)]
	queue_redraw()

func announce_final_choice():
	if multiplayer.is_server():
		print("spawn at", random_center)
		hex_outlines = []
		queue_redraw()

func _process(delta: float) -> void:
	if shrinking_timer >0:
		shrinking_timer-=0.2*delta/timer_full_time+abs(randfn(0.8*delta/timer_full_time, delta/timer_full_time))
	if shrinking_timer<0:
		shrinking_timer=0
		announce_final_choice()
	if shrinking_timer == 0:
		return
	var new_rad = int(full_rad*shrinking_timer)+guessing_rad-int(full_rad*guessing_prop)
	if rad!=new_rad or shrinking_timer>0 and new_rad<=0 and randf()<guess_curve_frame_chance_multiplier*(shrinking_timer/guessing_prop)*guess_speed_curve.sample(shrinking_timer/guessing_prop):
		rad = new_rad
