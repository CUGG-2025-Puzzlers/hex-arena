extends CharacterBody2D
class_name Player

@export var base_speed: float = 135.0
@export var animation_tree: AnimationTree
@export var animation_player: AnimationPlayer
@export var uses_directional_animation: bool = true

@onready var _input: MultiplayerInput = %InputSynchronizer
@onready var _ability: AbilityBase = %Ability

var do_ability: String
var input: Vector2
var canMove: bool
var playback: AnimationNodeStateMachinePlayback

@export var radius: int = 1
var radius_cells: Array
var cell: Vector2i
signal changed_cell(player_ind: int, new_cell: Vector2i)

@export var preset: CharacterStats
@export var stats_update: StatsUpdate

var rooted_until_msec: int = 0
var silenced_until_msec: int = 0
var _move_modifiers: Dictionary = {}
var _fading_modifier_versions: Dictionary = {}

var display_name: String = "Player"

var player_id: int:
	set(value):
		player_id = value
		%InputSynchronizer.set_multiplayer_authority(value)


func _ready() -> void:
	# Water Orb currently uses a static sprite, so AnimationTree is optional.
	if animation_tree != null:
		playback = animation_tree["parameters/playback"]

	# Collision with environment is layer 1; players ignore other players.
	set_collision_layer_value(2, true)
	set_collision_mask_value(2, false)

	radius_cells = HexCells.get_surrounding_cells_in_radius(
		Vector2i.ZERO,
		radius
	)
	get_node("Drawing range").draw_range(radius_cells)
	get_node("Area2D").area_entered.connect(_on_area_entered)

	_update_current_cell()


func _physics_process(delta: float) -> void:
	# Root stops movement but does not disable MultiplayerInput, so the player
	# can still place, transform, and fire magic.
	if is_rooted():
		velocity = Vector2.ZERO
		move_and_slide()

		if playback != null:
			playback.travel("Stop")

		_update_current_cell()
		return

	if _ability != null and _ability.blocks_movement():
		velocity = Vector2.ZERO
		move_and_slide()
		if playback != null:
			playback.travel("Stop")
		_update_current_cell()
		return

	# DashAbility also covers ReformAbility because Reform extends DashAbility.
	if _ability is DashAbility and _ability.is_controlling_movement():
		_update_current_cell()
		return

	if _ability is TeleportAbility and _ability.is_channeling:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_current_cell()
		return

	_handle_movement(delta)
	select_animation()
	update_animation_parameters()
	_update_current_cell()


func _update_current_cell() -> void:
	if not is_instance_valid(HexCells.player_unique_instance):
		return

	var collision_shape := get_node_or_null(
		"CollisionShape2D"
	) as CollisionShape2D

	if collision_shape == null:
		return

	var new_cell: Vector2i = (
		HexCells.player_unique_instance.local_to_map(
			collision_shape.global_position
		)
	)

	if new_cell != cell:
		HexCells.players_cells[player_id] = new_cell
		changed_cell.emit(player_id, new_cell)

	cell = new_cell


func select_animation() -> void:
	if playback == null:
		return

	if _input.direction == Vector2.ZERO:
		playback.travel("Stop")
	else:
		playback.travel("Walk")


func update_animation_parameters() -> void:
	if not uses_directional_animation or animation_tree == null:
		return

	if _input.direction == Vector2.ZERO:
		return

	animation_tree["parameters/Walk/blend_position"] = _input.direction
	animation_tree["parameters/Stop/blend_position"] = _input.direction


func _handle_movement(_delta: float) -> void:
	var speed: float = base_speed * get_move_speed_multiplier()

	if _ability is GhostAbility:
		speed *= _ability.get_speed_multiplier()

	if _input.use_ability and not is_gameplay_input_blocked():
		_ability.try_activate()

	velocity = _input.direction * speed
	move_and_slide()


func set_player_name(player_name: String) -> void:
	display_name = player_name
	stats_update.update_name(player_name)


func get_stats() -> StatsUpdate:
	return stats_update


func is_channeling() -> bool:
	return _ability is TeleportAbility and _ability.is_channeling


func is_dashing() -> bool:
	return _ability is DashAbility and _ability.is_dashing


func is_invulnerable() -> bool:
	if _ability != null and _ability.grants_invulnerability():
		return true

	# Preserve Water Orb Reform without requiring a broader refactor.
	if _ability is ReformAbility:
		return (
			_ability as ReformAbility
		).is_granting_invulnerability()

	return false


func is_silenced() -> bool:
	return Time.get_ticks_msec() < silenced_until_msec


func is_gameplay_input_blocked() -> bool:
	return (
		is_silenced()
		or (_ability != null and _ability.blocks_gameplay_input())
	)


func is_friendly_to(other: Player) -> bool:
	# Current game is 1v1. Replace this comparison with team_id later.
	return other != null and player_id == other.player_id


func get_move_speed_multiplier() -> float:
	var multiplier := 1.0
	for value in _move_modifiers.values():
		multiplier *= float(value)
	return clampf(multiplier, 0.2, 2.5)


