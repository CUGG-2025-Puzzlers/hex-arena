
extends AbilityBase
class_name PrismaticStillness

@export_range(0.1, 3.0, 0.05) var duration: float = 0.8
@export_range(0.0, 100.0, 1.0) var mana_restore: float = 28.0
@export_range(0.0, 1.0, 0.05) var active_opacity: float = 0.68

var elapsed: float = 0.0
var _visual: CanvasItem = null
var _original_modulate: Color = Color.WHITE


func _init() -> void:
	ability_name = "Prismatic Stillness"
	input_action = "ability"
	cooldown_duration = 10.0


func _ready() -> void:
	super._ready()
	_visual = player.get_node_or_null("Sprite2D") as CanvasItem
	if _visual != null:
		_original_modulate = _visual.modulate


func _process(delta: float) -> void:
	super._process(delta)

	if not is_active:
		return

	elapsed += delta
	player.velocity = Vector2.ZERO

	if elapsed >= duration:
		_finish_stillness()


func _execute() -> void:
	is_active = true
	elapsed = 0.0
	player.velocity = Vector2.ZERO
	_set_visual(true)


func blocks_movement() -> bool:
	return is_active


func blocks_gameplay_input() -> bool:
	return is_active


func grants_invulnerability() -> bool:
	return is_active


func _finish_stillness() -> void:
	if not is_active:
		return

	is_active = false
	player.velocity = Vector2.ZERO
	_set_visual(false)

	if multiplayer.is_server():
		player._restore_mana.rpc(mana_restore)

	ability_ended.emit()


func _set_visual(active: bool) -> void:
	if _visual == null:
		return

	if not active:
		_visual.modulate = _original_modulate
		return

	var still_color := Color(0.82, 0.91, 1.0, active_opacity)
	_visual.modulate = _original_modulate * still_color
