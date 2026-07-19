extends DashAbility
class_name ReformAbility

# Water Orb's distinct movement ability. It reuses DashAbility's movement curve,
# but adds temporary damage immunity and a translucent gameplay indicator.
@export_range(0.0, 1.0, 0.05) var dash_opacity: float = 0.55

var _visual: CanvasItem = null
var _original_visual_modulate: Color = Color.WHITE


func _init() -> void:
	super._init()
	ability_name = "Reform"


func _ready() -> void:
	super._ready()

	_visual = player.get_node_or_null("Sprite2D") as CanvasItem
	if _visual != null:
		_original_visual_modulate = _visual.modulate


func _execute() -> void:
	super._execute()
	_set_reform_visual(true)


func _end_dash() -> void:
	super._end_dash()
	_set_reform_visual(false)


func is_granting_invulnerability() -> bool:
	return is_dashing


func _set_reform_visual(active: bool) -> void:
	if _visual == null:
		return

	if not active:
		_visual.modulate = _original_visual_modulate
		return

	var translucent: Color = _original_visual_modulate
	translucent.a = dash_opacity
	_visual.modulate = translucent
