extends Node

const TELEMETRY_DIR := "user://telemetry"
const EVENTS_PATH := TELEMETRY_DIR + "/events.jsonl"
const ID_PATH := TELEMETRY_DIR + "/anonymous_install_id.txt"
const SESSION_COUNT_PATH := TELEMETRY_DIR + "/session_count.txt"
const OUTBOX_PATH := TELEMETRY_DIR + "/posthog_outbox.json"

# Replace with the project token from PostHog Project Settings.
# Use https://eu.i.posthog.com if the PostHog project is in the EU region.
const POSTHOG_PROJECT_TOKEN := "phc_nPaiAZZf8KVBFzU6pHLLu5fRtmC9f8q62mgtZA3ccSXd"
const POSTHOG_HOST := "https://us.i.posthog.com"
const POSTHOG_BATCH_SIZE := 25
const POSTHOG_FLUSH_SECONDS := 15.0
const SCHEMA_VERSION := 2

# Sparse checkpoints make first-session length measurable even if the game is
# force-closed before session_ended can be sent.
const FIRST_SESSION_CHECKPOINTS_SECONDS := [
	300,   # 5 min
	600,   # 10 min
	900,   # 15 min
	1200,  # 20 min
	1800,  # 30 min
	2700,  # 45 min
	3600,  # 60 min
]

var enabled: bool = true
var install_id: String = ""
var session_id: String = ""
var session_number: int = 0
var is_first_session: bool = false
var session_started_unix: int = 0

var current_match_id: String = ""
var current_match_mode: String = ""
var current_match_started_msec: int = 0
var duel_number: int = 0
var last_match_report: Dictionary = {}

var _match_context: Dictionary = {}
var _player_match_stats: Dictionary = {}
var _ability_match_stats: Dictionary = {}

var _focused := true
var _engaged_msec := 0
var _focus_started_msec := 0
var _session_end_tracked := false
var _reached_checkpoints := {}
var _matchmaking_started_msec := 0

var _outbox: Array = []
var _http_request: HTTPRequest
var _flush_timer: Timer
var _checkpoint_timer: Timer
var _request_in_progress := false
var _in_flight_count := 0


func _ready() -> void:
	_ensure_directory()
	install_id = _load_or_create_install_id()
	session_number = _increment_session_count()
	is_first_session = session_number == 1
	session_id = _generate_id()
	session_started_unix = int(Time.get_unix_time_from_system())
	_focus_started_msec = Time.get_ticks_msec()

	_load_outbox()
	_setup_http()
	_setup_timers()

	track("session_started")
	call_deferred("flush")


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			_commit_engaged_time()
			_focused = false
			flush()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			_focused = true
			_focus_started_msec = Time.get_ticks_msec()
		NOTIFICATION_WM_CLOSE_REQUEST:
			_end_session("window_closed")
			flush()


func _exit_tree() -> void:
	_end_session("application_exit")


func track(event_name: String, properties: Dictionary = {}) -> void:
	if not enabled or event_name.strip_edges().is_empty():
		return

	var event_properties := properties.duplicate(true)

	# Start queue timing from the existing title-screen event so no extra
	# instrumentation is required there.
	if event_name == "matchmaking_entered":
		_matchmaking_started_msec = Time.get_ticks_msec()
	elif event_name in ["matchmaking_connection_failed", "matchmaking_cancelled"]:
		_attach_and_clear_queue_duration(event_properties)

	var base := _base_properties()
	for key in event_properties:
		base[key] = event_properties[key]

	var payload := {
		"event": event_name,
		"timestamp": _utc_timestamp(),
		"properties": base,
	}

	_append_event(payload)

	if _posthog_configured():
		_outbox.append(payload)
		_save_outbox()
		if _outbox.size() >= POSTHOG_BATCH_SIZE:
			flush()


