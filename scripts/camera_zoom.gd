extends Camera2D

var other_player : Node2D
var this_player : Node2D
var camera_ready := false


func _ready() -> void:
	await _wait_for_players()
	camera_ready = true


func _wait_for_players() -> void:
	var current_scene = get_tree().get_current_scene()
	var players_node = current_scene.get_node("Players")

	while true:
		this_player = players_node.get_node_or_null(str(multiplayer.get_unique_id())) as Node2D
		other_player = null

		if this_player != null:
			for child in players_node.get_children():
				var player_node := child as Node2D
				if player_node != null and player_node != this_player:
					other_player = player_node
					break

		if this_player != null and other_player != null:
			break

		await get_tree().process_frame

	# Move camera under the local player only after the player exists.
	reparent(this_player)
	position = Vector2.ZERO
	make_current()


func _process(delta: float) -> void:
	if not camera_ready:
		return

	if this_player == null or other_player == null:
		return

	if not is_instance_valid(this_player) or not is_instance_valid(other_player):
		return
	
	var screen_size : Vector2 = get_viewport_rect().size
	
	var dist_vec = other_player.global_position - this_player.global_position

	var dist_ratio : float = 2.0 * dist_vec.length() / screen_size.length()
	
	"""
	var angle = fposmod(rad_to_deg(dist_vec.angle()),90)
	if angle<30:
		dist_ratio = 2*abs(dist_vec.x)/screen_size.x
	elif angle>60:
		dist_ratio = 2*abs(dist_vec.y)/screen_size.x
		
		if abs(dist_vec.y)>abs(dist_vec.x):
			dist_ratio = 2*abs(dist_vec.y)/screen_size.y
		else:
			dist_ratio = 2*abs(dist_vec.x)/screen_size.x
		"""
	
	var upper_bound : float = 0.8
	var lower_bound : float = 0.6
	
	var new_zoom : float = 4.0 / 3.0
	if dist_ratio > lower_bound:
		new_zoom = max(0.73, 1.0 / (dist_ratio / upper_bound))

	#if abs(zoom.x-new_zoom)>0.005:
	#	HexCells.player_unique_instance.queue_redraw()

	zoom = Vector2.ONE * ((new_zoom - zoom.x) * delta + zoom.x)
	
	# FOR NOW, LATER RENDER AND SAVE AS TEXTURE
	# HexCells.player_unique_instance.queue_redraw()