func is_rooted() -> bool:
	return Time.get_ticks_msec() < rooted_until_msec


func _on_area_entered(area: Area2D) -> void:
	# Reform behaves as a brief liquid/untargetable dash. Zilo's ordinary
	# Dash does not enter this branch because it is not a ReformAbility.
	if area is Magic:
		var incoming_magic := area as Magic
		if incoming_magic.player_id != player_id and is_invulnerable():
			return

	# Stationary weapon Magic subclasses resolve their own explicit attacks.
	if area is Magic and (area as Magic).handles_player_contact():
		return

	if area is MagicRootHand:
		var root_hand := area as MagicRootHand

		if (
			root_hand.player_id == player_id
			or not root_hand.try_consume_hit()
		):
			return

		root_hand.call_deferred("fizzle")

		var root_blood := get_node_or_null(
			"Area2D/CPUParticles2D"
		) as CPUParticles2D

		if root_blood != null:
			root_blood.restart()

		if multiplayer.is_server():
			_apply_root.rpc(root_hand.root_duration)

		return

	if (
		area is Magic
		and not (area is MagicBurst)
		and area.state in [
			Magic.MagicType.LIGHT,
			Magic.MagicType.HEAVY,
		]
		and area.player_id != player_id
	):
		area.call_deferred("fizzle")

		var blood := get_node_or_null(
			"Area2D/CPUParticles2D"
		) as CPUParticles2D

		if blood != null:
			blood.restart()

		# Only the server calculates and synchronizes damage.
		if multiplayer.is_server():
			var damage_amount: float = (
				area.damage / randf_range(3.3, 3.5)
			)
			_apply_damage.rpc(damage_amount)


@rpc("authority", "call_local", "reliable")
func _apply_root(duration: float) -> void:
	rooted_until_msec = maxi(
		rooted_until_msec,
		Time.get_ticks_msec() + int(duration * 1000.0)
	)
	velocity = Vector2.ZERO

	# DashAbility moves the player from its own _physics_process(), so it must
	# be cancelled explicitly when a root lands. This also cancels Reform.
	if _ability is DashAbility:
		(_ability as DashAbility).cancel_dash()


@rpc("authority", "call_local", "reliable")
func _apply_damage(amount: float) -> void:
	# Explicit attacks such as Tideblade, Pressure Lance, Burst, and Razor Wire
	# call this directly, so the Reform invulnerability check belongs here too.
	if is_invulnerable():
		return

	stats_update.take_damage(amount)


@rpc("authority", "call_local", "reliable")
func _use_mana(amount: float) -> void:
	stats_update.use_mana(amount)


@rpc("authority", "call_local", "reliable")
func _apply_heal(amount: float) -> void:
	if amount > 0.0:
		stats_update.heal(amount)


@rpc("authority", "call_local", "reliable")
func _restore_mana(amount: float) -> void:
	if amount > 0.0:
		stats_update.restore_mana(amount)


@rpc("authority", "call_local", "reliable")
func _apply_silence(duration: float) -> void:
	if duration <= 0.0:
		return
	silenced_until_msec = maxi(
		silenced_until_msec,
		Time.get_ticks_msec() + int(duration * 1000.0)
	)


@rpc("authority", "call_local", "reliable")
func _set_move_modifier(source_id: String, multiplier: float) -> void:
	_move_modifiers[source_id] = maxf(multiplier, 0.05)


@rpc("authority", "call_local", "reliable")
func _remove_move_modifier(source_id: String) -> void:
	_move_modifiers.erase(source_id)


@rpc("authority", "call_local", "reliable")
func _apply_fading_slow(
	source_id: String,
	starting_multiplier: float,
	duration: float
) -> void:
	var version := int(_fading_modifier_versions.get(source_id, 0)) + 1
	_fading_modifier_versions[source_id] = version
	_run_fading_slow(
		source_id,
		clampf(starting_multiplier, 0.05, 1.0),
		maxf(duration, 0.01),
		version
	)


func _run_fading_slow(
	source_id: String,
	starting_multiplier: float,
	duration: float,
	version: int
) -> void:
	var start_msec := Time.get_ticks_msec()
	var duration_msec := int(duration * 1000.0)

	while (
		is_inside_tree()
		and int(_fading_modifier_versions.get(source_id, -1)) == version
	):
		var elapsed_msec := Time.get_ticks_msec() - start_msec
		var progress := clampf(
			float(elapsed_msec) / float(maxi(duration_msec, 1)),
			0.0,
			1.0
		)
		_move_modifiers[source_id] = lerpf(
			starting_multiplier,
			1.0,
			progress
		)

		if progress >= 1.0:
			break

		await get_tree().process_frame

	if int(_fading_modifier_versions.get(source_id, -1)) == version:
		_move_modifiers.erase(source_id)
		_fading_modifier_versions.erase(source_id)


# FORCE POSITION
@rpc("authority", "call_local", "reliable")
func _reconcile_pos(target_pos: Vector2) -> void:
	position = target_pos
