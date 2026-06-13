

extends Resource
class_name CharacterStats

@export var max_health: float = 100.0
@export var max_mana: float = 100.0
@export var mana_regen_rate: float = 5.0  # /second

@export var base_speed: float = 250.

@export var radius_cells: Array[Vector2i]


@export var magics: Dictionary[Magic.MagicType, MagicStats] = {
	Magic.MagicType.NEUTRAL: null,
	Magic.MagicType.LIGHT: null,
	Magic.MagicType.HEAVY: null,
	Magic.MagicType.PASSIVE: null
}
