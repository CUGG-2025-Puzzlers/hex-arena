extends Resource
class_name PlaytestRules

## All first-rework tuning lives here. Existing character presets are untouched.
enum Preset { BASELINE, VISION_DUEL, TEAM_OBJECTIVE }
@export var preset: Preset = Preset.BASELINE
@export var limited_vision: bool = true
@export var sight_radius: float = 500.0
@export var magic_sight_radius: float = 180.0
@export var objective_delay: float = 30.0
@export var capture_seconds: float = 8.0
@export var control_percent_per_second: float = 100.0 / 120.0
@export var rounds_to_win: int = 2
@export var round_break: float = 8.0
@export var respawn_delay: float = 5.0
@export var protection_duration: float = 1.0
@export var recovery_rate: float = 20.0
@export var recovery_damage_delay: float = 3.0

func player_count() -> int:
	return 4 if preset == Preset.TEAM_OBJECTIVE else 2
