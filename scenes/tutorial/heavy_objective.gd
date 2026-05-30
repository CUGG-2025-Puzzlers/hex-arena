extends Node2D

signal completed

@export var shield_cell: Vector2i
@export var enemy_player_id := 999

var shield_magic: Magic
var complete := false


func activate() -> void:
	print("[SHIELD OBJECTIVE] activated")

	shield_magic = get_tree().current_scene.spawn_tutorial_magic(
		shield_cell,
		Magic.MagicType.SHIELD,
		enemy_player_id
	)

	if shield_magic == null:
		return

	# Remove the built-in 5-second shield fizzle timer.
	_disable_shield_auto_fizzle_timer()

	# Make normal Light damage unable to kill it.
	shield_magic.health = 999999.0

	# Complete when destroyed.
	shield_magic.fizzling.connect(_on_shield_destroyed)

	# Enforce tutorial rule externally.
	shield_magic.area_entered.connect(_on_shield_area_entered)
	
func _disable_shield_auto_fizzle_timer() -> void:
	if shield_magic == null:
		return

	for child in shield_magic.get_children():
		if child is Timer:
			print("[SHIELD OBJECTIVE] Removing shield auto-fizzle timer: ", child.name)
			child.stop()
			child.queue_free()
			
func _on_shield_area_entered(area: Area2D) -> void:
	print("[SHIELD OBJECTIVE] area entered: ", area.name)

	if complete:
		print("[SHIELD OBJECTIVE] ignored: already complete")
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
		magic.state,
		" player_id=",
		magic.player_id,
		" enemy_player_id=",
		enemy_player_id
	)

	if magic.player_id == enemy_player_id:
		print("[SHIELD OBJECTIVE] ignored: enemy-owned magic")
		return

	if magic.state != Magic.MagicType.HEAVY:
		print("[SHIELD OBJECTIVE] ignored: not Heavy")
		return

	print("[SHIELD OBJECTIVE] Heavy hit shield. Breaking.")
	shield_magic.call_deferred("fizzle")


func _on_shield_destroyed() -> void:
	if complete:
		return

	complete = true
	print("[SHIELD OBJECTIVE] complete")

	completed.emit()
