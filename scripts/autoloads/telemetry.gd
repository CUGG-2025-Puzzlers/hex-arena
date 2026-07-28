extends Node

const TELEMETRY_DIR := "user://telemetry"
const EVENTS_PATH := TELEMETRY_DIR + "/events.jsonl"
const ID_PATH := TELEMETRY_DIR + "/anonymous_install_id.txt"

var enabled: bool = true
var install_id: String = ""
var session_id: String = ""
var session_started_unix: int = 0
var current_match_id: String = ""
var current_match_mode: String = ""
var current_match_started_msec: int = 0


func _ready() -> void:
	_ensure_directory()
	install_id = _load_or_create_install_id()
	session_id = _generate_id()
	session_started_unix = int(Time.get_unix_time_from_system())
	track("session_started", {
		"platform": OS.get_name(),
		"game_version": str(
			ProjectSettings.get_setting(
				"application/config/version",
				"dev"
			)
		),
	})


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		track("session_ended", {
			"session_length_seconds": maxi(
				0,
				int(Time.get_unix_time_from_system())
				- session_started_unix
			)
		})


func track(event_name: String, properties: Dictionary = {}) -> void:
	if not enabled or event_name.strip_edges().is_empty():
		return

	var payload := {
		"event": event_name,
		"timestamp_unix": int(Time.get_unix_time_from_system()),
		"timestamp_utc": Time.get_datetime_string_from_system(true),
		"anonymous_install_id": install_id,
		"session_id": session_id,
		"platform": OS.get_name(),
		"properties": properties.duplicate(true),
	}

	_append_event(payload)


func start_match(mode: String, properties: Dictionary = {}) -> void:
	current_match_id = _generate_id()
	current_match_mode = mode
	current_match_started_msec = Time.get_ticks_msec()

	var match_properties := properties.duplicate(true)
	match_properties["match_id"] = current_match_id
	match_properties["mode"] = mode
	track("match_started", match_properties)


func end_match(properties: Dictionary = {}) -> void:
	if current_match_id.is_empty():
		return

	var match_properties := properties.duplicate(true)
	match_properties["match_id"] = current_match_id
	match_properties["mode"] = current_match_mode
	match_properties["match_duration_seconds"] = maxf(
		0.0,
		float(Time.get_ticks_msec() - current_match_started_msec) / 1000.0
	)
	track("match_ended", match_properties)

	current_match_id = ""
	current_match_mode = ""
	current_match_started_msec = 0


func get_events_path() -> String:
	return ProjectSettings.globalize_path(EVENTS_PATH)


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


func _generate_id() -> String:
	var crypto := Crypto.new()
	return crypto.generate_random_bytes(16).hex_encode()