func mark_matchmaking_connected(role: String) -> void:
	# Only report quick-match waits that began with matchmaking_entered.
	if _matchmaking_started_msec <= 0:
		return

	var properties := {"role": role}
	_attach_and_clear_queue_duration(properties)
	track("matchmaking_connected", properties)


func start_match(mode: String, properties: Dictionary = {}) -> void:
	current_match_id = _generate_id()
	current_match_mode = mode
	current_match_started_msec = Time.get_ticks_msec()
	_match_context = properties.duplicate(true)
	_player_match_stats.clear()
	_ability_match_stats.clear()
	last_match_report = {}

	if mode != "tutorial":
		duel_number += 1

	var match_properties := properties.duplicate(true)
	match_properties["match_id"] = current_match_id
	match_properties["mode"] = mode
	match_properties["duel_number"] = duel_number
	track("match_started", match_properties)


func register_match_player(player_id: int, character: String) -> void:
	if current_match_id.is_empty() or player_id < 0:
		return
	var stats := _get_player_stats(player_id)
	stats["character"] = character
	_player_match_stats[player_id] = stats


func record_ability_cast(player_id: int, ability: String) -> void:
	if current_match_id.is_empty() or player_id < 0 or ability.is_empty():
		return
	_get_ability_stats(player_id, ability)["casts"] += 1


func record_kill(winner_player_id: int, defeated_player_id: int) -> void:
	if current_match_id.is_empty():
		return
	if winner_player_id >= 0:
		_get_player_stats(winner_player_id)["kills"] += 1
	if defeated_player_id >= 0:
		_get_player_stats(defeated_player_id)["deaths"] += 1


func record_damage(
	source_player_id: int,
	target_player_id: int,
	amount: float,
	ability: String = ""
) -> void:
	if current_match_id.is_empty() or amount <= 0.0:
		return

	var target := _get_player_stats(target_player_id)
	target["damage_taken"] += amount

	if source_player_id >= 0:
		var source := _get_player_stats(source_player_id)
		source["damage_dealt"] += amount
		if not ability.is_empty():
			var ability_stats := _get_ability_stats(source_player_id, ability)
			ability_stats["hits"] += 1
			ability_stats["damage_dealt"] += amount


func record_heal(source_player_id: int, amount: float, ability: String = "") -> void:
	if current_match_id.is_empty() or source_player_id < 0 or amount <= 0.0:
		return
	var source := _get_player_stats(source_player_id)
	source["healing_done"] += amount
	if not ability.is_empty():
		var ability_stats := _get_ability_stats(source_player_id, ability)
		ability_stats["healing_done"] += amount


func record_mana_spent(player_id: int, amount: float) -> void:
	if current_match_id.is_empty() or amount <= 0.0:
		return
	_get_player_stats(player_id)["mana_spent"] += amount


func record_magic_placed(player_id: int, ability: String) -> void:
	if current_match_id.is_empty():
		return
	_get_player_stats(player_id)["magic_placed"] += 1
	if not ability.is_empty():
		_get_ability_stats(player_id, ability)["placements"] += 1


func record_magic_transformed(player_id: int, ability: String) -> void:
	if current_match_id.is_empty():
		return
	_get_player_stats(player_id)["magic_transformed"] += 1
	if not ability.is_empty():
		_get_ability_stats(player_id, ability)["transforms"] += 1


func record_magic_fired(player_id: int, ability: String) -> void:
	if current_match_id.is_empty():
		return
	_get_player_stats(player_id)["magic_fired"] += 1
	if not ability.is_empty():
		_get_ability_stats(player_id, ability)["casts"] += 1


func record_cc(
	source_player_id: int,
	target_player_id: int,
	duration: float,
	ability: String = ""
) -> void:
	if current_match_id.is_empty() or duration <= 0.0:
		return
	_get_player_stats(target_player_id)["cc_received_seconds"] += duration
	if source_player_id >= 0:
		_get_player_stats(source_player_id)["cc_inflicted_seconds"] += duration
		if not ability.is_empty():
			_get_ability_stats(source_player_id, ability)["cc_seconds"] += duration


