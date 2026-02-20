extends Area2D

func _ready() -> void:
	var me = 100

func _on_body_entered(body) -> void:
	if body.has_method("get stats"):
		var stats = body.get_stats()
		stats.restore_mana(stats.max_mana * 0.5)
