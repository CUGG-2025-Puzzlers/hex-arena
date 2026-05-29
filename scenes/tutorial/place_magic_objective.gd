extends Area2D

signal completed

enum ObjectiveState {
	INACTIVE,
	WAITING_FOR_PLACE,
	WAITING_FOR_TRANSFORM,
	COMPLETE,
}

@export var required_transform: Magic.MagicType = Magic.MagicType.LIGHT

@onready var player_id: int = multiplayer.get_unique_id()

@onready var sprite: Sprite2D = $Sprite2D
@onready var glow_sprite: Sprite2D = $Glow
@onready var particles: CPUParticles2D = $Sparkles
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var objective_state := ObjectiveState.INACTIVE
var target_magic: Magic


func _ready() -> void:
	visible = false
	monitoring = false
	monitorable = false
	collision_shape.set_deferred("disabled", true)

	print("[PLACE MAGIC OBJECTIVE] spawned")


func activate() -> void:
	objective_state = ObjectiveState.WAITING_FOR_PLACE

	visible = true
	monitoring = true
	monitorable = true
	collision_shape.set_deferred("disabled", false)

	sprite.modulate.a = 1.0
	glow_sprite.visible = false
	particles.visible = false

	print("[PLACE MAGIC OBJECTIVE] activated")


func _on_area_entered(area: Area2D) -> void:
	if objective_state != ObjectiveState.WAITING_FOR_PLACE:
		return

	print("[PLACE MAGIC OBJECTIVE] touched by area=", area.name)

	if not area.is_in_group("magic"):
		return

	var magic := area as Magic
	if magic == null:
		return

	if magic.player_id != player_id:
		return

	if magic.state != Magic.MagicType.NEUTRAL:
		return

	_on_basic_magic_placed(magic)


func _on_basic_magic_placed(magic: Magic) -> void:
	print("[PLACE MAGIC OBJECTIVE] Basic magic placed. Waiting for Light transform.")

	target_magic = magic
	objective_state = ObjectiveState.WAITING_FOR_TRANSFORM

	# Stop detecting new magic. We only care about this one now.
	monitoring = false
	monitorable = false
	collision_shape.set_deferred("disabled", true)
	
	sprite.modulate.a = 0.0

	var callback := Callable(self, "_on_target_magic_state_changed")
	if not target_magic.state_changed.is_connected(callback):
		target_magic.state_changed.connect(callback)

	_play_place_vfx()


func _on_target_magic_state_changed(
	magic: Magic,
	old_state: Magic.MagicType,
	new_state: Magic.MagicType
) -> void:
	if objective_state != ObjectiveState.WAITING_FOR_TRANSFORM:
		return

	if magic != target_magic:
		return

	print("[PLACE MAGIC OBJECTIVE] Magic changed: ", old_state, " -> ", new_state)

	if old_state == Magic.MagicType.NEUTRAL and new_state == Magic.MagicType.LIGHT:
		_complete_objective()

	elif old_state == Magic.MagicType.NEUTRAL and new_state == Magic.MagicType.SHIELD:
		print("Shields are good for blocking, but we want to practice making Light magic.")

	elif old_state == Magic.MagicType.NEUTRAL and new_state == Magic.MagicType.HEAVY:
		print("That's Heavy magic. We want Light for now.")


func _complete_objective() -> void:
	if objective_state == ObjectiveState.COMPLETE:
		return

	objective_state = ObjectiveState.COMPLETE

	print("[PLACE MAGIC OBJECTIVE] Basic magic changed into Light magic.")

	completed.emit()
	_play_complete_vfx()


func _play_place_vfx() -> void:
	# Small feedback: Basic magic was placed correctly.
	glow_sprite.visible = true
	glow_sprite.modulate.a = 0.0
	glow_sprite.scale = Vector2.ONE

	particles.visible = true
	particles.modulate.a = 1.0
	particles.restart()

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(glow_sprite, "modulate:a", 0.4, 0.08)
	tween.tween_property(glow_sprite, "scale", Vector2.ONE * 1.3, 0.2)

	tween.chain()
	tween.tween_property(glow_sprite, "modulate:a", 0.0, 0.2)


func _play_complete_vfx() -> void:
	# Bigger feedback: Basic transformed into Light successfully.
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
