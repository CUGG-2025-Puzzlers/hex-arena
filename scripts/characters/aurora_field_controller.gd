
extends Node
class_name AuroraFieldController

const FIELD_SCENE := preload("res://scenes/magic_types/aurora_field.tscn")

var active_field: Node2D = null
var activation_pending: bool = false
var next_field_id: int = 0


func request_activate_field() -> void:
	if not multiplayer.is_server() or activation_pending:
		return

	activation_pending = true
	call_deferred("_activate_if_ready")


func _activate_if_ready() -> void:
	activation_pending = false

	var owner := get_parent() as Player
	if owner == null:
		return

	var cells: Array[Vector2i] = []
	for node in get_tree().get_nodes_in_group("aurora_orb"):
		if not (node is MagicAuroraOrb):
			continue

		var orb := node as MagicAuroraOrb
		if (
			orb.player_id == owner.player_id
			and not orb.is_queued_for_deletion()
		):
			cells.append(orb.self_cell)

	if cells.size() < 3:
		return

	next_field_id += 1
	_spawn_field.rpc(cells, next_field_id)


@rpc("authority", "call_local", "reliable")
func _spawn_field(cells: Array[Vector2i], field_id: int) -> void:
	var owner := get_parent() as Player
	if owner == null or not is_instance_valid(HexCells.player_unique_instance):
		return

	if is_instance_valid(active_field):
		active_field.queue_free()

	var points := PackedVector2Array()
	var selected_cells: Dictionary = {}
	for cell in cells:
		selected_cells[cell] = true
		points.append(
			HexCells.player_unique_instance.to_global(
				HexCells.map_to_local(cell)
			)
		)

	for node in get_tree().get_nodes_in_group("aurora_orb"):
		if not (node is MagicAuroraOrb):
			continue

		var orb := node as MagicAuroraOrb
		if orb.player_id == owner.player_id and selected_cells.has(orb.self_cell):
			orb.fizzle()

	var field := FIELD_SCENE.instantiate() as Node2D
	var current_scene := get_tree().current_scene
	current_scene.add_child(field)

	# Keep the field above the arena floor but behind the entire Players layer.
	# Tree order is used instead of a negative z-index so the polygon does not
	# disappear underneath the TileMapLayer.
	var players_layer := current_scene.get_node_or_null("Players")
	if players_layer != null:
		current_scene.move_child(field, players_layer.get_index())

	field.call("initialize", owner.player_id, field_id, points)
	active_field = field
	field.tree_exited.connect(_on_active_field_exited.bind(field))


func _on_active_field_exited(field: Node2D) -> void:
	if active_field == field:
		active_field = null
