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

var hovered: bool = false

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

#region GUI Event Listeners

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			_on_mouse_pressed()

func _on_mouse_entered():
	scale *= 1.1

func _on_mouse_exited():
	scale /= 1.1

func _on_mouse_pressed():
	pass

#endregion

func _set_display_icon():
	%Icon.texture = icon

func _set_display_name():
	%Name.text = Util.Character.keys()[character]
