extends RefCounted
class_name ControlPointState

## Ownership and round percentage are separate. Occupancy captures ownership;
## the owner keeps earning percentage when the point is empty or contested.
var owner: int = -1
var capture_team: int = -1
var capture_progress: float = 0.0
var percentages: Array[float] = [0.0, 0.0]
var overtime: bool = false
var overtime_elapsed: float = 0.0
var overtime_remaining: float = 0.0
var touch_age: Array[float] = [999.0, 999.0]
var capture_idle: float = 0.0
var winner: int = -1

var capture_seconds: float = 8.0
var percent_per_second: float = 100.0 / 120.0
var recent_touch_seconds: float = 3.0
var capture_decay_delay: float = 2.0

func reset() -> void:
	owner = -1
	capture_team = -1
	capture_progress = 0.0
	percentages.assign([0.0, 0.0])
	overtime = false
	overtime_elapsed = 0.0
	overtime_remaining = 0.0
	touch_age.assign([999.0, 999.0])
	capture_idle = 0.0
	winner = -1

func tick(delta: float, counts: Array[int]) -> int:
	# Bound integration steps so capture/99%/overtime transitions remain correct
	# during a long frame and deterministic in the rule tests.
	var remaining := maxf(delta, 0.0)
	while remaining > 0.000001 and winner < 0:
		var step := minf(remaining, 0.1)
		_step(step, counts)
		remaining -= step
	return winner

func _step(delta: float, counts: Array[int]) -> void:
	for team in range(2):
		touch_age[team] = 0.0 if counts[team] > 0 else touch_age[team] + delta
	var contested := counts[0] > 0 and counts[1] > 0
	var team := 0 if counts[0] > 0 else (1 if counts[1] > 0 else -1)
	if not contested and team >= 0 and team != owner:
		capture_idle = 0.0
		var multiplier := 1.0 if counts[team] == 1 else (1.5 if counts[team] == 2 else 2.0)
		var amount := delta * multiplier / maxf(capture_seconds, 0.01)
		if capture_team != team and capture_progress > 0.0:
			var erased := minf(amount, capture_progress)
			capture_progress -= erased
			amount -= erased
		if capture_progress <= 0.000001:
			capture_team = team
		if capture_team == team:
			capture_progress += amount
		if capture_progress >= 1.0 - 0.000001:
			var previous_owner := owner
			owner = team
			capture_team = -1
			capture_progress = 0.0
			overtime = false
			overtime_elapsed = 0.0
			overtime_remaining = 0.0
			# Retaking at 99% still gives the displaced team an overtime touch window.
			if previous_owner >= 0:
				touch_age[previous_owner] = 0.0
	elif not contested:
		capture_idle += delta
		if capture_idle >= capture_decay_delay:
			capture_progress = maxf(0.0, capture_progress - delta / maxf(capture_seconds, 0.01))
			if capture_progress <= 0.0:
				capture_team = -1
	if owner < 0:
		return
	percentages[owner] = minf(100.0, percentages[owner] + delta * percent_per_second)
	var challenger := 1 - owner
	if percentages[owner] >= 99.0 and not overtime and touch_age[challenger] <= recent_touch_seconds:
		overtime = true
		overtime_elapsed = 0.0
		overtime_remaining = overtime_duration()
	if overtime:
		overtime_elapsed += delta
		if counts[challenger] > 0:
			overtime_remaining = overtime_duration()
		else:
			overtime_remaining = maxf(0.0, minf(overtime_remaining, overtime_duration()) - delta)
	if percentages[owner] >= 100.0 - 0.000001:
		percentages[owner] = 100.0
		if not overtime or (counts[challenger] == 0 and overtime_remaining <= 0.0):
			winner = owner

func overtime_duration() -> float:
	return 1.5 if overtime_elapsed >= 30.0 else (3.0 if overtime_elapsed >= 20.0 else 5.0)

func snapshot() -> Dictionary:
	return {"owner": owner, "capture_team": capture_team, "capture_progress": capture_progress,
		"percentages": percentages.duplicate(), "overtime": overtime, "overtime_elapsed": overtime_elapsed,
		"overtime_remaining": overtime_remaining, "winner": winner}

func load_snapshot(data: Dictionary) -> void:
	owner = int(data.owner)
	capture_team = int(data.capture_team)
	capture_progress = float(data.capture_progress)
	percentages.assign(data.percentages)
	overtime = bool(data.overtime)
	overtime_elapsed = float(data.overtime_elapsed)
	overtime_remaining = float(data.overtime_remaining)
	winner = int(data.winner)
