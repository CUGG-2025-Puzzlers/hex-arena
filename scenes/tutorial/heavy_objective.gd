extends Node2D

signal completed

@export var shield_cell: Vector2i = Vector2i.ZERO
@export var enemy_player_id: int = 999

var shield_magic: Magic = null
var active: bool = false
var complete: bool = false


func activate() -> void:
	if active or complete:
		return

	print("[SHIELD OBJECTIVE] activated")

	active = true

	shield_magic = get_tree().current_scene.spawn_tutorial_magic(
		shield_cell,
		Magic.MagicType.PASSIVE,
		enemy_player_id
	)

	if shield_magic == null:
		active = false
		push_error("[SHIELD OBJECTIVE] Failed to spawn Shield.")
		return

	_disable_shield_auto_fizzle_timer()

	if not shield_magic.area_entered.is_connected(
		_on_shield_area_entered
	):
		shield_magic.area_entered.connect(
			_on_shield_area_entered
		)


func _disable_shield_auto_fizzle_timer() -> void:
	if shield_magic == null or not is_instance_valid(shield_magic):
		return

	# Setting this prevents any later code from treating the Shield as
	# automatically expiring.
	if shield_magic is MagicShield:
		var shield := shield_magic as MagicShield
		shield.expires = false

	# MagicShield creates its lifetime Timer during _ready(), before this
	# objective receives the spawned instance, so remove that Timer as well.
	for child in shield_magic.get_children():
		if child is Timer:
			var timer := child as Timer

			print(
				"[SHIELD OBJECTIVE] Removing Shield timer: ",
				timer.name
			)

			timer.stop()
			timer.queue_free()


func _on_shield_area_entered(area: Area2D) -> void:
	print("[SHIELD OBJECTIVE] area entered: ", area.name)

	if not active or complete:
		print("[SHIELD OBJECTIVE] ignored: inactive or complete")
		return

	if not area.is_in_group("magic"):
		print("[SHIELD OBJECTIVE] ignored: not magic")
		return

	var magic := area as Magic

	if magic == null:
		print("[SHIELD OBJECTIVE] ignored: area is not Magic")
		return

	print(
		"[SHIELD OBJECTIVE] hit by magic. state=",
		Magic.MagicType.keys()[magic.state],
		" player_id=",
		magic.player_id,
		" enemy_player_id=",
		enemy_player_id
	)

	# Ignore the Shield's own side.
	if magic.player_id == enemy_player_id:
		print("[SHIELD OBJECTIVE] ignored: enemy-owned magic")
		return

	if magic.state != Magic.MagicType.HEAVY:
		print("[SHIELD OBJECTIVE] ignored: not Heavy")
		return

	print("[SHIELD OBJECTIVE] Heavy hit Shield.")

	_complete_objective()


func _complete_objective() -> void:
	if complete:
		return

	complete = true
	active = false

	print("[SHIELD OBJECTIVE] complete")

	# The valid Heavy collision is sufficient to complete the tutorial step.
	# Remove the Shield afterward without relying on a removed fizzling signal.
	if shield_magic != null and is_instance_valid(shield_magic):
		shield_magic.call_deferred("fizzle")

	completed.emit()
