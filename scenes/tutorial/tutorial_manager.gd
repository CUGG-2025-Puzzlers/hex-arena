extends Node2D

@onready var walk_objective: Area2D = $"Walk Objective"
@onready var place_magic_objective: Area2D = $"Place Magic Objective"

var target_magic: Magic

func _ready() -> void:
	walk_objective.completed.connect(_on_walk_objective_completed)
	place_magic_objective.completed.connect(_on_place_magic_objective_completed)

func _on_walk_objective_completed() -> void:
	print("[TUTORIAL] Walk objective completed. Showing place magic objective.")
		
	place_magic_objective.activate()

# get the basic magic that was placed at LastMagic's position or the last placed basic magic, and wait for some signal that it has been transformed
# when this function gets that signal, it prints a log (for now)
func _on_place_magic_objective_completed(magic: Magic) -> void:
	target_magic = magic
	target_magic.state_changed.connect(_on_target_magic_state_changed)
	
func _on_target_magic_state_changed(magic: Magic, state: Magic.MagicType, new_state: Magic.MagicType) -> void:
	if magic != target_magic:
		return

	if state == Magic.MagicType.NEUTRAL and new_state == Magic.MagicType.LIGHT:
		print("[TUTORIAL] Basic magic changed into Light magic.")
	elif state == Magic.MagicType.NEUTRAL and new_state == Magic.MagicType.SHIELD:
		print("Shields are good for blocking, but we want to practice making light magic.")
		print("It'll fizzle out in a few seconds, then we can try again.")
		# After fizzle + 2s
		print("Place basic magic again, then press 'E' to transform it into light magic" )
	elif state == Magic.MagicType.NEUTRAL and new_state == Magic.MagicType.HEAVY:
		print("That's heavy magic..")
		print("Press space to shoot it away, then we can try again.")
		# After firing
		print("Place basic magic again, then press 'E' to transform it into light magic")
