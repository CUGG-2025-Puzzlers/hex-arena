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

	# get "Master" audio bus (indx 0). Set volume
	var bus_idx = AudioServer.get_bus_index("Master") 
	
	if value <= 0: # 0 = mute asnd 100 = blast
		AudioServer.set_bus_mute(bus_idx, true)
	else:
		AudioServer.set_bus_mute(bus_idx, false)
		# convert 0-100 slider range to decibels
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(value / 100.0))
