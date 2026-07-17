

extends Resource
class_name CharacterStats

@export_group("Health and Mana")
@export var max_health: float = 100.0
@export var max_mana: float = 100.0
@export var mana_regen_rate: float = 5.0  # /second

@export_group("Speed")
@export var base_speed: float = 250.

@export_group("Range")
@export var radius_cells: Array[Vector2i]

@export_group("Magic")
@export var magics: Dictionary[Magic.MagicType, MagicStats] = {
	Magic.MagicType.NEUTRAL: null,
	Magic.MagicType.LIGHT: null,
	Magic.MagicType.HEAVY: null,
	Magic.MagicType.PASSIVE: null
}
@export var default_state_to_place: Magic.MagicType = Magic.MagicType.NEUTRAL
