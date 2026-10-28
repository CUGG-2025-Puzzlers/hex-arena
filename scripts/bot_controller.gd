# NOTE: THIS SCRIPT IS MOSTLY AI-GENERATED. 
# MAY NOT WORK EFFICIENTLY, OR BE WELL-STRUCTURED.

extends Node
class_name BotController

enum BotAction {
	NONE,
	PLACE_BASIC,
	TRANSFORM_LIGHT,
	TRANSFORM_HEAVY,
	TRANSFORM_SHIELD,
	FIRE_AT_PLAYER
}

@export var reaction_delay := 1.25
@export var reaction_randomness := 0.45
@export var mistake_chance := 0.20
@export var shield_chance := 0.25

@export var movement_enabled := true
@export var movement_change_interval := 1.5
@export var movement_randomness := 0.75
@export var keep_distance_from_player := 700.0
@export var max_distance_from_home := 500.0

var movement_timer := 0.0
var move_target: Vector2
var home_position: Vector2
var input_sync: Node

var controlled_player: Node2D
var target_player: Node2D
var bot_player_id := 999

var think_timer := 1.0


func setup(bot: Node2D, target: Node2D, id: int = 999) -> void:
	controlled_player = bot
	target_player = target
	bot_player_id = id

	home_position = controlled_player.global_position
	move_target = home_position

	input_sync = controlled_player.get_node_or_null("InputSynchronizer")

	if input_sync == null:
		push_warning("[BOT] Missing InputSynchronizer on bot.")

	print("[BOT] setup complete")

func _process(delta: float) -> void:
	if controlled_player == null or target_player == null:
		return

	think_timer -= delta

	if think_timer > 0.0:
		return

	var action := choose_action()
	execute_action(action)

	think_timer = reaction_delay + randf_range(0.0, reaction_randomness)

func _physics_process(delta: float) -> void:
	if not movement_enabled:
		_set_bot_direction(Vector2.ZERO)
		return

	if controlled_player == null or target_player == null:
		_set_bot_direction(Vector2.ZERO)
		return

	_update_movement_target(delta)
	_drive_player_movement()

func _update_movement_target(delta: float) -> void:
	movement_timer -= delta

	if movement_timer > 0.0:
		return

	movement_timer = movement_change_interval + randf_range(0.0, movement_randomness)

	var to_player := target_player.global_position - controlled_player.global_position
	var distance_to_player := to_player.length()

	var desired_direction := Vector2.ZERO

	if distance_to_player < keep_distance_from_player:
		# Back away if player is close.
		desired_direction = -to_player.normalized()
	else:
		# Otherwise strafe around the player.
		desired_direction = to_player.normalized().rotated(randf_range(-PI * 0.75, PI * 0.75))

	desired_direction = desired_direction.rotated(randf_range(-0.5, 0.5)).normalized()

	var desired_target := controlled_player.global_position + desired_direction * randf_range(120.0, 260.0)

	if desired_target.distance_to(home_position) > max_distance_from_home:
		desired_target = home_position + (desired_target - home_position).normalized() * max_distance_from_home

	move_target = desired_target
	
func _drive_player_movement() -> void:
	if input_sync == null:
		return

	var to_target := move_target - controlled_player.global_position

	if to_target.length() < 20.0:
		_set_bot_direction(Vector2.ZERO)
		return

	_set_bot_direction(to_target.normalized())
	
func _set_bot_direction(direction: Vector2) -> void:
	if input_sync == null:
		return

	input_sync.direction = direction
	
func choose_action() -> BotAction:
	if randf() < mistake_chance:
		return BotAction.NONE

	var owned_magic := _get_owned_magic()
	var enemy_magic := _get_enemy_magic()

	if _enemy_has_shield(enemy_magic) and _has_neutral_magic(owned_magic):
		return BotAction.TRANSFORM_HEAVY

	if owned_magic.is_empty():
		return BotAction.PLACE_BASIC

	if _has_light_magic(owned_magic):
		return BotAction.FIRE_AT_PLAYER

	if _has_neutral_magic(owned_magic):
		if randf() < shield_chance:
			return BotAction.TRANSFORM_SHIELD
		else:
			return BotAction.TRANSFORM_LIGHT

	return BotAction.NONE
	
func execute_action(action: BotAction) -> void:
	match action:
		BotAction.PLACE_BASIC:
			_place_basic_magic()

		BotAction.TRANSFORM_LIGHT:
			_transform_neutral_magic(Magic.MagicType.LIGHT)

		BotAction.TRANSFORM_HEAVY:
			_transform_neutral_magic(Magic.MagicType.HEAVY)

		BotAction.TRANSFORM_SHIELD:
			_transform_neutral_magic(Magic.MagicType.PASSIVE)

		BotAction.FIRE_AT_PLAYER:
			_fire_light_at_player()

		BotAction.NONE:
			print("[BOT] wait")
			
