extends Resource
class_name PlaytestRules

## All first-rework tuning lives here. Existing character presets are untouched.
enum Preset { BASELINE, VISION_DUEL, TEAM_OBJECTIVE }
@export var preset: Preset = Preset.BASELINE
@export var limited_vision: bool = true
@export var sight_radius: float = 500.0
@export var magic_sight_radius: float = 180.0
@export var score_to_win: float = 60.0
@export var objective_delay: float = 15.0
@export var time_limit: float = 480.0
@export var respawn_delay: float = 5.0
@export var protection_duration: float = 1.0
@export var recovery_rate: float = 20.0
@export var recovery_damage_delay: float = 3.0

func player_count() -> int:
	return 4 if preset == Preset.TEAM_OBJECTIVE else 2

static func score_owner(occupants: Array) -> int:
	if occupants.has(0) and not occupants.has(1):
		return 0
	if occupants.has(1) and not occupants.has(0):
		return 1
	return -1
