extends Area2D

signal completed

enum ObjectiveState {
	INACTIVE,
	WAITING_FOR_LIGHT,
	COMPLETE,
}

@onready var player_id: int = multiplayer.get_unique_id()

@onready var sprite: Sprite2D = $Sprite2D
@onready var glow_sprite: Sprite2D = $Glow
@onready var particles: CPUParticles2D = $Sparkles
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var objective_state := ObjectiveState.INACTIVE


func _ready() -> void:
	visible = false
	monitoring = false
	monitorable = false
	collision_shape.set_deferred("disabled", true)

	print("[LIGHT OBJECTIVE] spawned")


func activate() -> void:
	objective_state = ObjectiveState.WAITING_FOR_LIGHT

	visible = true
	monitoring = true
	monitorable = true
	collision_shape.set_deferred("disabled", false)

	sprite.modulate.a = 1.0
	glow_sprite.visible = false
	particles.visible = false

	print("[LIGHT OBJECTIVE] activated")


func _on_area_entered(area: Area2D) -> void:
	if objective_state != ObjectiveState.WAITING_FOR_LIGHT:
		return

	print("[LIGHT OBJECTIVE] touched by area=", area.name)

	if not area.is_in_group("magic"):
		return

	var magic := area as Magic
	if magic == null:
		return

	if magic.player_id != player_id:
		return

	if magic.state != Magic.MagicType.LIGHT:
		return

	_complete_objective()


func _complete_objective() -> void:
	if objective_state == ObjectiveState.COMPLETE:
		return

	objective_state = ObjectiveState.COMPLETE

	print("[LIGHT OBJECTIVE] hit by Light magic.")

	collision_shape.set_deferred("disabled", true)
	monitoring = false
	monitorable = false

	completed.emit()
	_play_complete_vfx()


func _play_complete_vfx() -> void:
	glow_sprite.visible = true
	glow_sprite.modulate.a = 0.0
	glow_sprite.scale = Vector2.ONE

	particles.visible = true
	particles.modulate.a = 1.0
	particles.restart()

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(sprite, "modulate:a", 0.0, 0.35)

	tween.tween_property(glow_sprite, "modulate:a", 0.8, 0.12)
	tween.tween_property(glow_sprite, "scale", Vector2.ONE * 1.8, 0.35)

	tween.chain()
	tween.tween_property(glow_sprite, "modulate:a", 0.0, 0.25)
	tween.tween_property(particles, "modulate:a", 0.0, 0.25)

	tween.finished.connect(queue_free)
