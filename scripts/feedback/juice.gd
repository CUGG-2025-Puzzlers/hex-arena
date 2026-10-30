extends Node

## Local presentation only. Gameplay remains in the existing authoritative handlers.
signal presented(event: Dictionary)
signal settings_visibility_changed

const WORLD_EFFECT := preload("res://scripts/feedback/world_effect.gd")
const READABILITY := preload("res://scripts/feedback/combat_readability.gd")
const MAX_EFFECTS := 48
const MAX_VOICES := 8
const PRIORITY := {"place": 1, "transform": 2, "launch": 2, "hit": 4, "hurt": 5, "danger": 7, "control": 5, "block": 3, "break": 6, "heal": 2, "ready": 3, "ability": 3, "denied": 2, "elimination": 8, "objective": 8, "ui": 0, "ui_accept": 1, "success": 4, "root": 5, "silence": 5, "wall": 3, "spell": 2, "depart": 3, "arrive": 3, "interrupted": 4, "expired": 1, "completed": 1, "lost_target": 2, "overtime_tick": 2}
const COLORS := {"place": Color("8cddff"), "transform": Color("c7a3ff"), "launch": Color("e6f6ff"), "hit": Color("fff0bd"), "block": Color("91e9ee"), "break": Color("ffcb83"), "heal": Color("91e1b2"), "ready": Color("8cddff"), "ability": Color("c7a3ff"), "root": Color("e6bf96"), "silence": Color("d3baff"), "wall": Color("cabfae"), "spell": Color("b9d6ff"), "depart": Color("9adeee"), "arrive": Color("9adeee"), "stride": Color("b4c9ce"), "stop": Color("b4c9ce"), "expired": Color("b6c5ce"), "completed": Color("b9ddcb"), "interrupted": Color("e5b4a1"), "lost_target": Color("d8c69d")}

var intensity: float = 0.75
var sound_gain: float = 0.5
var reduced_flashes: bool = false
var settings_open: bool = false
var audio_enabled: bool = true
var _scene_id: int = 0
var _effects: Array[WeakRef] = []
var _voices: Array[Dictionary] = []
var _pending: Array[Dictionary] = []
var _last: Dictionary = {}
var _streams: Dictionary = {}
var _readability: Node2D
var _dialog: AcceptDialog

func _ready() -> void:
	_load_preferences()
	audio_enabled = DisplayServer.get_name() != "headless"
	get_tree().node_added.connect(_node_added)

func _process(delta: float) -> void:
	_sync_scene()
	if not is_instance_valid(_readability):
		var scene := get_tree().current_scene
		if is_instance_valid(scene) and scene.has_node("Players"):
			_readability = READABILITY.new()
			scene.add_child(_readability)
	_effects = _effects.filter(func(ref: WeakRef): return is_instance_valid(ref.get_ref()) and not ref.get_ref().is_queued_for_deletion())
	_voices = _voices.filter(func(voice: Dictionary): return is_instance_valid(voice.node) and voice.node.playing)
	_pending.sort_custom(func(a: Dictionary, b: Dictionary): return a.score > b.score)
	# At most four new accents per rendered frame. Existing voices have a hard cap.
	for cue_data in _pending.slice(0, 4):
		_play(cue_data)
	_pending.clear()
	var highest := 0.0
	for voice in _voices:
		highest = maxf(highest, voice.score)
	for voice in _voices:
		var duck := 0.45 if highest > voice.score + 2.5 else 1.0
		var target_db := float(voice.base_db) + linear_to_db(duck)
		voice.node.volume_db = lerpf(voice.node.volume_db, target_db, minf(delta * 30.0, 1.0))

func _sync_scene() -> void:
	var scene := get_tree().current_scene
	var next_id := scene.get_instance_id() if is_instance_valid(scene) else 0
	if next_id != _scene_id:
		clear_transients()
		_scene_id = next_id
		if is_instance_valid(_readability):
			_readability.queue_free()
		_readability = null

func local_id() -> int:
	return multiplayer.get_unique_id()

