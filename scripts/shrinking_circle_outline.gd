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
@export var guessing_timer : float = 0
@export var full_rad : int = 15
@export var guessing_prop : float = 0.4 
@export var guessing_rad:int = 1
@export var guess_speed_curve: Curve
@export var guessing_speedup_multiplier: float = 2.5
var random_center: Vector2i = Vector2i.ZERO
var guessing_accumulator : float = 0

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
	if shrinking_timer > 0:
		var ratio = delta/(timer_full_time*(1.-guessing_prop))
		shrinking_timer-=0.2*ratio+abs(randfn(0.8*ratio, ratio))
		
		if shrinking_timer<=0:
			guessing_timer = 1.+shrinking_timer
			guessing_accumulator = 0
			shrinking_timer=0
		else:
			var new_rad = int((full_rad-guessing_rad)*shrinking_timer)+guessing_rad
			if rad!=new_rad:
				rad = new_rad
	elif guessing_timer>0:
		var ratio : float = delta/(timer_full_time*guessing_prop)
		guessing_timer -= 0.2*ratio+abs(randfn(0.8*ratio, ratio))
		
		if guessing_timer <= 0:
			guessing_timer = 0
			guessing_accumulator = 0
			announce_final_choice()
		else:
			var temp = guessing_accumulator
			guessing_accumulator+=(full_rad-guessing_rad)*ratio*lerpf(1,guessing_speedup_multiplier,guess_speed_curve.sample(fmod(1-guessing_timer,1)))
			if int(guessing_accumulator)>int(temp):
				pick_random_center()