func record_damage_blocked(
	player_id: int,
	amount: float,
	ability: String = ""
) -> void:
	if current_match_id.is_empty() or amount <= 0.0:
		return
	_get_player_stats(player_id)["damage_blocked"] += amount
	if not ability.is_empty():
		_get_ability_stats(player_id, ability)["damage_blocked"] += amount


func end_match(properties: Dictionary = {}) -> void:
	if current_match_id.is_empty():
		return

	var match_properties := properties.duplicate(true)
	var winner_player_id := int(match_properties.get("winner_player_id", -1))
	match_properties.erase("winner_player_id")

	for key in _match_context:
		if not match_properties.has(key):
			match_properties[key] = _match_context[key]

	var local_id := multiplayer.get_unique_id()
	var opponent_id := _find_opponent_id(local_id)
	var local_stats := _get_player_stats(local_id).duplicate(true)
	var opponent_stats := (
		_get_player_stats(opponent_id).duplicate(true)
		if opponent_id >= 0
		else {}
	)

	_append_stats(match_properties, local_stats, "")
	if not opponent_stats.is_empty():
		_append_stats(match_properties, opponent_stats, "opponent_")

	if winner_player_id >= 0 and _player_match_stats.has(winner_player_id):
		match_properties["winner_character"] = str(
			_get_player_stats(winner_player_id).get("character", "")
		)

	match_properties["match_id"] = current_match_id
	match_properties["mode"] = current_match_mode
	match_properties["duel_number"] = duel_number
	match_properties["match_duration_seconds"] = maxf(
		0.0,
		float(Time.get_ticks_msec() - current_match_started_msec) / 1000.0
	)

	_emit_local_ability_summaries(local_id, str(match_properties.get("result", "")))

	last_match_report = {
		"result": str(match_properties.get("result", "")),
		"winner_character": str(match_properties.get("winner_character", "")),
		"match_duration_seconds": match_properties["match_duration_seconds"],
		"local": local_stats,
		"opponent": opponent_stats,
	}

	track("match_ended", match_properties)

	current_match_id = ""
	current_match_mode = ""
	current_match_started_msec = 0
	_match_context.clear()
	_player_match_stats.clear()
	_ability_match_stats.clear()
	flush()


func _get_player_stats(player_id: int) -> Dictionary:
	if not _player_match_stats.has(player_id):
		_player_match_stats[player_id] = {
			"character": "",
			"kills": 0,
			"deaths": 0,
			"damage_dealt": 0.0,
			"damage_taken": 0.0,
			"healing_done": 0.0,
			"damage_blocked": 0.0,
			"mana_spent": 0.0,
			"magic_placed": 0,
			"magic_transformed": 0,
			"magic_fired": 0,
			"cc_inflicted_seconds": 0.0,
			"cc_received_seconds": 0.0,
		}
	return _player_match_stats[player_id]


func _get_ability_stats(player_id: int, ability: String) -> Dictionary:
	if not _ability_match_stats.has(player_id):
		_ability_match_stats[player_id] = {}
	var player_abilities: Dictionary = _ability_match_stats[player_id]
	if not player_abilities.has(ability):
		player_abilities[ability] = {
			"placements": 0,
			"transforms": 0,
			"casts": 0,
			"hits": 0,
			"damage_dealt": 0.0,
			"healing_done": 0.0,
			"damage_blocked": 0.0,
			"cc_seconds": 0.0,
		}
	return player_abilities[ability]


func _find_opponent_id(local_id: int) -> int:
	for player_id in _player_match_stats:
		if int(player_id) != local_id:
			return int(player_id)
	return -1


func _append_stats(target: Dictionary, stats: Dictionary, prefix: String) -> void:
	for key in stats:
		target[prefix + str(key)] = stats[key]