func visible_at(point: Vector2, owner_id: int) -> bool:
	return not Overhaul.active() or Overhaul.local_friendly(owner_id) or Overhaul.can_see(point)

func world(kind: String, point: Vector2, owner_id: int, direction: Vector2 = Vector2.ZERO, strength: float = 1.0) -> void:
	_sync_scene()
	if not point.is_finite() or not visible_at(point, owner_id):
		return
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return
	if intensity > 0.0 and _reserve_effect(kind):
		var effect := WORLD_EFFECT.new()
		effect.kind = kind
		effect.owner_id = owner_id
		effect.direction = direction.normalized()
		effect.tint = COLORS.get(kind, Color.WHITE)
		effect.strength = clampf(strength, 0.35, 1.5)
		effect.intensity = intensity
		effect.reduced_flashes = reduced_flashes
		scene.add_child(effect)
		effect.global_position = point
		_effects.append(weakref(effect))
	if kind not in ["stride", "stop", "expired", "completed"]:
		queue_sound(kind, point, owner_id)

func _reserve_effect(kind: String) -> bool:
	_effects = _effects.filter(func(ref: WeakRef): return is_instance_valid(ref.get_ref()) and not ref.get_ref().is_queued_for_deletion())
	if _effects.size() < MAX_EFFECTS:
		return true
	var weakest := 0
	for i in range(_effects.size()):
		if int(PRIORITY.get(_effects[i].get_ref().kind, 0)) < int(PRIORITY.get(_effects[weakest].get_ref().kind, 0)):
			weakest = i
	if int(PRIORITY.get(kind, 1)) <= int(PRIORITY.get(_effects[weakest].get_ref().kind, 0)):
		return false
	_effects[weakest].get_ref().queue_free()
	_effects.remove_at(weakest)
	return true

func trail(projectile: Node2D) -> void:
	if intensity <= 0.0 or _effects.size() >= MAX_EFFECTS or not is_instance_valid(projectile):
		return
	if not visible_at(projectile.global_position, projectile.player_id):
		return
	var effect := WORLD_EFFECT.new()
	effect.kind = "trail"
	effect.owner_id = projectile.player_id
	effect.follow = weakref(projectile)
	effect.tint = Color("b9e6f0")
	effect.intensity = intensity
	get_tree().current_scene.add_child(effect)
	_effects.append(weakref(effect))

func damage(victim: Node2D, amount: float, source_id: int, lethal: bool) -> void:
	if amount <= 0.0:
		return
	var point := victim.global_position
	world("hit", point, victim.player_id, Vector2.ZERO, clampf(amount / 35.0, 0.5, 1.5))
	var local_victim: bool = victim.player_id == local_id()
	var local_attacker: bool = source_id == local_id() and visible_at(point, victim.player_id)
	if not local_victim and not local_attacker:
		return
	var source := _player(source_id)
	var bearing := (source.global_position - point).normalized() if is_instance_valid(source) else Vector2.ZERO
	var event := {"kind": "hurt" if local_victim else "confirmed_hit", "position": point, "bearing": bearing, "amount": amount}
	presented.emit(event)
	if local_victim:
		queue_sound("hurt", point, local_id(), true)
		var maximum: float = victim.stats_update.max_health
		if not lethal and victim.stats_update.current_health > maximum * 0.25 and victim.stats_update.current_health - amount <= maximum * 0.25 and _gate("critical_health", 1.5):
			queue_sound("danger", point, local_id(), true)
	if lethal and local_attacker and source_id != victim.player_id:
		presented.emit({"kind": "elimination", "text": "ELIMINATED  " + victim.display_name.left(28)})
		queue_sound("elimination", point, local_id(), true)

func success(text: String, point: Vector2, owner_id: int) -> void:
	if owner_id == local_id() and visible_at(point, owner_id) and _gate("success:" + text, 0.4):
		presented.emit({"kind": "success", "text": text})
		queue_sound("success", point, owner_id, true)

func heal(target: Node2D, amount: float) -> void:
	if amount > 0.0 and _gate("heal:%d" % target.player_id, 0.45):
		world("heal", target.global_position, target.player_id)

