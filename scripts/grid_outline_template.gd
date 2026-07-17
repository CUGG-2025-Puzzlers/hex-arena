@tool
extends GridOutline

func _ready() -> void:
	GridOutline.player_unique_instance.redrawn.connect(custom_draw)

func custom_draw():
	hex_outlines = GridOutline.player_unique_instance.hex_outlines
	queue_redraw()