func _emit_local_ability_summaries(player_id: int, result: String) -> void:
	if not _ability_match_stats.has(player_id):
		return
	var character := str(_get_player_stats(player_id).get("character", ""))
	for ability in _ability_match_stats[player_id]:
		var stats: Dictionary = _ability_match_stats[player_id][ability]
		var properties := stats.duplicate(true)
		properties["match_id"] = current_match_id
		properties["mode"] = current_match_mode
		properties["duel_number"] = duel_number
		properties["character"] = character
		properties["ability"] = ability
		properties["result"] = result
		track("ability_match_summary", properties)


func get_events_path() -> String:
	return ProjectSettings.globalize_path(EVENTS_PATH)


func flush() -> void:
	if (
		not enabled
		or not _posthog_configured()
		or _request_in_progress
		or _outbox.is_empty()
		or _http_request == null
	):
		return

	_in_flight_count = mini(POSTHOG_BATCH_SIZE, _outbox.size())
	var batch: Array = []
	for index in range(_in_flight_count):
		batch.append(_outbox[index])

	var payload := {
		"api_key": POSTHOG_PROJECT_TOKEN,
		"historical_migration": false,
		"batch": batch,
	}
	var headers := PackedStringArray(["Content-Type: application/json"])
	var error := _http_request.request(
		POSTHOG_HOST + "/batch/",
		headers,
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)

	if error == OK:
		_request_in_progress = true
	else:
		_in_flight_count = 0
		push_warning("PostHog request could not start: %s" % error_string(error))


func _on_posthog_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	_body: PackedByteArray
) -> void:
	_request_in_progress = false
	var success := (
		result == HTTPRequest.RESULT_SUCCESS
		and response_code >= 200
		and response_code < 300
	)

	if success:
		for _index in range(_in_flight_count):
			if not _outbox.is_empty():
				_outbox.pop_front()
		_save_outbox()
	else:
		push_warning(
			"PostHog upload failed (result=%s, HTTP=%s). Events remain queued."
			% [result, response_code]
		)

	_in_flight_count = 0
	if _outbox.size() >= POSTHOG_BATCH_SIZE:
		call_deferred("flush")


func _base_properties() -> Dictionary:
	return {
		"distinct_id": install_id,
		"$process_person_profile": false,
		"anonymous_install_id": install_id,
		"session_id": session_id,
		"session_number": session_number,
		"is_first_session": is_first_session,
		"duel_number": duel_number,
		"session_engaged_seconds": _get_engaged_seconds(),
		"platform": OS.get_name(),
		"game_version": str(
			ProjectSettings.get_setting(
				"application/config/version",
				"dev"
			)
		),
		"build_type": "debug" if OS.is_debug_build() else "release",
		"schema_version": SCHEMA_VERSION,
		"control_scheme": GameManager.control_scheme,
		"camera_profile": GameManager.camera_profile,
		"camera_locked": GameManager.camera_locked,
	}


func _setup_http() -> void:
	_http_request = HTTPRequest.new()
	add_child(_http_request)
	_http_request.request_completed.connect(_on_posthog_request_completed)


func _setup_timers() -> void:
	_flush_timer = Timer.new()
	_flush_timer.wait_time = POSTHOG_FLUSH_SECONDS
	_flush_timer.one_shot = false
	_flush_timer.autostart = true
	add_child(_flush_timer)
	_flush_timer.timeout.connect(flush)

	_checkpoint_timer = Timer.new()
	_checkpoint_timer.wait_time = 5.0
	_checkpoint_timer.one_shot = false
	_checkpoint_timer.autostart = true
	add_child(_checkpoint_timer)
	_checkpoint_timer.timeout.connect(_check_first_session_checkpoints)


func _check_first_session_checkpoints() -> void:
	if not is_first_session or _session_end_tracked:
		return

	var engaged_seconds := _get_engaged_seconds()
	for threshold in FIRST_SESSION_CHECKPOINTS_SECONDS:
		if engaged_seconds < float(threshold):
			continue
		if _reached_checkpoints.get(threshold, false):
			continue

		_reached_checkpoints[threshold] = true
		track("first_session_time_reached", {
			"minutes": int(threshold / 60),
			"duel_number": duel_number,
		})


