extends Timer
class_name ManaSpawner

var mana_pool = preload("res://scenes/mana_pool.tscn")
var screen: Rect2 = Rect2()

static var player_unique_instance : ManaSpawner

@export var restores_mana: float = 40
@export var remains_on_map_for: float = 16
@export var min_time_between_spawns: float = 8

func _ready() -> void:
	player_unique_instance = self
	
	screen.size = Vector2(HexCells.player_unique_instance.width,HexCells.player_unique_instance.height)
	screen.position = -screen.size/2
	
	if multiplayer.is_server():
		start()

func _on_timeout() -> void:
	var players = get_node("../Players").get_children()
	
	if len(players)==2:
		var midpoint : Vector2 = 0.5*(players[0].global_position+players[1].global_position)
		var dist_v : Vector2 = (players[0].global_position-players[1].global_position).normalized()
		dist_v = dist_v.rotated(PI/2.)
		var pos = midpoint + dist_v*randf_range(3,9)*[1,-1].pick_random()*HexCells.hex_width
		
		if not screen.has_point(pos):
			wait_time=min_time_between_spawns
			return
		
		var cell = HexCells.player_unique_instance.local_to_map(pos)
		if not HexCells.cell_dict.has(cell) or is_instance_valid(HexCells.cell_dict[cell]):
			wait_time=min_time_between_spawns
			return
		
		place_mana_pool.rpc(cell)
		wait_time = randf_range(min_time_between_spawns, remains_on_map_for)

@rpc("call_local", "authority", "reliable")
func place_mana_pool(cell: Vector2i):
	if HexCells.cell_dict.has(cell) and is_instance_valid(HexCells.cell_dict[cell]):
		HexCells.cell_dict[cell].queue_free()
	
	var mana_pool_instance : Area2D = mana_pool.instantiate()
	mana_pool_instance.global_position = HexCells.map_to_local(cell)
	
	add_child(mana_pool_instance)
	HexCells.cell_dict[cell] = mana_pool_instance
	
	mana_pool_instance.add_to_group("mana_pool")
	
	var mana_pool_lifespan:Timer = mana_pool_instance.get_node("Timer")
	mana_pool_lifespan.start(remains_on_map_for)
	mana_pool_lifespan.timeout.connect(mana_pool_instance.queue_free)


@rpc("call_local","authority","reliable")
func collect_mana_pool(pos: Vector2, player_id:int):
	var cell = HexCells.player_unique_instance.local_to_map(pos)
	if HexCells.cell_dict.has(cell) and is_instance_valid(HexCells.cell_dict[cell]):
		HexCells.cell_dict[cell].queue_free()
		HexCells.cell_dict[cell]=null
	
	get_node("../Players/"+str(player_id)+"/StatsComponent").restore_mana(restores_mana)