func cue(kind: String, text: String = "") -> void:
	_sync_scene()
	if not _gate("cue:" + kind, 0.18):
		return
	presented.emit({"kind": kind, "text": text})
	queue_sound(kind, Vector2.ZERO, local_id(), true)

func queue_sound(kind: String, point: Vector2, owner_id: int, personal: bool = false) -> void:
	if not audio_enabled or sound_gain <= 0.0:
		return
	var player := _player(local_id())
	var distance := player.global_position.distance_to(point) if is_instance_valid(player) and not personal else 0.0
	if distance > 850.0 or (not personal and not visible_at(point, owner_id)):
		return
	var gate_key := "audio:%s:%d" % [kind, owner_id]
	if not _gate(gate_key, 0.075 if kind != "ui" else 0.10):
		return
	var priority: int = PRIORITY.get(kind, 1)
	if kind == "break":
		_pending = _pending.filter(func(cue_data: Dictionary): return cue_data.kind != "block" or cue_data.point.distance_to(point) > 1.0)
	var attenuation := 1.0 if personal else clampf(1.0 - distance / 950.0, 0.1, 1.0)
	if not personal and is_instance_valid(player) and Overhaul.active():
		if not PlaytestVisionMask.has_line_of_sight(player.global_position, point, Overhaul.get_match().walls):
			attenuation *= 0.45
	_pending.append({"kind": kind, "score": float(priority) + attenuation, "gain": attenuation, "personal": personal, "point": point})

func _play(cue_data: Dictionary) -> void:
	if _voices.size() >= MAX_VOICES:
		var weakest := 0
		for i in range(_voices.size()):
			if _voices[i].score < _voices[weakest].score:
				weakest = i
		if cue_data.score <= _voices[weakest].score:
			return
		_voices[weakest].node.queue_free()
		_voices.remove_at(weakest)
	var voice: Node = AudioStreamPlayer.new() if cue_data.personal else AudioStreamPlayer2D.new()
	voice.stream = _sound(cue_data.kind)
	voice.volume_db = linear_to_db(maxf(0.001, sound_gain * cue_data.gain * 0.16))
	add_child(voice)
	if voice is AudioStreamPlayer2D:
		voice.global_position = cue_data.point
		voice.max_distance = 850.0
		voice.panning_strength = 0.8
	voice.finished.connect(voice.queue_free)
	voice.play()
	_voices.append({"node": voice, "score": cue_data.score, "base_db": voice.volume_db})

