extends Area2D

signal completed(magic:Magic)

@onready var player_id : int = multiplayer.get_unique_id()

@onready var sprite: Sprite2D = $Sprite2D
@onready var glow_sprite: Sprite2D = $Glow
@onready var particles: CPUParticles2D = $Sparkles
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	visible = false
	monitoring = false
	monitorable = false

	print("[PLACE MAGIC OBJECTIVE] spawned")
	
func _on_area_entered(area: Area2D) -> void:
	print("[PLACE MAGIC OBJECTIVE] touched by area=", area.name)
	
	if not area.is_in_group("magic"):
		return
		
	var magic := area as Magic
	if magic == null:
		return

	if magic.state==Magic.MagicType.NEUTRAL:
		_complete_objective(magic)

func activate():
	visible = true
	monitoring = true
	monitorable = true

func _complete_objective(magic: Magic) -> void:
	print("[PLACE MAGIC] objective complete")

	# Disable collision so it cannot complete twice.
	collision_shape.set_deferred("disabled", true)
	monitoring = false
	monitorable = false

	_play_complete_vfx()

	completed.emit(magic)


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
