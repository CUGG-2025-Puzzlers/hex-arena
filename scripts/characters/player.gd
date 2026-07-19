extends CharacterBody2D
class_name Player

@export var base_speed : float = 135.0
@export var animation_tree : AnimationTree
@export var animation_player : AnimationPlayer
@export var uses_directional_animation: bool = true

@onready var _input: MultiplayerInput = %InputSynchronizer
@onready var _ability : AbilityBase = %Ability

var do_ability : String
var input : Vector2
var canMove : bool
var playback : AnimationNodeStateMachinePlayback

@export var radius : int = 1
var radius_cells : Array
var cell : Vector2i

@export var preset: CharacterStats
@export var stats_update: StatsUpdate

var rooted_until_msec: int = 0

var player_id: int:
	set(value):
		player_id = value
		%InputSynchronizer.set_multiplayer_authority(value)

func _ready() -> void:
	if animation_tree != null:
		playback = animation_tree["parameters/playback"]
	
	# collision with environment is layer 1 and ignore other players
	set_collision_layer_value(2, true)   # player on layer 2
	set_collision_mask_value(2, false)   # player cant collide with layer 2
	
	radius_cells = HexCells.get_surrounding_cells_in_radius(Vector2i.ZERO, radius)
	get_node("Drawing range").draw_range(radius_cells)
	
	get_node("Area2D").area_entered.connect(_on_area_entered)

func _process(_delta: float) -> void:
	if multiplayer.is_server():
		_reconcile_pos.rpc(position)

func _physics_process(delta: float) -> void:
	# Root stops movement but does not disable MultiplayerInput, so the player
	# can still place, transform, and fire magic.
	if is_rooted():
		velocity = Vector2.ZERO
		move_and_slide()
		if playback != null:
			playback.travel("Stop")
		cell = HexCells.player_unique_instance.local_to_map(
			get_node("CollisionShape2D").global_position
		)
		return

	# no movement if dashing
	if _ability is DashAbility and _ability.is_controlling_movement():
		return
		
	if _ability is TeleportAbility and _ability.is_channeling:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	_handle_movement(delta)
	select_animation()
	update_animation_parameters()
		
	cell = HexCells.player_unique_instance.local_to_map(
		get_node("CollisionShape2D").global_position
	)

func select_animation():
	if playback == null:
		return

	if _input.direction == Vector2.ZERO:
		playback.travel("Stop")
	else:
		playback.travel("Walk")

func update_animation_parameters():
	if not uses_directional_animation or animation_tree == null:
		return

	if _input.direction == Vector2.ZERO:
		return
		
	animation_tree["parameters/Walk/blend_position"] = _input.direction
	animation_tree["parameters/Stop/blend_position"] = _input.direction

func _handle_movement(_delta: float) -> void:	
	# ghost speed multiplier when active
	var speed = base_speed
	if _ability is GhostAbility:
		speed *= _ability.get_speed_multiplier()
	
	if _input.use_ability:
		_ability.try_activate()

	velocity = _input.direction * speed
	move_and_slide()

func set_player_name(player_name: String):
	stats_update.update_name(player_name) 

func get_stats() -> StatsUpdate:
	return stats_update
	
func is_channeling() -> bool:
	return _ability is TeleportAbility and _ability.is_channeling
	
func is_dashing() -> bool:
	return _ability is DashAbility and _ability.is_dashing


func is_invulnerable() -> bool:
	# Only Water Orb's Reform grants immunity. Zilo's Dash is still vulnerable.
	if _ability is ReformAbility:
		return (_ability as ReformAbility).is_granting_invulnerability()
	return false


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
		if root_hand.player_id == player_id or not root_hand.try_consume_hit():
			return

		root_hand.call_deferred("fizzle")
		var root_blood := get_node_or_null("Area2D/CPUParticles2D") as CPUParticles2D
		if root_blood != null:
			root_blood.restart()

		if multiplayer.is_server():
			_apply_root.rpc(root_hand.root_duration)
		return

	if area is Magic \
	and not (area is MagicBurst) \
	and area.state in [Magic.MagicType.LIGHT, Magic.MagicType.HEAVY] \
	and area.player_id != player_id:
		area.call_deferred("fizzle")
		var blood: CPUParticles2D = get_node("Area2D/CPUParticles2D")
		blood.restart()

		# only server calculates and then syncs damage
		if multiplayer.is_server():
			var damage_amount = area.damage / randf_range(3.3, 3.5)
			_apply_damage.rpc(damage_amount)

@rpc("authority", "call_local", "reliable")
func _apply_root(duration: float) -> void:
	rooted_until_msec = maxi(
		rooted_until_msec,
		Time.get_ticks_msec() + int(duration * 1000.0)
	)
	velocity = Vector2.ZERO

	# DashAbility moves the player from its own _physics_process(), so it must
	# be cancelled explicitly when a root lands.
	if _ability is DashAbility:
		(_ability as DashAbility).cancel_dash()

@rpc("authority", "call_local", "reliable")
func _apply_damage(amount: float) -> void:
	# Explicit attacks such as Tideblade, Pressure Lance, Burst, and Razor Wire
	# call this function directly, so the invulnerability check belongs here too.
	if is_invulnerable():
		return
	stats_update.take_damage(amount)

@rpc("authority", "call_local", "reliable")
func _use_mana(amount: float) -> void:
	stats_update.use_mana(amount)

#FORCE POSITION
@rpc("authority", "call_local", "reliable")
func _reconcile_pos(target_pos: Vector2) -> void:
	position = target_pos
