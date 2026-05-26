extends Area2D

@onready var player_id : int = multiplayer.get_unique_id()

func _ready() -> void:
	print("[WALK OBJECTIVE] spawned")
	
func _on_area_entered(area: Area2D) -> void:
	print("[WALK OBJECTIVE] player_id=", player_id)
	if not area.player_id == null and area.player_id == player_id:
		print("[WALK OBJECTIVE] objective complete")
		
