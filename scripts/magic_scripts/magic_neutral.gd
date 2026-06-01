extends Magic
class_name MagicNeutral


@onready var animated_sprites : Array[Sprite2D] = [$MainSprite, $MainSprite/ChildLight1]

@export var animation_cycles: Array[float] = [PI, 3.]
@export var dists: Array[Vector2] = [Vector2.UP*6, Vector2.RIGHT*20.]

var tweens : Array[Tween] = []


func _ready() -> void:
	
	create_and_start_animation()

func cycle_complete(iteration: int):
	pass
	#print('neutral in cell ',self_cell,' finished cycle ', iteration)

# Bobbing up and down and circling child light animation as looping tweens
func create_and_start_animation():
	#animated_children.append_array(parent_light.find_children("*Light*", "Sprite2D"))
	
	var bobbing = create_tween().set_loops()
	bobbing.tween_method(
		func(prog: float):
			animated_sprites[0].position = dists[0] * sin(prog*2*PI),
		0., 1., animation_cycles[0]
	)
	tweens.append(bobbing)
	
	for i in range(1, len(animated_sprites)):
		var animated_child :Sprite2D = animated_sprites[i]
		
		var circling = create_tween().set_loops()
		circling.tween_method(
			func(angle: float):
				animated_child.position = dists[i].rotated(angle),
			0., 2 * PI, animation_cycles[i])
		
		if i == 1:
			circling.loop_finished.connect(cycle_complete)
		
		tweens.append(circling)
	
