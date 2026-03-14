class_name UserSettings
extends Resource

# This script is a resource that should hold relevant user settings, like audio
# levels, KEYBINDS, and more. 

#region Audio Settings

@export var master_volume: int = 50

#endregion

#region Keybind Settings

@export var move_up: Key = Key.KEY_W
@export var move_left: Key = Key.KEY_A
@export var move_down: Key = Key.KEY_S
@export var move_right: Key = Key.KEY_D

@export var convert_shield: Key = Key.KEY_Q
@export var convert_light: Key = Key.KEY_E
@export var convert_heavy: Key = Key.KEY_R

@export var use_ability: Key = Key.KEY_SHIFT

#endregion
