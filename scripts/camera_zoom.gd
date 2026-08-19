extends Camera2D

@export var league_zoom: float = 1.0

var other_player: Node2D
var this_player: Node2D
var camera_ready := false
var camera_locked := true
var _dragging := false


func _ready() -> void:
	await _wait_for_players()
	if camera_ready:
		make_current()


func configure_players(local_player: Node2D, opponent_player: Node2D = null) -> void:
	this_player = local_player
	other_player = opponent_player
	camera_ready = this_player != null
	camera_locked = true
	GameManager.camera_locked = true

	if camera_ready:
		global_position = this_player.global_position
		make_current()


func _wait_for_players() -> void:
	var current_scene := get_tree().get_current_scene()
	var players_node := current_scene.get_node_or_null("Players")
	if players_node == null:
		return

	while not camera_ready:
		if multiplayer == null:
			return

		var local_player := players_node.get_node_or_null(
			str(multiplayer.get_unique_id())
		) as Node2D
		var found_opponent: Node2D = null

		if local_player != null:
			for child in players_node.get_children():
				var player_node := child as Node2D
				if player_node != null and player_node != local_player:
					found_opponent = player_node
					break

		if local_player != null and found_opponent != null:
			configure_players(local_player, found_opponent)
			break

		await get_tree().process_frame

	var hud := current_scene.get_node_or_null("HUD")
	if hud != null and hud.has_method("connect_to_players"):
		hud.call("connect_to_players", this_player, other_player)


func _unhandled_input(event: InputEvent) -> void:
	if not camera_ready or GameManager.camera_profile != GameManager.CAMERA_PROFILE_LEAGUE:
		_dragging = false
		return

	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		var key := key_event.physical_keycode
		if key == 0:
			key = key_event.keycode
		if key == KEY_Y:
			camera_locked = not camera_locked
			GameManager.camera_locked = camera_locked
			_dragging = false
			if camera_locked and is_instance_valid(this_player):
				global_position = this_player.global_position
			Telemetry.track("camera_lock_changed", {"locked": camera_locked})
			return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_MIDDLE and not camera_locked:
			_dragging = mouse_event.pressed
	elif event is InputEventMouseMotion and _dragging and not camera_locked:
		var motion := event as InputEventMouseMotion
		global_position -= motion.relative / maxf(zoom.x, 0.01)


func _process(delta: float) -> void:
	if not camera_ready or not is_instance_valid(this_player):
		return

	if GameManager.camera_profile == GameManager.CAMERA_PROFILE_LEAGUE:
		_process_league_camera(delta)
	else:
		_process_legacy_camera(delta)


func _process_league_camera(delta: float) -> void:
	if camera_locked:
		global_position = this_player.global_position

	var target_zoom := Vector2.ONE * league_zoom
	zoom = zoom.lerp(target_zoom, clampf(delta * 6.0, 0.0, 1.0))


func _process_legacy_camera(delta: float) -> void:
	camera_locked = true
	GameManager.camera_locked = true
	global_position = this_player.global_position

	if not is_instance_valid(other_player):
		return

	var screen_size := get_viewport_rect().size
	var dist_vec := other_player.global_position - this_player.global_position
	var dist_ratio := 2.0 * dist_vec.length() / screen_size.length()
	var upper_bound := 0.8
	var lower_bound := 0.6

	var new_zoom := 4.0 / 3.0
	if dist_ratio > lower_bound:
		new_zoom = maxf(0.73, 1.0 / (dist_ratio / upper_bound))

	zoom = Vector2.ONE * lerpf(
		zoom.x,
		new_zoom,
		clampf(delta, 0.0, 1.0)
	)