func _end_session(reason: String) -> void:
	if _session_end_tracked or install_id.is_empty():
		return

	_commit_engaged_time()
	_session_end_tracked = true
	track("session_ended", {
		"end_reason": reason,
		"session_length_seconds": maxi(
			0,
			int(Time.get_unix_time_from_system()) - session_started_unix
		),
		"engaged_seconds": float(_engaged_msec) / 1000.0,
		"duels_started": duel_number,
	})


func _commit_engaged_time() -> void:
	if not _focused:
		return

	var now := Time.get_ticks_msec()
	_engaged_msec += maxi(0, now - _focus_started_msec)
	_focus_started_msec = now


func _get_engaged_seconds() -> float:
	var total := _engaged_msec
	if _focused:
		total += maxi(0, Time.get_ticks_msec() - _focus_started_msec)
	return float(total) / 1000.0


func _attach_and_clear_queue_duration(properties: Dictionary) -> void:
	if _matchmaking_started_msec <= 0:
		return

	properties["queue_duration_seconds"] = maxf(
		0.0,
		float(Time.get_ticks_msec() - _matchmaking_started_msec) / 1000.0
	)
	_matchmaking_started_msec = 0


func _append_event(payload: Dictionary) -> void:
	_ensure_directory()
	var file := FileAccess.open(EVENTS_PATH, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(EVENTS_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Telemetry could not open %s" % EVENTS_PATH)
		return

	file.seek_end()
	file.store_line(JSON.stringify(payload))
	file.close()


func _load_outbox() -> void:
	if not FileAccess.file_exists(OUTBOX_PATH):
		return

	var file := FileAccess.open(OUTBOX_PATH, FileAccess.READ)
	if file == null:
		return

	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if parsed is Array:
		_outbox = parsed


func _save_outbox() -> void:
	_ensure_directory()
	var file := FileAccess.open(OUTBOX_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Telemetry could not save PostHog outbox.")
		return
	file.store_string(JSON.stringify(_outbox))
	file.close()


func _ensure_directory() -> void:
	var absolute_path := ProjectSettings.globalize_path(TELEMETRY_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_path)


func _load_or_create_install_id() -> String:
	if FileAccess.file_exists(ID_PATH):
		var existing_file := FileAccess.open(ID_PATH, FileAccess.READ)
		if existing_file != null:
			var existing_id := existing_file.get_as_text().strip_edges()
			existing_file.close()
			if not existing_id.is_empty():
				return existing_id

	var new_id := _generate_id()
	var file := FileAccess.open(ID_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(new_id)
		file.close()
	return new_id


func _increment_session_count() -> int:
	var count := 0
	if FileAccess.file_exists(SESSION_COUNT_PATH):
		var read_file := FileAccess.open(SESSION_COUNT_PATH, FileAccess.READ)
		if read_file != null:
			count = int(read_file.get_as_text().strip_edges())
			read_file.close()
	elif FileAccess.file_exists(EVENTS_PATH):
		# Migration from the existing local-only telemetry system: an install
		# with prior events should not suddenly be classified as a new player.
		count = 1

	count += 1
	var write_file := FileAccess.open(SESSION_COUNT_PATH, FileAccess.WRITE)
	if write_file != null:
		write_file.store_string(str(count))
		write_file.close()
	return count


func _posthog_configured() -> bool:
	return (
		not POSTHOG_PROJECT_TOKEN.is_empty()
		and POSTHOG_PROJECT_TOKEN != "phc_REPLACE_ME"
	)


func _utc_timestamp() -> String:
	return Time.get_datetime_string_from_system(true, false) + "Z"


func _generate_id() -> String:
	var crypto := Crypto.new()
	return crypto.generate_random_bytes(16).hex_encode()
