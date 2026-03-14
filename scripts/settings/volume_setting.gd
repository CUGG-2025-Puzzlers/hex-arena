@tool
extends Control

@export var setting_name: String = "Volume":
	set(value):
		setting_name = value
		%SettingLabel.text = value

@export var setting_type: Util.Setting = Util.Setting.None

@onready var _value_label: Label = %VolumeValue
@onready var _slider: HSlider = %VolumeSlider

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_slider.value_changed.connect(_on_slide_value_changed)

func _on_slide_value_changed(value: float):
	_value_label.text = str(int(value))
