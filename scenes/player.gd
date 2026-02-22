extends CharacterBody2D

@export var base_speed : float = 150.0
@export var animation_tree : AnimationTree
@export var animation_player : AnimationPlayer

@onready var _input: MultiplayerInput = %InputSynchronizer
@onready var OverheadHp : ProgressBar = $OverheadHp
@onready var stats : StatsComponent = $StatsComponent
@onready var _ability : AbilityBase = %Ability

var do_ability : String
var input : Vector2
var canMove : bool
var playback : AnimationNodeStateMachinePlayback

@export var radius : int = 1
var radius_cells : Array
var cell : Vector2i

var player_id: int:
	set(value):
		player_id = value
		%InputSynchronizer.set_multiplayer_authority(value)

func _ready() -> void:
	playback = animation_tree["parameters/playback"]
	
	# collision with environment is layer 1 and ignore other players
	set_collision_layer_value(2, true)   # player on layer 2
	set_collision_mask_value(2, false)   # player cant collide with layer 2
	
	radius_cells = HexCells.get_surrounding_cells_in_radius(Vector2i.ZERO, radius)
	get_node("Drawing range").draw_range(radius_cells)
	
	get_node("Area2D").area_entered.connect(_on_area_entered)
	
	stats.health_changed.connect(_on_overhead_hp_changed)
	_on_overhead_hp_changed.call_deferred(stats.current_health, stats.max_health)

func _physics_process(delta: float) -> void:
	#no movement if dashing
	if _ability is DashAbility and _ability.is_controlling_movement():
		return
		
	if _ability is TeleportAbility and _ability.is_channeling:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	_handle_movement(delta)
	select_animation()
	update_animation_parameters()
	
	if multiplayer.is_server():
		_reconcile_pos.rpc(position)
	
	cell = HexCells.player_unique_instance.local_to_map(get_node("CollisionShape2D").global_position)

func select_animation():
	if _input.direction == Vector2.ZERO:
		playback.travel("Stop")
	else:
		playback.travel("Walk")

func update_animation_parameters():
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
	%NameLabel.text = player_name

func _on_overhead_hp_changed(current: float, maximum: float) -> void:
	if not OverheadHp:
		return
		
	print("Overhead HP update: ", current, " / ", maximum)
	OverheadHp.max_value = maximum
	OverheadHp.value = current

func get_stats() -> StatsComponent:
	return stats
	
func is_channeling() -> bool:
	return _ability is TeleportAbility and _ability.is_channeling
	
func is_dashing() -> bool:
	return _ability is DashAbility and _ability.is_dashing
	
func _unhandled_input(event: InputEvent) -> void:
	if %InputSynchronizer.get_multiplayer_authority() != player_id:
		return
	"""
	for testing damage, heal, mana use
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_K:
			stats.take_damage(10.0)
		elif event.keycode == KEY_L:
			stats.heal(10.0)
		elif event.keycode == KEY_M:
			stats.use_mana(20.0)
	"""



func _on_area_entered(area: Area2D) -> void:
	if area is Magic and area.state in [Magic.MagicType.LIGHT, Magic.MagicType.HEAVY] and area.player_id != player_id:
		area.call_deferred("fizzle")
		var blood: CPUParticles2D = get_node("Area2D/CPUParticles2D")
		blood.restart()

		# only server calculates and then syncs damage
		if multiplayer.is_server():
			var damage_amount = area.damage / randf_range(3.0, 4.0)
			_apply_damage.rpc(damage_amount)

@rpc("authority", "call_local", "reliable")
func _apply_damage(amount: float) -> void:
	stats.take_damage(amount)

@rpc("authority", "call_local", "reliable")
func _reconcile_pos(target_pos: Vector2) -> void:
	position = target_pos
