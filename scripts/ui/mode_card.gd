extends Button

var _hovered: bool = false

func _ready() -> void:
	mouse_entered.connect(func():
		_hovered = true
		refresh_visual())
	mouse_exited.connect(func():
		_hovered = false
		refresh_visual())
	focus_entered.connect(refresh_visual)
	focus_exited.connect(refresh_visual)
	toggled.connect(func(_pressed: bool): refresh_visual())
	refresh_visual()

func refresh_visual() -> void:
	var highlighted := not disabled and (button_pressed or _hovered or has_focus())
	modulate = Color(1, 1, 1, 0.55) if disabled else Color.WHITE
	var symbol := get_node_or_null("Symbol") as TextureRect
	if symbol != null:
		symbol.modulate = Color.WHITE if highlighted else Color("4c6f9b")
	for node_name in ["Title", "Description", "Hint"]:
		var label := get_node_or_null(node_name) as Label
		if label != null:
			label.add_theme_color_override("font_color", Color.WHITE if highlighted else Color("17263e"))
	var tag := get_node_or_null("Tag") as Label
	if tag != null:
		tag.add_theme_color_override("font_color", Color("c8edff") if highlighted else Color("435979"))