func _sound(kind: String) -> AudioStreamWAV:
	if _streams.has(kind):
		return _streams[kind]
	# Original short synthetic accents; deterministic noise never touches gameplay RNG.
	var frequency: float = {"place": 460.0, "transform": 640.0, "launch": 240.0, "hit": 920.0, "hurt": 180.0, "danger": 190.0, "control": 300.0, "block": 350.0, "break": 135.0, "heal": 580.0, "ready": 780.0, "ability": 530.0, "denied": 160.0, "elimination": 980.0, "objective": 660.0, "ui": 510.0, "ui_accept": 700.0, "success": 840.0, "root": 280.0, "silence": 390.0, "wall": 115.0, "spell": 710.0, "depart": 320.0, "arrive": 610.0, "interrupted": 150.0, "lost_target": 210.0, "overtime_tick": 490.0}.get(kind, 440.0)
	var length := 0.22 if kind in ["elimination", "objective", "ready"] else 0.075
	var sample_rate := 22050
	var samples := int(length * sample_rate)
	var bytes := PackedByteArray()
	bytes.resize(samples * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 731
	for i in range(samples):
		var t := float(i) / sample_rate
		var p := t / length
		var envelope := minf(t / 0.003, 1.0) * pow(1.0 - p, 2.0)
		var phase := TAU * frequency * (t + t * t * (1.2 if kind in ["transform", "ready", "heal"] else -0.5))
		var value := sin(phase) * 0.7 + sin(phase * 1.5) * 0.2
		if kind in ["hit", "hurt", "block", "break", "launch", "wall", "spell"]:
			value = value * 0.65 + rng.randf_range(-0.3, 0.3) * (1.0 - p)
		bytes.encode_s16(i * 2, int(clampf(value * envelope, -1.0, 1.0) * 24500.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.data = bytes
	_streams[kind] = stream
	return stream

func _gate(key: String, interval: float) -> bool:
	var now := Time.get_ticks_msec() * 0.001
	if now - float(_last.get(key, -100.0)) < interval:
		return false
	_last[key] = now
	return true

func _player(id: int) -> Node2D:
	var scene := get_tree().current_scene
	return scene.get_node_or_null("Players/" + str(id)) as Node2D if is_instance_valid(scene) else null

func clear_transients() -> void:
	for ref in _effects:
		if is_instance_valid(ref.get_ref()):
			ref.get_ref().queue_free()
	for voice in _voices:
		if is_instance_valid(voice.node):
			voice.node.queue_free()
	_effects.clear()
	_voices.clear()
	_pending.clear()
	_last.clear()

func _node_added(node: Node) -> void:
	if node is BaseButton:
		_wire_button.call_deferred(weakref(node))

func _wire_button(ref: WeakRef) -> void:
	var button := ref.get_ref() as BaseButton
	if not is_instance_valid(button) or button.has_meta("juice_wired"):
		return
	button.set_meta("juice_wired", true)
	button.mouse_entered.connect(func():
		if not button.disabled:
			queue_sound("ui", Vector2.ZERO, local_id(), true))
	button.focus_entered.connect(func():
		if not button.disabled:
			queue_sound("ui", Vector2.ZERO, local_id(), true))
	button.pressed.connect(func(): queue_sound("ui_accept", Vector2.ZERO, local_id(), true))

func settings_button(parent: Node, point: Vector2, caption: String = "SOUND & EFFECTS") -> Button:
	var button := Button.new()
	button.name = "FeedbackSettingsButton"
	button.text = caption
	button.position = point
	button.size = Vector2(210, 42) if caption != "FX" else Vector2(48, 34)
	button.pressed.connect(open_settings)
	parent.add_child(button)
	return button

func open_settings() -> void:
	if not is_instance_valid(_dialog):
		_dialog = AcceptDialog.new()
		_dialog.title = "Sound & effects"
		_dialog.ok_button_text = "DONE"
		_dialog.min_size = Vector2i(440, 270)
		var layout := VBoxContainer.new()
		_dialog.add_child(layout)
		for entry in [["Effect intensity", "intensity"], ["Feedback volume", "sound_gain"]]:
			var label := Label.new()
			label.text = entry[0]
			layout.add_child(label)
			var slider := HSlider.new()
			slider.max_value = 1.0
			slider.step = 0.05
			slider.value = get(entry[1])
			slider.custom_minimum_size = Vector2(380, 35)
			var property: String = entry[1]
			slider.value_changed.connect(func(value: float):
				set(property, value)
				_save_preferences())
			layout.add_child(slider)
		var reduced := CheckButton.new()
		reduced.text = "Reduce impact flashes"
		reduced.button_pressed = reduced_flashes
		reduced.toggled.connect(func(value: bool):
			reduced_flashes = value
			_save_preferences())
		layout.add_child(reduced)
		_dialog.visibility_changed.connect(func():
			settings_open = _dialog.visible
			settings_visibility_changed.emit())
		add_child(_dialog)
	_dialog.popup_centered()

func _load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load("user://feedback.cfg") == OK:
		intensity = clampf(float(config.get_value("feedback", "intensity", 0.75)), 0.0, 1.0)
		sound_gain = clampf(float(config.get_value("feedback", "sound_gain", 0.5)), 0.0, 1.0)
		reduced_flashes = bool(config.get_value("feedback", "reduced_flashes", false))

func _save_preferences() -> void:
	var config := ConfigFile.new()
	config.set_value("feedback", "intensity", intensity)
	config.set_value("feedback", "sound_gain", sound_gain)
	config.set_value("feedback", "reduced_flashes", reduced_flashes)
	config.save("user://feedback.cfg")
