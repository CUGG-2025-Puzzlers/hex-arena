extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD

func _ready() -> void:
	# attach hud to player
	hud.connect_to_player(player)

func _unhandled_input(event: InputEvent) -> void:
	# take 10 dmg when press K
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_K:
			player.stats.take_damage(10.0)
			print("Took 10 damage. HP: %d" % player.stats.current_health)
		elif event.keycode == KEY_L:
			player.stats.heal(10.0)
			print("Healed 10. HP: %d" % player.stats.current_health)
		elif event.keycode == KEY_M:
			player.stats.use_mana(20.0)
			print("Used 20 mana. Mana: %d" % player.stats.current_mana)