func _get_owned_magic() -> Array[Magic]:
	var result: Array[Magic] = []

	for node in get_tree().get_nodes_in_group("magic"):
		var magic := node as Magic

		if magic == null:
			continue

		if magic.player_id == bot_player_id:
			result.append(magic)

	return result


func _get_enemy_magic() -> Array[Magic]:
	var result: Array[Magic] = []

	for node in get_tree().get_nodes_in_group("magic"):
		var magic := node as Magic

		if magic == null:
			continue

		if magic.player_id != bot_player_id:
			result.append(magic)

	return result

func _has_neutral_magic(magic_list: Array[Magic]) -> bool:
	for magic in magic_list:
		if magic.state == Magic.MagicType.NEUTRAL:
			return true

	return false


func _has_light_magic(magic_list: Array[Magic]) -> bool:
	for magic in magic_list:
		if magic.state == Magic.MagicType.LIGHT:
			return true

	return false


func _enemy_has_shield(magic_list: Array[Magic]) -> bool:
	for magic in magic_list:
		if magic.state == Magic.MagicType.PASSIVE:
			return true

	return false
	
func _place_basic_magic() -> void:
	var hex_cells := _get_hex_cells()
	var bot := controlled_player as Player

	if hex_cells == null or bot == null:
		return

	if bot.preset == null or bot.stats_update == null:
		return

	var cell := _get_bot_place_cell()

	if not HexCells.cell_dict.has(cell):
		return

	if is_instance_valid(HexCells.cell_dict[cell]):
		return

	var place_type: Magic.MagicType = bot.preset.default_state_to_place

	if not bot.preset.magics.has(place_type):
		push_warning("[BOT] Preset has no default magic type.")
		return

	var magic_stats: MagicStats = bot.preset.magics[place_type]

	if magic_stats == null:
		return

	if bot.stats_update.current_mana < magic_stats.cost:
		return

	hex_cells.place_magic_in_cell_for_player.rpc(
		cell,
		place_type,
		bot_player_id
	)

func _transform_neutral_magic(new_type: Magic.MagicType) -> void:
	var hex_cells := _get_hex_cells()
	var bot := controlled_player as Player

	if hex_cells == null or bot == null or bot.stats_update == null:
		return

	for node in get_tree().get_nodes_in_group("magic"):
		var magic := node as Magic

		if magic == null:
			continue

		if magic.player_id != bot_player_id:
			continue

		if magic.state != Magic.MagicType.NEUTRAL:
			continue

		var transform_cost := magic.change_state_cost(new_type)

		# This particular Neutral cannot transform into the requested type.
		if transform_cost < 0.0:
			continue

		if bot.stats_update.current_mana < transform_cost:
			return

		hex_cells.change_magic_in_cell_for_player.rpc(
			magic.self_cell,
			new_type,
			bot_player_id
		)

		bot._use_mana.rpc(transform_cost)

		print("[BOT] transformed magic to ", new_type)
		return
		
func _fire_light_at_player() -> void:
	var hex_cells := _get_hex_cells()
	if hex_cells == null:
		return

	var magic := _get_first_owned_magic_of_type(Magic.MagicType.LIGHT)
	if magic == null:
		return

	var direction := (target_player.global_position - magic.global_position).normalized()
	var path := Magic.create_wiggly_path(direction, Magic.BULLET_DISTANCE)

	hex_cells.launch_magic_in_cell.rpc(
		magic.self_cell,
		path,
		bot_player_id
	)
func _get_first_owned_magic_of_type(required_type: Magic.MagicType) -> Magic:
	for node in get_tree().get_nodes_in_group("magic"):
		var magic := node as Magic
		if magic == null:
			continue

		if magic.player_id == bot_player_id and magic.state == required_type:
			return magic

	return null

func _get_hex_cells() -> HexCells:
	return get_tree().current_scene.get_node_or_null("Path2D") as HexCells

func _get_bot_cell() -> Vector2i:
	var hex_cells := _get_hex_cells()

	if hex_cells == null or controlled_player == null:
		return Vector2i.ZERO

	var collision := controlled_player.get_node_or_null("CollisionShape2D") as CollisionShape2D

	if collision != null:
		return hex_cells.local_to_map(collision.global_position)

	return hex_cells.local_to_map(controlled_player.global_position)

func _get_bot_place_cell() -> Vector2i:
	var bot_cell := _get_bot_cell()

	# Start with the cell below the bot, toward the player.
	var candidate := bot_cell + Vector2i(0, 1)

	if HexCells.cell_dict.has(candidate) and not is_instance_valid(HexCells.cell_dict[candidate]):
		return candidate

	# Fallback: search around bot.
	var nearby := HexCells.get_surrounding_cells_in_radius(bot_cell, 2, true)

	for cell in nearby:
		if HexCells.cell_dict.has(cell) and not is_instance_valid(HexCells.cell_dict[cell]):
			return cell

	return bot_cell
