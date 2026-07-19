extends Area2D

signal completed

enum ObjectiveState {
	INACTIVE,
	WAITING_FOR_PLACE,
	WAITING_FOR_TRANSFORM,
	COMPLETE,
}

@export var required_transform: Magic.MagicType = Magic.MagicType.LIGHT

# If the tracked Neutral disappears without being replaced, wait briefly before
# resetting. This prevents a one-frame gap during transformation from being
# mistaken for the magic being destroyed.
@export var replacement_grace_time: float = 0.25

@onready var player_id: int = multiplayer.get_unique_id()

@onready var sprite: Sprite2D = $Sprite2D
@onready var glow_sprite: Sprite2D = $Glow
@onready var particles: CPUParticles2D = $Sparkles
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var objective_state: ObjectiveState = ObjectiveState.INACTIVE

# The objective watches the cell where the Neutral magic was placed.
# Transforming magic replaces the old Magic node with a new one, so we detect
# the replacement by checking for a different instance in the same cell.
var target_cell: Vector2i
var target_player_id: int = -1
var original_magic_instance_id: int = 0

var missing_magic_time: float = 0.0


func _ready() -> void:
	visible = false
	monitoring = false
	monitorable = false
	collision_shape.set_deferred("disabled", true)

	# Processing is only needed while watching a placed Neutral magic.
	set_process(false)

	print("[PLACE MAGIC OBJECTIVE] spawned")


func activate() -> void:
	objective_state = ObjectiveState.WAITING_FOR_PLACE

	target_player_id = -1
	original_magic_instance_id = 0
	missing_magic_time = 0.0

	set_process(false)

	visible = true
	monitoring = true
	monitorable = true
	collision_shape.set_deferred("disabled", false)

	sprite.modulate.a = 1.0

	glow_sprite.visible = false
	glow_sprite.modulate.a = 0.0
	glow_sprite.scale = Vector2.ONE

	particles.visible = false
	particles.modulate.a = 1.0

	print("[PLACE MAGIC OBJECTIVE] activated")


func _process(delta: float) -> void:
	if objective_state != ObjectiveState.WAITING_FOR_TRANSFORM:
		return

	var current_magic := _get_magic_in_target_cell()

	if current_magic == null:
		missing_magic_time += delta

		if missing_magic_time >= replacement_grace_time:
			print(
				"[PLACE MAGIC OBJECTIVE] Target magic disappeared without "
				+ "the required transformation."
			)
			_reset_for_another_attempt()

		return

	missing_magic_time = 0.0

	# The originally placed Neutral magic still occupies the cell.
	if current_magic.get_instance_id() == original_magic_instance_id:
		return

	# A different Magic instance now occupies the same cell. Under the current
	# magic architecture, this means the Neutral was replaced by a transformed
	# magic scene.
	_on_replacement_magic_detected(current_magic)


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
	print(
		"[PLACE MAGIC OBJECTIVE] Neutral magic placed. "
		+ "Waiting for required transformation."
	)

	target_cell = magic.self_cell
	target_player_id = magic.player_id
	original_magic_instance_id = magic.get_instance_id()
	missing_magic_time = 0.0

	objective_state = ObjectiveState.WAITING_FOR_TRANSFORM

	# Stop detecting additional placed magic. From now on, watch the selected
	# cell for the Neutral object to be replaced.
	monitoring = false
	monitorable = false
	collision_shape.set_deferred("disabled", true)

	sprite.modulate.a = 0.0

	set_process(true)

	_play_place_vfx()


func _get_magic_in_target_cell() -> Magic:
	if not HexCells.cell_dict.has(target_cell):
		return null

	var cell_contents = HexCells.cell_dict[target_cell]

	if not is_instance_valid(cell_contents):
		return null

	var current_magic := cell_contents as Magic

	if current_magic == null:
		return null

	if current_magic.player_id != target_player_id:
		return null

	return current_magic


func _on_replacement_magic_detected(new_magic: Magic) -> void:
	# Prevent this replacement from being processed repeatedly.
	set_process(false)

	print(
		"[PLACE MAGIC OBJECTIVE] Replacement magic detected. State: ",
		new_magic.state
	)

	if new_magic.state == required_transform:
		_complete_objective()
		return

	match new_magic.state:
		Magic.MagicType.PASSIVE:
			print(
				"Passive magic is useful, but we want to practice making "
				+ "Light magic."
			)

		Magic.MagicType.HEAVY:
			print(
				"That's Heavy magic. We want Light magic for now."
			)

		Magic.MagicType.LIGHT:
			print(
				"That's Light magic, but it is not the transformation "
				+ "required by this objective."
			)

		Magic.MagicType.NEUTRAL:
			# A different Neutral instance replaced the original one. Continue
			# tracking this new Neutral rather than resetting the objective.
			original_magic_instance_id = new_magic.get_instance_id()
			missing_magic_time = 0.0
			set_process(true)
			return

		_:
			print(
				"That was not the required magic transformation."
			)

	_reset_for_another_attempt()


func _reset_for_another_attempt() -> void:
	set_process(false)

	target_player_id = -1
	original_magic_instance_id = 0
	missing_magic_time = 0.0

	objective_state = ObjectiveState.WAITING_FOR_PLACE

	visible = true
	monitoring = true
	monitorable = true
	collision_shape.set_deferred("disabled", false)

	sprite.modulate.a = 1.0

	glow_sprite.visible = false
	glow_sprite.modulate.a = 0.0
	glow_sprite.scale = Vector2.ONE

	particles.visible = false
	particles.modulate.a = 1.0

	print(
		"[PLACE MAGIC OBJECTIVE] Reset. Waiting for another Neutral magic."
	)


func _complete_objective() -> void:
	if objective_state == ObjectiveState.COMPLETE:
		return

	objective_state = ObjectiveState.COMPLETE

	set_process(false)
	monitoring = false
	monitorable = false
	collision_shape.set_deferred("disabled", true)

	print(
		"[PLACE MAGIC OBJECTIVE] Neutral magic changed into the "
		+ "required magic."
	)

	completed.emit()
	_play_complete_vfx()


func _play_place_vfx() -> void:
	# Small feedback: Neutral magic was placed correctly.
	glow_sprite.visible = true
	glow_sprite.modulate.a = 0.0
	glow_sprite.scale = Vector2.ONE

	particles.visible = true
	particles.modulate.a = 1.0
	particles.restart()

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		glow_sprite,
		"modulate:a",
		0.4,
		0.08
	)

	tween.tween_property(
		glow_sprite,
		"scale",
		Vector2.ONE * 1.3,
		0.2
	)

	tween.chain()

	tween.tween_property(
		glow_sprite,
		"modulate:a",
		0.0,
		0.2
	)


func _play_complete_vfx() -> void:
	# Bigger feedback: Neutral transformed successfully.
	glow_sprite.visible = true
	glow_sprite.modulate.a = 0.0
	glow_sprite.scale = Vector2.ONE

	particles.visible = true
	particles.modulate.a = 1.0
	particles.restart()

	var tween := create_tween()
	tween.set_parallel(true)

	tween.tween_property(
		sprite,
		"modulate:a",
		0.0,
		0.35
	)

	tween.tween_property(
		glow_sprite,
		"modulate:a",
		0.8,
		0.12
	)

	tween.tween_property(
		glow_sprite,
		"scale",
		Vector2.ONE * 1.8,
		0.35
	)

	tween.chain()

	tween.tween_property(
		glow_sprite,
		"modulate:a",
		0.0,
		0.25
	)

	tween.tween_property(
		particles,
		"modulate:a",
		0.0,
		0.25
	)

	tween.finished.connect(queue_free)
