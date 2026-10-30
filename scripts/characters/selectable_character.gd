@tool
extends Panel

@export var icon: Texture:
	set(value):
		icon = value
		_set_display_icon()

@export var character: Util.Character = Util.Character.None:
	set(value):
		character = value
		_set_display_name()

@export var locked: bool = false:
	set(value):
		locked = value
		_apply_state()

var hovered: bool = false
var _selected: bool = false

func _ready() -> void:
	_set_display_icon()
	_set_display_name()
	_apply_state()
	if Engine.is_editor_hint():
		return
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_apply_state)
	focus_exited.connect(_apply_state)

func _gui_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		grab_focus()
		_on_mouse_pressed()
		accept_event()
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		_on_mouse_pressed()
		accept_event()

func _on_mouse_entered() -> void:
	hovered = true
	_apply_state()

func _on_mouse_exited() -> void:
	hovered = false
	_apply_state()

func set_selected(value: bool) -> void:
	_selected = value
	_apply_state()

func _apply_state() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f0f4fa") if not locked else Color("8a96a6")
	style.border_color = Color("ffad50") if _selected else (Color("8ad6ff") if hovered or has_focus() else Color("d8e2ee"))
	style.set_border_width_all(4 if _selected or hovered or has_focus() else 2)
	add_theme_stylebox_override("panel", style)
	var art := get_node_or_null("Icon") as TextureRect
	if art != null:
		art.modulate = Color(0.45, 0.45, 0.45, 0.7) if locked else Color.WHITE
	var lock_label := get_node_or_null("LockedLabel") as Label
	if lock_label != null:
		lock_label.visible = locked
	mouse_default_cursor_shape = Control.CURSOR_ARROW if locked else Control.CURSOR_POINTING_HAND

func _on_mouse_pressed() -> void:
	if locked:
		return
	var screen := get_tree().current_scene
	if screen != null and screen.has_method("handle_character_card_pressed"):
		screen.call("handle_character_card_pressed", character)
	else:
		MultiplayerManager.select_character(character)

func _set_display_icon() -> void:
	var art := get_node_or_null("Icon") as TextureRect
	if art != null:
		art.texture = icon

func _set_display_name() -> void:
	var label := get_node_or_null("Name") as Label
	if label != null:
		label.text = Util.get_character_display_name(character).to_upper()
