extends CharacterBody2D

@export var base_speed : float = 150.0
@export var animation_tree : AnimationTree
@export var animation_player : AnimationPlayer

@onready var _input: MultiplayerInput = %InputSynchronizer

@onready var stats : StatsComponent = $StatsComponent
@onready var flash_ability : FlashAbility = $FlashAbility
@onready var dash_ability: DashAbility = $DashAbility
@onready var ghost_ability : GhostAbility = $GhostAbility
@onready var teleport_ability : TeleportAbility = $TeleportAbility

var do_ability : String
var input : Vector2
var canMove : bool
var playback : AnimationNodeStateMachinePlayback

var radius : int = 1
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

func _physics_process(delta: float) -> void:
	#no movement if dashing
	if dash_ability.is_controlling_movement():
		return
		
	if teleport_ability.is_channeling:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	_handle_movement(delta)
	select_animation()
	update_animation_parameters()
	
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
	var speed = base_speed * ghost_ability.get_speed_multiplier()
	
	match _input.ability:
		Util.Ability.Flash:
			flash_ability.try_activate()
		Util.Ability.Dash:
			dash_ability.try_activate()
		Util.Ability.Ghost:
			ghost_ability.try_activate()
		Util.Ability.Teleport:
			teleport_ability.try_activate()

	velocity = _input.direction * speed
	move_and_slide()

func set_player_name(player_name: String):
	%NameLabel.text = player_name

func get_stats() -> StatsComponent:
	return stats
	
func is_channeling() -> bool:
	return teleport_ability.is_channeling
	
func is_dashing() -> bool:
	return dash_ability.is_dashing
	
func _unhandled_input(event: InputEvent) -> void:
	if %InputSynchronizer.get_multiplayer_authority() != player_id:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_K:
			stats.take_damage(10.0)
		elif event.keycode == KEY_L:
			stats.heal(10.0)
		elif event.keycode == KEY_M:
			stats.use_mana(20.0)
