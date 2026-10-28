extends Node
class_name WaterOrbWireController


const WATER_ORB_WIRE_SCENE := preload(
	"res://scenes/magic_types/water_orb_wire.tscn"
)

const RAZOR_CURRENT := 1
const FLOW_CIRCUIT := 2

@export_enum("Razor Current:1", "Flow Circuit:2")
var wire_variant: int = RAZOR_CURRENT

@export var base_connection_cost: float = 5.0
@export var cost_per_hex: float = 2.0

var next_wire_id: int = 0

@onready var player: Player = get_parent() as Player


func try_create_wire() -> void:
	if player == null:
		return

	_request_create_wire.rpc_id(1)


@rpc("any_peer", "call_local", "reliable")
func _request_create_wire() -> void:
	if not multiplayer.is_server():
		return

	if player == null or player.preset == null:
		return

	# The client may invoke only the controller attached to its own player.
	# Local host calls report sender ID 0.
	var sender_id: int = multiplayer.get_remote_sender_id()

	if sender_id == 0:
		if player.player_id != multiplayer.get_unique_id():
			return
	elif sender_id != player.player_id:
		push_warning(
			"Rejected Water Orb wire request for another player."
		)
		return

	if wire_variant not in [RAZOR_CURRENT, FLOW_CIRCUIT]:
		return

	var owned_orbs: Array[MagicTidebladeOrb] = (
		_get_surviving_tideblades()
	)

	if owned_orbs.size() < 2:
		print(
			"[WATER ORB] Q requires at least two surviving "
			+ "Tideblade Orbs."
		)
		return

	owned_orbs.sort_custom(
		func(
			first: MagicTidebladeOrb,
			second: MagicTidebladeOrb
		) -> bool:
			return (
				first.creation_sequence
				< second.creation_sequence
			)
	)

	var endpoint_a: MagicTidebladeOrb = (
		owned_orbs[owned_orbs.size() - 2]
	)
	var endpoint_b: MagicTidebladeOrb = (
		owned_orbs[owned_orbs.size() - 1]
	)

	var hex_length: int = _hex_distance(
		endpoint_a.self_cell,
		endpoint_b.self_cell
	)

	var connection_cost: float = (
		base_connection_cost
		+ cost_per_hex * float(hex_length)
	)

	if (
		player.stats_update == null
		or player.stats_update.current_mana < connection_cost
	):
		print(
			"[WATER ORB] Not enough mana to connect "
			+ "Tideblades. Need ",
			connection_cost,
			" mana."
		)
		return

	# There is intentionally no duplicate-pair check and no clear-existing
	# operation. Every successful Q press creates another independent wire.
	player._use_mana.rpc(connection_cost)

	next_wire_id += 1
	_spawn_wire.rpc(
		endpoint_a.self_cell,
		endpoint_b.self_cell,
		wire_variant,
		next_wire_id
	)


func _get_surviving_tideblades() -> Array[MagicTidebladeOrb]:
	var result: Array[MagicTidebladeOrb] = []

	for node: Node in get_tree().get_nodes_in_group(
		"tideblade_orb"
	):
		if not (node is MagicTidebladeOrb):
			continue

		var orb: MagicTidebladeOrb = (
			node as MagicTidebladeOrb
		)

		if orb.player_id != player.player_id:
			continue

		if orb.creation_sequence < 0:
			continue

		if orb.attacks_remaining <= 0:
			continue

		if orb.is_queued_for_deletion():
			continue

		result.append(orb)

	return result


@rpc("authority", "call_local", "reliable")
func _spawn_wire(
	endpoint_a_cell: Vector2i,
	endpoint_b_cell: Vector2i,
	variant: int,
	wire_id: int
) -> void:
	var endpoint_a: MagicTidebladeOrb = _find_endpoint(
		endpoint_a_cell
	)
	var endpoint_b: MagicTidebladeOrb = _find_endpoint(
		endpoint_b_cell
	)

	if endpoint_a == null or endpoint_b == null:
		push_warning(
			"Could not create Water Orb wire because "
			+ "an endpoint was missing."
		)
		return

	var wire: WaterOrbWire = (
		WATER_ORB_WIRE_SCENE.instantiate()
		as WaterOrbWire
	)

	if wire == null:
		push_error("Water Orb wire scene has the wrong root script.")
		return

	wire.name = "WaterWire_%d_%d" % [
		player.player_id,
		wire_id,
	]

	get_tree().current_scene.add_child(wire, true)

	wire.configure(
		endpoint_a,
		endpoint_b,
		player.player_id,
		variant,
		wire_id
	)


func _find_endpoint(
	cell: Vector2i
) -> MagicTidebladeOrb:
	for node: Node in get_tree().get_nodes_in_group(
		"tideblade_orb"
	):
		if not (node is MagicTidebladeOrb):
			continue

		var orb: MagicTidebladeOrb = (
			node as MagicTidebladeOrb
		)

		if orb.player_id != player.player_id:
			continue

		if orb.self_cell != cell:
			continue

		if orb.is_queued_for_deletion():
			continue

		return orb

	return null


func _hex_distance(
	first: Vector2i,
	second: Vector2i
) -> int:
	# Convert this project's odd-row offset coordinates to axial coordinates.
	var first_q: int = (
		first.x
		- int((first.y - posmod(first.y, 2)) / 2)
	)
	var second_q: int = (
		second.x
		- int((second.y - posmod(second.y, 2)) / 2)
	)

	var delta_q: int = first_q - second_q
	var delta_r: int = first.y - second.y

	return int(
		(
			absi(delta_q)
			+ absi(delta_r)
			+ absi(delta_q + delta_r)
		) / 2
	)
