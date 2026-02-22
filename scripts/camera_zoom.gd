extends Camera2D

var other_player : Node2D
var this_player : Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	this_player =  get_parent()
	other_player = this_player


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if other_player == this_player:
		for player in get_parent().get_parent().get_children():
			if player!=this_player:
				other_player=player
				break
		if other_player == this_player:
			zoom = Vector2.ONE
			return
	
	
	var screen_size : Vector2 = get_viewport_rect().size
	
	var dist_vec = other_player.global_position-this_player.global_position

	var dist_ratio : float = 2.*dist_vec.length()/screen_size.length()
	
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
	
	var new_zoom : float = 4./3.
	if dist_ratio > lower_bound:
		new_zoom = max(0.73,1./(dist_ratio/upper_bound))

	#if abs(zoom.x-new_zoom)>0.005:
	#	HexCells.player_unique_instance.queue_redraw()
	zoom = Vector2.ONE * ((new_zoom-zoom.x)*delta+zoom.x)
	
	# FOR NOW, LATER RENDER AND SAVE AS TEXTURE
	HexCells.player_unique_instance.queue_redraw()
