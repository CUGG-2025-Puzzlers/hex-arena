extends Node

@onready var _reset_button: Button = %ResetButton
@onready var _exit_button: Button = %ExitButton

func _ready() -> void:
	_reset_button.pressed.connect(_on_reset_pressed)
	_exit_button.pressed.connect(_on_exit_pressed)

#region Button Callbacks

func _on_reset_pressed():
	reset_to_default()

func _on_exit_pressed():
	close_options()

#endregion

func reset_to_default():
	pass

func close_options():
	pass
