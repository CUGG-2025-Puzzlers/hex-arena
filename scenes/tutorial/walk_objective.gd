extends Area2D

signal completed

@onready var player_id : int = multiplayer.get_unique_id()

@onready var sprite: Sprite2D = $Sprite2D
@onready var glow_sprite: Sprite2D = $Glow
@onready var particles: CPUParticles2D = $Sparkles
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	print("[WALK OBJECTIVE] spawned")
	
func _on_area_entered(area: Area2D) -> void:
	print("[WALK OBJECTIVE] touched by area=", area.name)

	var player := _find_player_node(area)

	if player == null:
		print("[WALK OBJECTIVE] not a player")
		return

	var entered_player_id = player.get("player_id")

	if entered_player_id != null and int(entered_player_id) == player_id:
		print("[WALK OBJECTIVE] objective complete")
		_complete_objective()

func _find_player_node(node: Node) -> Node:
	var current := node

	while current != null:
		if current.is_in_group("player"):
			return current

		current = current.get_parent()

	return null


func _complete_objective() -> void:
	print("[WALK OBJECTIVE] objective complete")

	# Disable collision so it cannot complete twice.
	collision_shape.set_deferred("disabled", true)
	monitoring = false
	monitorable = false

	_play_complete_vfx()

	completed.emit()


func _play_complete_vfx() -> void:
	glow_sprite.visible = true
	glow_sprite.modulate.a = 0.0
	glow_sprite.scale = Vector2.ONE * 1.0
	
	particles.modulate.a = 0.0
	particles.visible = true
	particles.restart()

	var tween := create_tween()
	tween.set_parallel(true)

	# Main sprite fades out.
	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)

	# Glow expands and fades.
	tween.tween_property(glow_sprite, "modulate:a", 0.6, 0.12)
	tween.tween_property(glow_sprite, "scale", Vector2.ONE * 1.8, 0.35)

	tween.tween_property(particles, "modulate:a", 0.6, 0.12)

	tween.chain()
	tween.tween_property(glow_sprite, "modulate:a", 0.0, 0.25)
	tween.tween_property(particles, "modulate:a", 0.0, 0.12)

	tween.finished.connect(queue_free)
