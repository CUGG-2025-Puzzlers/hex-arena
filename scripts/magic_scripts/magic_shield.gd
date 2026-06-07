extends Magic
class_name MagicShield

@onready var shield_animated_texture : GradientTexture2D = $"Shield Pattern/Shield Glow".texture.duplicate()
@onready var coll_shape : CollisionShape2D = $CollisionShape
@onready var shield_static_body : StaticBody2D = $ShieldBody

@export var lifetime : float = 5

var glow_tween : Tween

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visualize_shield()
	recalculate_coll_shape()
	create_and_start_glow()
	
	if HexCells.player_unique_instance:
		start_lifetime_timer(lifetime)

func start_lifetime_timer(time: float):
	var timer : Timer = Timer.new()
	timer.one_shot = true
	timer.autostart = true
	
	timer.timeout.connect(fizzle)
	
	timer.wait_time = time
	add_child(timer)

func recalculate_coll_shape():
	coll_shape.shape = HexCells.hex_polygon_shape
	get_node("ShieldBody").add_child(coll_shape.duplicate())

func create_and_start_glow():
	var start_point = randf()
	
	glow_tween = create_tween().set_loops()
	
	glow_tween.tween_method(
		func(prog: float):
			prog = 0.5 * (cos(2 * PI * prog) + 1)
			shield_animated_texture.fill_to = Vector2.ONE * lerpf(0.6, 0.8, prog) * sqrt(2)
	, start_point, start_point+[-1.,1.].pick_random(), 5)

func visualize_shield():
	find_child("Shield Glow").texture = shield_animated_texture
	
	if player_id!=multiplayer.get_unique_id():
		var pattern: Polygon2D = find_child("Shield Pattern")
		var glow: Polygon2D = find_child("Shield Glow")
		
		var temp = pattern.texture
		pattern.texture = glow.texture
		glow.texture=temp
	
	var bounding_box: Rect2 = Rect2()
	bounding_box.position = Vector2(HexCells.hex_shape[5].x,HexCells.hex_shape[0].y)
	bounding_box.size = abs(bounding_box.position)*2
	
	for polygon in find_children("Shield*", "Polygon2D"):
		polygon.polygon = HexCells.hex_shape
		
		var scale_vec : Vector2 = polygon.texture.get_size()/bounding_box.size
		polygon.texture_scale = Vector2.ONE*max(scale_vec.x,scale_vec.y)
		polygon.texture_scale*=2
